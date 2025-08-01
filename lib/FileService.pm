package FileService;

use strict;
use warnings FATAL => 'all';
use File::Find;
use Try::Tiny;
use Encode qw(decode encode);
use Data::Dumper;
use Text::CSV::Simple;

=head1 new(conf, log)


=cut
sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub cleanLine
{
    my $self = shift;
    my $line = shift;

    $line =~ s/[\x{201c}\x{201d}]//g; # Remove smart quotes
    $line =~ s/[\x{2018}\x{2019}]//g; # Remove smart apostrophes
    $line =~ s/\\//g;                 # Remove backslashes
    $line =~ s/\"//g;                 # Remove regular quotes
    $line =~ s/[\x00-\x1F\x7F]//g;    # Remove control characters

    return $line;
}

sub readFileToArray
{
    my $self = shift;
    my $filePath = shift;

    $main::log->addLogLine("reading file: [$filePath]");

    # Check if file exists and is readable
    unless (-e $filePath && -r $filePath) {
        die "File does not exist or is not readable: $filePath";
    }

    my @data = ();
    my $lineCount = 0;
    my @encodings = ('UTF-8', 'cp1252', 'MacRoman');
    my $lastError = "";
    my $success = 0;

    # Try different encodings
    foreach my $encoding (@encodings)
    {
        eval {
            @data = (); # Clear the array
            $lineCount = 0;

            # Set up the file handle with proper encoding and binmode
            open(my $fh, '<', $filePath) or die "Could not open file '$filePath': $!";
            binmode($fh, ":encoding($encoding)");

            # Enable all platform line endings
            local $/ = undef; # Slurp mode
            my $content = <$fh>;
            close($fh);

            # Skip if content is empty
            die "Empty file" unless defined $content && length($content) > 0;

            # Split on any type of line ending
            my @lines = split(/\r\n|\r|\n/, $content);

            foreach my $line (@lines)
            {
                $line = $self->cleanLine($line);
                if ($line =~ /\S/) { # Only keep non-empty lines
                    push(@data, $line);
                    $lineCount++;
                }
            }

            # Check if we got any valid data
            die "No valid data found with $encoding" unless @data;

            $success = 1; # Mark as successful if we got here
            1;
        } or do {
            $lastError = $@ || "Unknown error";
            $main::log->addLogLine("Attempt with $encoding failed: $lastError");
            next; # Try next encoding
        };

        # If successful, exit the loop
        last if $success;
    }

    # If all encodings failed
    unless ($success) {
        $main::log->addLogLine("Failed to read file with any encoding. Last error: $lastError");
        die "Failed to read file with any encoding. Last error: $lastError";
    }

    my $arraySize = @data;
    $main::log->addLogLine("Total lines read: [$lineCount] : Total array size: [$arraySize]");

    return \@data;
}

sub readFileAsString
{
    my $self = shift;
    my $fileName = shift;

    my $data = "";

    open my $fileHandle, '<', $fileName or die "Could not open file '$fileName' $!";
    while (my $line = <$fileHandle>)
    {$data .= $line;}
    close $fileHandle;

    return $data;

}

sub _loadMOBIUSPatronLoadsCSV
{
    # https://docs.google.com/spreadsheets/d/1Bm8cRxcrhthtDEaKduYiKrNU5l_9VtR7bhRtNH-gTSY/edit#gid=1394736163
    my $self = shift;
    my $csv = $self->_loadCSVFileAsArray($main::conf->{projectPath} . "/" . $main::conf->{clusterFilesMappingSheetPath});
    my @clusterFiles = ();
    my $cluster = '';
    my $institution = '';

    my $rowCount = 0;
    for my $row (@{$csv})
    {

        # Skip the header row
        if ($rowCount == 0)
        {
            $rowCount++;
            next;
        }

        $cluster = $row->[0] if ($row->[0] ne '');
        $institution = $row->[1] if ($row->[1] ne '');

        my $files = {
            'cluster'  => lc $cluster, # <== This is needed to build out the file paths.
            'name'     => $institution,
            'fileName' => $row->[2],
        };

        # we should skip all institutions that have a file of 'n/a' as they're not participating?
        push(@clusterFiles, $files) if ($row->[2] ne '');

        $rowCount++;
    }

    return \@clusterFiles;
}

sub _buildFilePatterns
{

    my $self = shift;
    my $institutions = shift;
    my $filePatterns;

    for my $institution (@{$institutions})
    {

        my $pattern = $institution->{fileName};

        $pattern =~ s/\-/\\-/g;
        $pattern =~ s/\./\\./g;
        $pattern =~ s/dd/\\d{2}/g;
        $pattern =~ s/mm/\\d{2}/g;
        $pattern =~ s/MM/\\d{2}/g;
        $pattern =~ s/yyyy/\\d{4}/g;
        $pattern =~ s/yy/\\d{2}/g;
        $pattern =~ s/YY/\\d{2}/g;


        # todo: I'm not sure if this is right.
        # This was added to combat the KCAI file listed for kc-towers. It's to loose and we're picking up other stuff.
        $pattern =~ s/xxx/.*/g;
        $pattern =~ s/XXX/.*/g;

        $institution->{pattern} = $pattern;

        push(@$filePatterns, $institution);

    }

    return $filePatterns;
}

sub patronFileDiscovery
{
    my $self = shift;
    my $institution = shift;

    for my $folder (@{$institution->{folders}})
    {

        # Grab all the files in the institution folder path
        my @files = ();

        # This is our File::Find module. This thing is super fast!
        try
        {find(sub {push(@files, $File::Find::name)}, $folder->{'path'});}
        catch
        {
            print "Could not find this folder path! $folder->{'path'}\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->addLine("Could not find this folder path! $folder->{'path'}");
        };

        for my $file (@{$folder->{files}})
        {

            # Skip files that are 'n/a'
            next if ($file->{'pattern'} eq 'n/a' || $file->{'pattern'} eq '' || !defined($file->{'pattern'}));

            print "Looking for pattern: [$file->{pattern}]\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->addLine("Looking for pattern: [$file->{pattern}]");

            my @paths = ();
            foreach (@files)
            {
                my $thisFullPath = $_;
                my @frags = split(/\//, $thisFullPath);
                my $filename = pop @frags;
                push(@paths, $thisFullPath) if ($filename =~ /$file->{pattern}/i);
                undef $thisFullPath;
                undef @frags;
            }

            if (@paths)
            {
                for my $path (@paths)
                {

                    # Check if we're a file
                    if (-f $path)
                    {

                        print "File Found: [$institution->{name}]:[$path]\n" if ($main::conf->{print2Console} eq 'true');
                        $main::log->addLine("File Found: [$folder->{'path'}]:[$path]");

                        my $pathHash = $self->buildPathHash($path, $institution->{'id'});

                        # we're going to skip files older than n days. Setting in conf file.
                        my $maxPatronFileAge = $main::conf->{maxPatronFileAge} * 60 * 60 * 24;

                        # if $path contains the word test skip
                        if (lc $path =~ /test/)
                        {
                            print "File contains the word test. Skipping.\n" if ($main::conf->{print2Console} eq 'true');
                            $main::log->addLine("File contains the word test. Skipping.");
                            next;
                        }

                        # check our file dates for old files.
                        if (time > $pathHash->{lastModified} + $maxPatronFileAge)
                        {
                            print "File is older than 3 months. Skipping.\n" if ($main::conf->{print2Console} eq 'true');
                            $main::log->addLine("File is older than 3 months. Skipping.");
                            next;
                        }

                        $main::dao->_insertHashIntoTable("file_tracker", $pathHash);

                    }

                }

            }

            $file->{paths} = \@paths;

        }

    }

}

sub patronFileDiscoverySpecificFolder
{
    my $self = shift;
    my $institution_id = shift;

    my $dropboxSpecificInstitutionDirectoryPath = $main::dao->getFullPathByInstitutionId($institution_id);

    my @files;

    # Define the wanted subroutine here, with access to @files
    my $wanted = sub {
        push @files, $File::Find::name if -f; # Only add files, avoiding directories
    };

    try
    {
        find($wanted, $dropboxSpecificInstitutionDirectoryPath); # Find all files in the specified path
    }
    catch
    {};

    my $folder = {
        path  => $dropboxSpecificInstitutionDirectoryPath,
        files => []
    };

    for my $filePath (@files)
    {
        # Skip files that contain 'test' in the name
        if (lc $filePath =~ /test/)
        {
            print "Dropbox file contains 'test'. Skipping: [$filePath]\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->addLine("Dropbox file contains 'test'. Skipping: [$filePath]");
            next;
        }

        # Check file age (same logic as pattern discovery)
        my $pathHash = $self->buildPathHash($filePath, $institution_id);
        my $maxPatronFileAge = $main::conf->{maxPatronFileAge} * 60 * 60 * 24;
        if (time > $pathHash->{lastModified} + $maxPatronFileAge)
        {
            print "Dropbox file is older than $main::conf->{maxPatronFileAge} days. Skipping: [$filePath]\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->addLine("Dropbox file is older than $main::conf->{maxPatronFileAge} days. Skipping: [$filePath]");
            next;
        }

        my $fileName = $filePath;
        $fileName =~ s|.*/||; # Extract just the filename

        my @filePathArray = ();
        push @filePathArray, $filePath;

        # FIX: Create file entry that parsers can process
        push @{$folder->{files}}, {
            paths => \@filePathArray,
            name  => $fileName,
            pattern => ".*", # Accept any file from dropbox (no pattern restriction)
            dropbox_file => 1, # Flag to indicate this came from dropbox discovery
            institution_id => $institution_id
        };

        # Log that we found and backed up a dropbox file
        print "Dropbox file found and backed up: [$fileName] at [$filePath]\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("Dropbox file found and backed up: [$fileName] at [$filePath]");

        # Backup file contents to database
        $main::dao->_insertHashIntoTable("file_tracker", $pathHash);
    }

    return $folder;
}

sub _loadCSVFileAsArray
{
    my $self = shift;
    my $filePath = shift;

    my $parser = Text::CSV::Simple->new;
    my @csvData = $parser->read_file($filePath);

    return \@csvData;

}

sub saveFilePath # <== is this being used?!?!
{
    # this needs updated.

    my $self = shift;
    my $filePathsHash = shift;

    my $institution = $main::dao->getInstitutionMapHashByName($filePathsHash->{institution});
    my $files = $filePathsHash->{files};
    my @files = @{$files};

    my @newFiles = ();

    if (@files) # <== this is suspect
    {
        # files can't be empty
        for my $path (@files)
        {

            my @data = (
                $main::jobID,
                $institution->{id},
                $path
            );

            $main::dao->_insertIntoTable("file_tracker", \@data);
            my $file = $main::dao->getLastFileTrackerEntryByName($path);
            # getLastFileTrackerEntry
        }

        return; # I return here because I freaking hate else statements

    }

    # No files found

    my @data = (
        $main::jobID,
        $institution->{id},
        'file-not-found'
    );

    $main::dao->_insertArrayIntoTable("file_tracker", \@data);

}

sub _buildFolderPaths
{
    my $self = shift;
    my $fileHashArray = shift;

    my @newFileHashArray = ();
    for my $file (@{$fileHashArray})
    {
        $file->{folder_path} = "$main::conf->{dropBoxPath}/$file->{cluster}/home/$file->{cluster}/incoming";
        push(@newFileHashArray, $file);
    }

    return \@newFileHashArray;
}

sub buildInstitutionTableData
{
    my $self = shift;

    my $institutions = $self->_loadMOBIUSPatronLoadsCSV();
    $institutions = $self->_buildFilePatterns($institutions);
    $institutions = $self->_buildFolderPaths($institutions);
    $institutions = $self->_addTenants($institutions);

    # load the esid csv
    $self->_loadSSO_ESID_MappingCSV();

    my @existingFolders = ();
    my @existingInstitutions = ();
    my @existingInstitutionsFolderMap = ();
    my $folder_id = 0;
    my $institution_id = 0;

    for my $institution (@{$institutions})
    {

        my $esid = $main::dao->getESIDFromMappingTable($institution);

        my $institutionToSave = {
            'name'    => $institution->{name},
            'enabled' => 'TRUE',
            'module'  => "SierraParser",
            'esid'    => $esid,
            'tenant'  => $institution->{tenant}
        };

        # I'm not happy with how I wrote this. It works, but it's just not that clean.

        # we store the institution name into an array and check for it's existence on each cycle
        unless (grep(/$institutionToSave->{name}/, @existingInstitutions))
        {
            $main::dao->_insertHashIntoTable("institution", $institutionToSave);
            $institution_id = $main::dao->_getLastIDByTableName("institution"); # <== this works because we only build this 1 time
            push(@existingInstitutions, $institutionToSave->{name});
        }

        my $folder = {
            'path' => "$main::conf->{dropBoxPath}/$institution->{cluster}/home/$institution->{cluster}/incoming"
        };

        # crossref array to see if it's already been added.
        unless (grep(/$folder->{path}/, @existingFolders))
        {
            $main::dao->_insertHashIntoTable("folder", $folder);
            $folder_id = $main::dao->_getLastIDByTableName("folder");
            push(@existingFolders, $folder->{path});
        }

        # our institution -> folder mapping table
        my $institutionFolderMap = {
            'institution_id' => $institution_id,
            'folder_id'      => $folder_id
        };

        # no duplicated entries. Same logic as the unless statements above.
        unless (grep {$_->{'folder_id'} == $institutionFolderMap->{'folder_id'} &&
            $_->{'institution_id'} == $institutionFolderMap->{'institution_id'}} @existingInstitutionsFolderMap)
        {
            $main::dao->_insertHashIntoTable("institution_folder_map", $institutionFolderMap);
            push(@existingInstitutionsFolderMap, $institutionFolderMap);
        }

        # files are 100% unique here.
        my $file = {
            'institution_id' => $institution_id,
            'name'           => $institution->{fileName},
            'pattern'        => $institution->{pattern}
        };

        $main::dao->_insertHashIntoTable("file", $file);

    }

}

sub buildPtypeMappingFromCSV
{
    my $self = shift;

    my $mappingSheet = $self->_loadCSVFileAsArray($main::conf->{projectPath} . "/" . $main::conf->{patronTypeMappingSheetPath});
    my $institutions = $main::dao->getInstitutionsFoldersAndFilesHash();

    for my $row (@{$mappingSheet})
    {

        # skip the first row
        next if ($row->[0] eq 'Name');

        my $institution = $row->[0];
        my $pType = $row->[1];
        my $folioType = $row->[2];

        # trim white spaces
        $institution =~ s/^\s*//g;
        $institution =~ s/\s*$//g;

        $pType =~ s/^\s*//g;
        $pType =~ s/\s*$//g;

        $folioType =~ s/^\s*//g;
        $folioType =~ s/\s*$//g;

        my $record = {
            'institution_id' => $self->_getInstitutionIDFromArray($institutions, $institution),
            'pType'          => $pType,
            'foliogroup'     => $folioType
        };

        # We have a bunch of institutions with a file listed as 'n/a'. We don't even insert these institutions into the db
        # When we try inserting this ptype mapping table we look for these institutions by name, but we didn't insert them
        # so they get an institution_id = -1 which isn't going to work. So we drop them too with the if statement.
        $main::dao->_insertHashIntoTable("ptype_mapping", $record) if ($record->{institution_id} != -1);

    }

}

sub _getInstitutionIDFromArray
{
    my $self = shift;
    my $institutions = shift;
    my $institution = shift;

    for my $i (@{$institutions})
    {
        return $i->{'id'} if ($institution eq $i->{'name'});
    }

    # uh... why didn't we find anything?
    return -1;

}

sub _loadSSO_ESID_MappingCSV
{
    my $self = shift;
    my $tableName = "sso_esid_mapping";

    # load our sso_esid_mapping sheet.
    $main::dao->createTableFromCSV("sso_esid_mapping", $main::conf->{projectPath} . "/" . $main::conf->{sso_esid_mapping});

    # I don't want to touch the csv and I don't want to keep updating it as I test. So I'll just sql it.
    my $updates = "
    update patron_import.sso_esid_mapping set c1='Conception Abbey and Seminary' where c1='Conception Abbey and Seminary College';
    update patron_import.sso_esid_mapping set c1='Concordia' where c1='Concordia Seminary';
    update patron_import.sso_esid_mapping set c1='Goldfarb School of Nursing' where c1='Goldfarb School of Nursing at Barnes-Jewish College';
    update patron_import.sso_esid_mapping set c1='Kenrick-Glennon Seminary' where c1='Kenrick-Glennon Theological Seminary';
    update patron_import.sso_esid_mapping set c1='Missouri Historical Society' where c1='Missouri History Museum';
    update patron_import.sso_esid_mapping set c1='University of Health Sciences and Pharmacy' where c1='University of Health Sciences and Pharmacy in St. Louis';
    update patron_import.sso_esid_mapping set c1='Webster University/Eden Seminary' where c1='Webster University';";

    $main::dao->query($updates);

}

sub getFileStats
{
    my $self = shift;
    my $filename = shift;

    my $currentTime = time();

    my $hash = {};
    $hash->{path} = $filename;
    $hash->{lastAccess} = (stat($filename))[8];
    $hash->{lastModified} = (stat($filename))[9];
    $hash->{currentTime} = $currentTime;
    $hash->{ageInMinutes} = ($currentTime - $hash->{lastModified}) / 60;

    return $hash;

}

sub checkFileForSpecialChars
{

    # uggg.... these csv's are a freakin mess.
    my $self = shift;
    my $fileName = shift;

    print "checking file $fileName\n" if ($main::conf->{print2Console} eq 'true');

    my $data = $self->readFileToArray($fileName);

    # ascii char range?
    my $allowedChars = "+-,.0123456789:;<=>?\@ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\]^_`abcdefghijklmnopqrstuvwxyz ";
    my @allowedChars = split('', $allowedChars);

    print "$allowedChars\n" if ($main::conf->{print2Console} eq 'true');

    my $lineCount = 0;
    for my $line (@{$data})
    {

        # print "[$lineCount]: $line\n" if($main::conf->{print2Console});
        my @lineArray = split('', $line);
        for my $char (@lineArray)
        {
            my $match;
            for (@allowedChars)
            {$match = 1 if ($_ eq $char);}
            print "[$lineCount]:[$char][" . ord($char) . "]\n" if (!defined $match && $main::conf->{print2Console});

        }

        $lineCount++;
    }

    # return 1;

}

sub _addTenants
{
    my $self = shift;
    my $institutions = shift;

    $main::dao->createTableFromCSV("tenant_mapping", $main::conf->{projectPath} . "/resources/mapping/tenant_mapping.csv");
    my $tenants = $main::dao->query("select c1,c2 from patron_import.tenant_mapping");

    for my $institution (@{$institutions})
    {

        for my $tenant (@{$tenants})
        {

            if ($tenant->[0] eq $institution->{name})
            {
                $institution->{tenant} = $tenant->[1];
                next;
            }

        }


    }

    return $institutions;

}

sub deletePatronFiles
{
    my $self = shift;

    return $self;
}

sub normalizeLineEndings
{
    my $self = shift;
    my $inputFile = shift;
    my $outputFile = shift;

    open my $inFH, '<:raw', $inputFile or die "Cannot open input file '$inputFile': $!";
    open my $outFH, '>:raw', $outputFile or die "Cannot open output file '$outputFile' for writing: $!";

    my $content = do {
        local $/;
        <$inFH>
    };

    # Convert all line endings to \n
    $content =~ s/\r\n|\r/\n/g;

    print $outFH $content;

    close $inFH;
    close $outFH;

    print "File processed. Line endings converted to \\n.\n";
}

sub checkAndConvertIfNeeded
{
    my $self = shift;
    my $filePath = shift;

    open my $fh, '<:raw', $filePath or die "Cannot open file '$filePath': $!";

    my $containsCR = 0;
    while (my $line = <$fh>)
    {
        if ($line =~ /\r/)
        {
            $containsCR = 1;
            last;
        }
    }

    close $fh;

    if ($containsCR != 0)
    {
        $main::log->addLogLine("File '$filePath' contains \\r line endings. Converting...");
        print "File '$filePath' contains \\r line endings. Converting...\n" if ($main::conf->{print2Console} eq 'true');
        my $tmpFile = $filePath . ".tmp";
        $self->normalizeLineEndings($filePath, $tmpFile);
        rename $tmpFile, $filePath or die "Cannot rename file: $!";
        print "Conversion complete. Original file updated.\n" if ($main::conf->{print2Console} eq 'true');
    }
    else
    {
        print "File '$filePath' does not contain \\r line endings. No conversion needed.\n" if ($main::conf->{print2Console} eq 'true');
    }

}

sub buildPathHash
{
    my $self = shift;
    my $path = shift;
    my $institution_id = shift;

    return {
        'job_id'         => $main::jobID,
        'institution_id' => $institution_id,
        'path'           => $path,
        'size'           => (stat($path))[7],
        'lastModified'   => (stat($path))[9],
        'contents'       => $self->readFileAsString($path)
    };

}

1;