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
    my $self = {
        jobID => shift,
        dao   => shift,
        conf  => shift,
        log   => shift,
        debug => shift,
    };
    bless $self, $class;
    return $self;
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
        {
            find(sub {push(@files, $File::Find::name)}, $folder->{'path'});
        }
        catch
        {
            print "Could not find this folder path! $folder->{'path'}\n" if ($self->{debug});
            $self->{log}->addLine("Could not find this folder path! $folder->{'path'}");
        };

        for my $file (@{$folder->{files}})
        {

            # Skip files that are 'n/a'
            next if ($file->{'pattern'} eq 'n/a' || $file->{'pattern'} eq '' || !defined($file->{'pattern'}));

            print "Looking for pattern: [$file->{pattern}]\n" if ($self->{debug});
            $self->{log}->addLine("Looking for pattern: [$file->{pattern}]");

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
            my @saving = ();

            if (@paths)
            {
                for my $path (@paths)
                {

                    # Check if we're a file
                    if (-f $path)
                    {

                        print "File Found: [$institution->{name}]:[$path]\n" if ($self->{debug});
                        $self->{log}->addLine("File Found: [$folder->{'path'}]:[$path]");

                        my $pathHash = $self->buildPathHash($path, $institution->{'id'});

                        # we're going to skip files older than n days. Setting in conf file.
                        my $maxPatronFileAge = $self->{conf}->{maxPatronFileAge} * 60 * 60 * 24;

                        # check our file dates for old files.
                        if (time > $pathHash->{lastModified} + $maxPatronFileAge)
                        {
                            print "File is older than configured [$maxPatronFileAge days] allowance. Skipping.\n" if ($self->{debug});
                            $self->{log}->addLine("File is older than $maxPatronFileAge days . Skipping.");
                            next;
                        }

                        my $id = $self->{dao}->insertHashIntoTable("file_tracker", $pathHash);
                        my $s = {"path" => $path, "id" => $id};
                        push @saving, $s;

                    }

                }

            }

            $file->{paths} = \@saving;

        }

    }

}

sub patronFileDiscoverySpecificFolder
{
    my $self = shift;
    my $institution_id = shift;

    print "Dropbox discovery starting for institution_id: [$institution_id]\n" if ($self->{debug});
    $self->{log}->addLine("Dropbox discovery starting for institution_id: [$institution_id]");

    my $basePath = $self->{dao}->getFullPathByInstitutionId($institution_id);
    print "Base path from database: [$basePath]\n" if ($self->{debug});
    $self->{log}->addLine("Base path from database: [$basePath]");

    my $dropboxSpecificInstitutionDirectoryPath = $basePath . "/import";
    print "Looking for dropbox files in: [$dropboxSpecificInstitutionDirectoryPath]\n" if ($self->{debug});
    $self->{log}->addLine("Looking for dropbox files in: [$dropboxSpecificInstitutionDirectoryPath]");

    # Check if directory exists and is accessible
    if (!defined($dropboxSpecificInstitutionDirectoryPath) || $dropboxSpecificInstitutionDirectoryPath eq '/import') {
        print "ERROR: Invalid path for institution_id [$institution_id] - path is undefined or incomplete\n" if ($self->{debug});
        $self->{log}->addLine("ERROR: Invalid path for institution_id [$institution_id] - path is undefined or incomplete");
        return {
            path => $dropboxSpecificInstitutionDirectoryPath,
            files => [],
            error => 'INVALID_PATH',
            error_message => "Invalid path for institution_id [$institution_id] - path is undefined or incomplete"
        };
    }

    if (!-e $dropboxSpecificInstitutionDirectoryPath) {
        print "WARNING: Directory does not exist: [$dropboxSpecificInstitutionDirectoryPath]\n" if ($self->{debug});
        $self->{log}->addLine("WARNING: Directory does not exist: [$dropboxSpecificInstitutionDirectoryPath]");
        return {
            path => $dropboxSpecificInstitutionDirectoryPath,
            files => [],
            error => 'NOT_FOUND',
            error_message => "Directory does not exist: $dropboxSpecificInstitutionDirectoryPath"
        };
    }

    if (!-d $dropboxSpecificInstitutionDirectoryPath) {
        print "WARNING: Path exists but is not a directory: [$dropboxSpecificInstitutionDirectoryPath]\n" if ($self->{debug});
        $self->{log}->addLine("WARNING: Path exists but is not a directory: [$dropboxSpecificInstitutionDirectoryPath]");
        return {
            path => $dropboxSpecificInstitutionDirectoryPath,
            files => [],
            error => 'NOT_DIRECTORY',
            error_message => "Path exists but is not a directory: $dropboxSpecificInstitutionDirectoryPath"
        };
    }

    if (!-r $dropboxSpecificInstitutionDirectoryPath) {
        print "ERROR: Directory is not readable: [$dropboxSpecificInstitutionDirectoryPath]\n" if ($self->{debug});
        $self->{log}->addLine("ERROR: Directory is not readable: [$dropboxSpecificInstitutionDirectoryPath]");
        return {
            path => $dropboxSpecificInstitutionDirectoryPath,
            files => [],
            error => 'PERMISSION_DENIED',
            error_message => "Directory is not readable (permission denied): $dropboxSpecificInstitutionDirectoryPath"
        };
    }

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
    {
        my $error = $_ || $@ || 'Unknown error';
        print "ERROR: File::Find failed for [$dropboxSpecificInstitutionDirectoryPath]: $error\n" if ($self->{debug});
        $self->{log}->addLine("ERROR: File::Find failed for [$dropboxSpecificInstitutionDirectoryPath]: $error");
    };

    my $fileCount = scalar(@files);
    print "Found [$fileCount] files in dropbox directory\n" if ($self->{debug});
    $self->{log}->addLine("Found [$fileCount] files in dropbox directory");

    my $folder = {
        path  => $dropboxSpecificInstitutionDirectoryPath,
        files => []
    };

    for my $filePath (@files)
    {

        # Check file age (same logic as pattern discovery)
        my $pathHash = $self->buildPathHash($filePath, $institution_id);
        my $maxPatronFileAge = $self->{conf}->{maxPatronFileAge} * 60 * 60 * 24;
        if (time > $pathHash->{lastModified} + $maxPatronFileAge)
        {
            print "Dropbox file is older than $self->{conf}->{maxPatronFileAge} days. Skipping: [$filePath]\n" if ($self->{debug});
            $self->{log}->addLine("Dropbox file is older than $self->{conf}->{maxPatronFileAge} days. Skipping: [$filePath]");
            next;
        }

        my $fileName = $filePath;
        $fileName =~ s|.*/||; # Extract just the filename

        # Log that we found and backed up a dropbox file
        print "Dropbox file found and backed up: [$fileName] at [$filePath]\n" if ($self->{debug});
        $self->{log}->addLine("Dropbox file found and backed up: [$fileName] at [$filePath]");

        # Backup file contents to database
        my $id = $self->{dao}->insertHashIntoTable("file_tracker", $pathHash);
        my $s = {"path" => $filePath, "id" => $id};
        my @saving = ($s);

        push @{$folder->{files}}, {
            paths => \@saving,
            name  => $fileName,
            pattern => ".*", # Accept any file from dropbox (no pattern restriction)
            dropbox_file => 1, # Flag to indicate this came from dropbox discovery
            institution_id => $institution_id
        };
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

    my $institution = $self->{dao}->getInstitutionMapHashByName($filePathsHash->{institution});
    my $files = $filePathsHash->{files};
    my @files = @{$files};

    my @newFiles = ();

    if (@files) # <== this is suspect
    {
        # files can't be empty
        for my $path (@files)
        {

            my @data = (
                $self->{jobID},
                $institution->{id},
                $path
            );

            $self->{dao}->_insertIntoTable("file_tracker", \@data);
            my $file = $self->{dao}->getLastFileTrackerEntryByName($path);
            # getLastFileTrackerEntry
        }

        return; # I return here because I freaking hate else statements

    }

    # No files found

    my @data = (
        $self->{jobID},
        $institution->{id},
        'file-not-found'
    );

    $self->{dao}->_insertArrayIntoTable("file_tracker", \@data);

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

sub buildPathHash
{
    my $self = shift;
    my $path = shift;
    my $institution_id = shift;

    # Skip reading contents for binary Excel files - they're read directly by parsers
    my $contents = '';
    if ($path !~ /\.(xlsx|xls)$/i) {
        $contents = $self->readFileAsString($path);
    }

    return {
        'job_id'         => $self->{jobID},
        'institution_id' => $institution_id,
        'path'           => $path,
        'size'           => (stat($path))[7],
        'lastModified'   => (stat($path))[9],
        'contents'       => $contents  # Empty string for xlsx/xls files
    };

}

1;