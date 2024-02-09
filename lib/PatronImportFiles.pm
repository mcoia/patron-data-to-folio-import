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
    my @filePathsHashArray = ();

    my $fileHashArray = $self->_loadMOBIUSPatronLoadsCSV(); # <== todo: switch this over to the database. Almost ready!!!
    $fileHashArray = $self->_buildFilePatterns($fileHashArray);

    for my $clusterFileHash (@$fileHashArray)
    {
        $main::log->addLine("Processing File Pattern: [$clusterFileHash->{file}][$clusterFileHash->{pattern}]:[$clusterFileHash->{cluster}]:[$clusterFileHash->{institution}]");

        my $filePaths = $self->_patronFileDiscovery($clusterFileHash);

        my $filePathsHash = {
            'cluster'      => $clusterFileHash->{cluster},
            'institution'  => $clusterFileHash->{institution},
            'file_pattern' => $clusterFileHash->{pattern},
            'files'        => $filePaths,
        };

        # I'm saving a list of files instead of just 1. This should be in a loop of the array of files in $filePathsHash->{files}
        # We need the database id's

        # $filePathsHash
        # 'cluster' = {SCALAR(0x56204970dfd8)} "archway"
        # 'file_pattern' = {SCALAR(0x562048c7e780)} "eccpat"
        # 'files' = {REF to ARRAY(0x56204965aa50)} REF(0x56204972a300)
        #            "/mnt/dropbox/archway/home/archway/incoming/eccpat.txt"
        # 'institution' = {SCALAR(0x56204970dcc0)} "East Central College"

        my $debugger = 1;








        push(@filePathsHashArray, $filePathsHash);

    }

    return \@filePathsHashArray;
}

=head1 getPTYPEMappingSheet($cluster)

Load the mapping sheet for Ptype mapping.

On our zero field, 'Patron Type' we get 3 digits that determine what type of account this is.
We'll use this csv sheet to drive this.

example:




=cut
sub getPTYPEMappingSheet
{
    my $self = shift;
    my $cluster = shift;

    my $filePath = "$main::conf->{patronTypeMappingSheetPath}/$cluster.csv";

    # todo: put this in the database
    return $self->_loadCSVFileAsArray($filePath);
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
        if ($rowCount > 0)
        {

            $cluster = $row->[0] if ($row->[0] ne '');
            $institution = $row->[1] if ($row->[1] ne '');

            # We have a filename in this column, it's what we're after!
            if ($row->[2] ne '' && $row->[2] ne 'n/a' && $row->[2] ne 'Patron Files')
            {

                my $files = {
                    'cluster'     => lc $cluster,
                    'institution' => $institution,
                    'file'        => $row->[2],
                };

                push(@clusterFiles, $files) if ($self->_containsClusterName($cluster));

            }

        }
        $rowCount++;
    }

    return \@clusterFiles;
}

sub _buildFilePatterns
{
    # Is this where this method goes?
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
    my $clusterFileHash = shift;

=pod

What does this clusterFileHash look like?

{
          'file' => 'eccpat.txt',
          'institution' => 'East Central College',
          'pattern' => 'eccpat',
          'cluster' => 'archway'
};


=cut

    my @filePaths = ();

    # We use linux's find command to probe these directories for files
    my $command = "find $main::conf->{rootPath}/$clusterFileHash->{cluster}/home/$clusterFileHash->{cluster}/incoming/* -iname $clusterFileHash->{pattern}*";
    $main::log->addLine("Looking for patron files: [$command]");
    my @paths = `$command`;
    chomp(@paths);

    if (@paths)
    {
        for my $path (@paths)
        {
            $main::log->addLine("File Found: [$clusterFileHash->{cluster}][$clusterFileHash->{institution}]:[$path]");
            print "File Found: [$clusterFileHash->{cluster}][$clusterFileHash->{institution}]:[$path]\n";
        }
        push(@filePaths, @paths);
    }

    return \@filePaths if (@filePaths);

    $main::log->addLine("File NOT FOUND! [$clusterFileHash->{cluster}][$clusterFileHash->{institution}][$clusterFileHash->{pattern}]");
    print "File NOT FOUND! [$clusterFileHash->{cluster}][$clusterFileHash->{institution}][$clusterFileHash->{pattern}]\n";

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
                $main::conf->{jobID},
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
        $main::conf->{jobID},
        $institution->{id},
        'file-not-found'
    );

    $main::dao->_insertIntoTable("file_tracker", \@data);

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

1;