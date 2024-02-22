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
    my @fileTrackerArray = ();

    my $institutions = $main::dao->getInstitutionMap();

    for my $institution (@{$institutions})
    {

        my $filePaths = $self->_patronFileDiscovery($institution);

        for my $filePath (@{$filePaths})
        {

            my @data = (
                $main::jobID,
                $institution->{id},
                $filePath
            );

            $main::dao->_insertArrayIntoTable("file_tracker", \@data);
            my $file_tracker = $main::dao->_convertQueryResultsToHash("file_tracker", $main::dao->getLastFileTrackerEntryByFilename($filePath))->[0];

            push(@fileTrackerArray, $file_tracker);
        }

    }

    return \@fileTrackerArray;
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
            'cluster'     => lc $cluster,
            'institution' => $institution,
            'file'        => $row->[2],
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

        my $file = $clusterFileHash->{file};

        # remove some file extensions
        $file =~ s/\.txt*//g;
        $file =~ s/\.marc*//g;

        # Dates
        $file =~ s/dd.*//g;
        $file =~ s/mm.*//g;
        $file =~ s/yy.*//g;

        $file =~ s/DD.*//g;
        $file =~ s/MM.*//g;
        $file =~ s/YY.*//g;

        $file =~ s/month.*//g;
        $file =~ s/day.*//g;
        $file =~ s/year.*//g;

        $clusterFileHash->{pattern} = $file;

        push(@$filePatterns, $clusterFileHash);

    }

    return $filePatterns;
}

sub _patronFileDiscovery
{
    my $self = shift;
    my $institution = shift;

    # We don't have a file pattern to even search for. Just return.
    return if ($institution->{file_pattern} eq '' || $institution->{file_pattern} eq 'n/a');

    my @filePaths = ();

    # We use linux's find command to probe these directories for files
    # my $command = "find $main::conf->{rootPath}/$clusterFileHash->{cluster}/home/$clusterFileHash->{cluster}/incoming/* -iname $clusterFileHash->{pattern}*";
    my $command = "find $institution->{folder_path}/* -iname $institution->{file_pattern}*";
    $main::log->addLine("Looking for patron files: [$command]");
    my @paths = `$command`;
    chomp(@paths);

    if (@paths)
    {
        for my $path (@paths)
        {
            $main::log->addLine("File Found: [$institution->{cluster}][$institution->{institution}]:[$path]");
            print "File Found: [$institution->{cluster}][$institution->{institution}]:[$path]\n";
        }
        push(@filePaths, @paths);
    }

    return \@filePaths if (@filePaths);

    # $main::log->addLine("File NOT FOUND! [$institution->{cluster}][$institution->{institution}][$institution->{pattern}]");
    print "File NOT FOUND! [$institution->{cluster}][$institution->{institution}][$institution->{file_pattern}]\n";

    # we found zero files for this pattern in all the clusters
    return \@filePaths;

}

sub _loadCSVFileAsArray
{
    my $self = shift;
    my $filePath = shift;

    my $parser = Text::CSV::Simple->new;
    my @csvData = $parser->read_file($filePath);

    return \@csvData;

}

sub _containsClusterName
{
    my $self = shift;
    my $row = lc shift;

    my @clusters = split(' ', $main::conf->{clusters});

    for (@clusters)
    {
        return 1 if ($row eq $_);
    }

    return 0;
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

sub buildDCBPtypeMappingFromCSV
{
    # patronTypeMappingSheetPath
    my $self = shift;

    my $mappingSheet = $self->_loadCSVFileAsArray($main::conf->{patronTypeMappingSheetPath});

    # my @pTypeMappingArray = ();
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
            'name'       => $institution,
            'pType'      => $pType,
            'foliogroup' => $folioType
        };

        # push(@pTypeMappingArray, $record);
        $main::dao->_insertHashIntoTable("ptype_mapping", $record);

    }


    # return \@pTypeMappingArray;

}

sub buildInstitutionMapTableData
{
    my $self = shift;

    my $institutions = $self->_loadMOBIUSPatronLoadsCSV();
    $institutions = $self->_buildFilePatterns($institutions);
    $institutions = $self->_buildFolderPaths($institutions);

    $self->_loadSSO_ESID_MappingCSV();

    for my $institution (@{$institutions})
    {

        my $esid = $main::dao->getESIDFromMappingTable($institution);

        my @data = (
            "$institution->{cluster}",
            "$institution->{institution}",
            "$institution->{folder_path}",
            "$institution->{file}",
            "$institution->{pattern}",
            "GenericParser",
            $esid
        );

        $main::dao->_insertArrayIntoTable("institution_map", \@data);

    }


}

sub _loadSSO_ESID_MappingCSV
{
    my $self = shift;

    my $csv = $self->_loadCSVFileAsArray($main::conf->{sso_esid_mapping});
    my $tableName = "sso_esid_mapping";

    # load our sso_esid_mapping sheet.
    # https://docs.google.com/spreadsheets/d/1Q9EqkKqCkEchKzcumMcMWxr-UlPSB__xD0ddPPZaj7M/edit#gid=154768990
    $main::dao->dropTable($tableName);
    $main::dao->createTableFromCSVFilePath("sso_esid_mapping", $main::conf->{sso_esid_mapping}, 4);

}

1;