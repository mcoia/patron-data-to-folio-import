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

        my $file = $clusterFileHash->{name};

        my $extension = ($file =~ /\.\w*$/g)[0];
        $extension = "" if (!defined($extension));

        $file =~ s/dd.*/*/g;
        $file =~ s/mm.*/*/g;
        $file =~ s/yy.*/*/g;

        $file =~ s/DD.*/*/g;
        $file =~ s/MM.*/*/g;
        $file =~ s/YY.*/*/g;

        $file =~ s/month.*/*/g;
        $file =~ s/day.*/*/g;
        $file =~ s/year.*/*/g;

        # add the file extension back if it isn't already and we actually have one.
        $file .= $extension if ($file !~ /$extension/ && $extension ne '');

        $clusterFileHash->{pattern} = $file;

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

        # find: warning: ‘-iname’ matches against basenames only, but the given pattern contains a directory separator (‘/’),
        # thus the expression will evaluate to false all the time.  Di you mean ‘-iwholename’?
        # We get this error because some of the filenames are listed as 'n/a' so the command looks like
        # find /mnt/dropbox/arthur/home/arthur/incoming/* -iname n/a*
        next if ($file->{'pattern'} eq 'n/a' || $file->{'pattern'} eq '');

        my $command = "find $institution->{'folder'}->{'path'}/* -iname $file->{pattern}";
        my @paths = `$command`;
        chomp(@paths);

        if (@paths)
        {
            for my $path (@paths)
            {

                unless (-d $path) # we're getting directories matching.
                {
                    $main::log->addLine("File Found: [$institution->{'folder'}->{'path'}]:[$path]");
                    print "File Found: [$institution->{name}]:[$path]\n";

                    $main::dao->_insertHashIntoTable("file_tracker", {
                        'job_id'         => $main::jobID,
                        'institution_id' => $institution->{'id'},
                        'path'           => $path
                    });
                }

            }

        }

        $file->{paths} = \@paths;

    }

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

1;