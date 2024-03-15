package PatronImportFiles;
use strict;
use warnings FATAL => 'all';
# no warnings 'uninitialized';
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

sub readFileToArray
{

    my $self = shift;
    my $filePath = shift;

    $main::log->addLogLine("reading file: [$filePath]");

    my @data = ();

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";
    my $lineCount = 0;
    while (my $line = <$fileHandle>)
    {
        $line =~ s/\n//g;
        $line =~ s/\r//g;
        push(@data, $line) if ($line ne '');
        $lineCount++;
    }

    close $fileHandle;

    my $arraySize = @data;
    $main::log->addLogLine("Total lines read: [$lineCount] : Total array size: [$arraySize]");

    return \@data;

}

sub getPatronFilePaths
{
    my $self = shift;

    # todo: write this!
    # my $files = $main::dao->


}

sub _loadMOBIUSPatronLoadsCSV
{
    # https://docs.google.com/spreadsheets/d/1Bm8cRxcrhthtDEaKduYiKrNU5l_9VtR7bhRtNH-gTSY/edit#gid=1394736163
    my $self = shift;
    my $csv = $self->_loadCSVFileAsArray($main::conf->{clusterFilesMappingSheetPath});
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
            'cluster'         => lc $cluster,
            'institutionName' => $institution,
            'name'            => $row->[2],
        };

        push(@clusterFiles, $files) if ($row->[2] ne '');

        $rowCount++;
    }

    return \@clusterFiles;
}

sub _buildFilePatterns
{

    my $self = shift;
    my $clusterFileHashArray = shift;
    my $filePatterns;

    for my $clusterFileHash (@{$clusterFileHashArray})
    {

        my $pattern = $clusterFileHash->{name};

        # $pattern = lc $pattern;
        # next if ($pattern eq 'n/a' || $pattern !~ 'dd' || $pattern !~ 'mm'|| $pattern !~ 'yy'); next if ($pattern eq 'n/a');

        # print "$pattern,";
        $pattern =~ s/\-/\\-/g;
        $pattern =~ s/\./\\./g;
        $pattern =~ s/dd/\\d{2}/g;
        $pattern =~ s/mm/\\d{2}/g;
        $pattern =~ s/MM/\\d{2}/g;
        $pattern =~ s/yyyy/\\d{4}/g;
        $pattern =~ s/yy/\\d{2}/g;
        $pattern =~ s/YY/\\d{2}/g;

        $clusterFileHash->{pattern} = $pattern;

        push(@$filePatterns, $clusterFileHash);

    }

    return $filePatterns;
}

sub patronFileDiscovery
{
    my $self = shift;
    my $institution = shift;

    for my $file (@{$institution->{'folder'}->{files}})
    {

        next if ($file->{'pattern'} eq 'n/a' || $file->{'pattern'} eq '');
        print "Looking for pattern: [$file->{pattern}]\n";
        $main::log->addLine("Looking for pattern: [$file->{pattern}]");

        my @files = ();

        @files = @{dirtrav($self, \@files, $institution->{'folder'}->{'path'})};
        my @paths = ();
        foreach (@files)
        {
            my $thisFullPath = $_;
            my @frags = split(/\//, $thisFullPath);
            my $filename = pop @frags;
            push(@paths, $thisFullPath) if ($filename =~ /$file->{pattern}/);
            undef $thisFullPath;
            undef @frags;
        }

        if (@paths)
        {
            for my $path (@paths)
            {

                unless (-d $path) # we're getting directories matching.
                {

                    print "File Found: [$institution->{name}]:[$path]\n";
                    $main::log->addLine("File Found: [$institution->{'folder'}->{'path'}]:[$path]");

                    $main::dao->_insertHashIntoTable("file_tracker", {
                        'job_id'         => $main::jobID,
                        'institution_id' => $institution->{'id'},
                        'path'           => $path,
                        'size'           => (stat($path))[7],
                        'lastModified'   => (stat($path))[9],
                    });
                }

            }

        }

        $file->{paths} = \@paths;

    }

}

sub dirtrav
{
    my $self = shift;
    my $f = shift;
    my $pwd = shift;
    my @files = @{$f};
    opendir(DIR, "$pwd") or die "Cannot open $pwd\n";
    my @thisdir = readdir(DIR);
    closedir(DIR);
    foreach my $file (@thisdir)
    {
        if (($file ne ".") and ($file ne ".."))
        {
            if (-d "$pwd/$file")
            {
                push(@files, "$pwd/$file");
                @files = @{dirtrav($self, \@files, "$pwd/$file")};
            }
            elsif (-f "$pwd/$file")
            {
                push(@files, "$pwd/$file");
            }
        }
    }
    return \@files;
}

sub _loadCSVFileAsArray
{
    my $self = shift;
    my $filePath = shift;

    my $parser = Text::CSV::Simple->new;
    my @csvData = $parser->read_file($filePath);

    return \@csvData;

}

sub saveFilePath
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
        $file->{folder_path} = "$main::conf->{rootPath}/$file->{cluster}/home/$file->{cluster}/incoming";
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
            'name'    => $institution->{institutionName},
            'enabled' => 'TRUE',
            'module'  => "GenericParser",
            'esid'    => $esid
        };

        # we store the institution name into an array and check for it's existence on each cycle
        unless (grep(/$institutionToSave->{name}/, @existingInstitutions))
        {
            $main::dao->_insertHashIntoTable("institution", $institutionToSave);
            $institution_id = $main::dao->_getLastIDByTableName("institution"); # <== this works because we only build this 1 time
            push(@existingInstitutions, $institutionToSave->{name});
        }

        my $folder = {
            # 'institution_id' => $institution_id,
            'path' => "/mnt/dropbox/$institution->{cluster}/home/$institution->{cluster}/incoming"
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
        # unless ($self->_containsInstitutionFolderMapHash(\@existingInstitutionsFolderMap, $institutionFolderMap))
        unless (grep {$_->{'folder_id'} == $institutionFolderMap->{'folder_id'} &&
            $_->{'institution_id'} == $institutionFolderMap->{'institution_id'}} @existingInstitutionsFolderMap)
        {
            $main::dao->_insertHashIntoTable("institution_folder_map", $institutionFolderMap);
            push(@existingInstitutionsFolderMap, $institutionFolderMap);
        }

        # files are 100% unique here.
        my $file = {
            'institution_id' => $institution_id,
            # 'folder_id'      => $folder_id,
            'name'           => $institution->{name},
            'pattern'        => $institution->{pattern}
        };

        $main::dao->_insertHashIntoTable("file", $file);

    }

}

sub buildPtypeMappingFromCSV
{
    my $self = shift;

    my $mappingSheet = $self->_loadCSVFileAsArray($main::conf->{patronTypeMappingSheetPath});
    my $institutions = $main::dao->getInstitutionsFoldersAndFilesHash();

    for my $row (@{$mappingSheet})
    {

        # skip the first row
        next if ($row->[0] eq 'Name');

        my $institution = $row->[0];
        my $pType = $row->[3];
        my $folioType = $row->[5];

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

        $main::dao->_insertHashIntoTable("ptype_mapping", $record);

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
    # https://docs.google.com/spreadsheets/d/1Q9EqkKqCkEchKzcumMcMWxr-UlPSB__xD0ddPPZaj7M/edit#gid=154768990
    $main::dao->dropTable($tableName);
    $main::dao->createTableFromCSV("sso_esid_mapping", $main::conf->{sso_esid_mapping}, 4);

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

1;