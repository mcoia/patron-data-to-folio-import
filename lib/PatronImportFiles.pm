package PatronImportFiles;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use Text::CSV::Simple;

=head1 new(conf, log)


=cut
sub new
{
    my $class = shift;
    my $self = {
        'conf' => shift,
        'log'  => shift,
        'db'   => shift,
    };
    bless $self, $class;
    return $self;
}

sub readFileToArray
{

    my $self = shift;
    my $filePath = shift;

    $self->{log}->addLogLine("reading file: [$filePath]");

    my @data = ();

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";
    my $lineCount = 0;
    while (my $line = <$fileHandle>)
    {
        chomp $line;
        push(@data, $line);
        $lineCount++;
    }

    close $fileHandle;

    my $arraySize = @data;
    $self->{log}->addLogLine("Total lines read: [$lineCount] : Total array size: [$arraySize]");

    return \@data;

}

sub getPatronFilePaths
{
    my $self = shift;
    my @filePathsHashArray = ();

    my $clusterFileHashArray = $self->_loadMOBIUSPatronLoadsCSV();
    $clusterFileHashArray = $self->_buildFilePatterns($clusterFileHashArray);

    for my $clusterFileHash (@$clusterFileHashArray)
    {
        $self->{log}->addLine("Processing File Pattern: [$clusterFileHash->{file}][$clusterFileHash->{pattern}]:[$clusterFileHash->{cluster}]:[$clusterFileHash->{institution}]");

        my $filePaths = $self->_patronFileDiscovery($clusterFileHash);

        my $filePathsHash = {
            'cluster'     => $clusterFileHash->{cluster},
            'institution' => $clusterFileHash->{institution},
            'pattern'     => $clusterFileHash->{pattern},
            'files'       => $filePaths,
        };

        # Save $filePathsHash to database
        $self->saveFilePath($filePathsHash);

        push(@filePathsHashArray, $filePathsHash) if ($filePaths != 0);
    }

    return \@filePathsHashArray;
}

=head1 _getPTYPEMappingSheet($cluster)

Load the mapping sheet for Ptype mapping.

On our zero field, 'Patron Type' we get 3 digits that determine what type of account this is.
We'll use this csv sheet to drive this.

example:




=cut
sub _getPTYPEMappingSheet
{
    my $self = shift;
    my $cluster = shift;

    my $filePath = "$self->{conf}->{patronTypeMappingSheetPath}/$cluster.csv";

    return $self->_loadCSVFileAsArray($filePath);
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

sub _loadMOBIUSPatronLoadsCSV
{

    my $self = shift;
    my $csv = $self->_loadCSVFileAsArray($self->{conf}->{clusterFilesMappingSheetPath});
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

                push(@clusterFiles, $files);
            }

        }
        $rowCount++;
    }

    return \@clusterFiles;
}

sub _patronFileDiscovery
{
    my $self = shift;
    my $clusterFileHash = shift;

    my @filePaths = ();

    my $command = "find $self->{conf}->{rootPath}/$clusterFileHash->{cluster}/home/$clusterFileHash->{cluster}/incoming/* -iname $clusterFileHash->{pattern}*";

    $self->{log}->addLine("Looking for patron files: [$command]");

    my @paths = `$command`;
    chomp(@paths);

    if (@paths)
    {
        for my $path (@paths)
        {
            $self->{log}->addLine("File Found: [$clusterFileHash->{cluster}][$clusterFileHash->{institution}]:[$path]");
            print "File Found: [$clusterFileHash->{cluster}][$clusterFileHash->{institution}]:[$path]\n";
        }
        push(@filePaths, @paths);
    }

    return \@filePaths if (@filePaths);

    $self->{log}->addLine("File NOT FOUND! [$clusterFileHash->{cluster}][$clusterFileHash->{institution}][$clusterFileHash->{pattern}]");
    print "File NOT FOUND! [$clusterFileHash->{cluster}][$clusterFileHash->{institution}][$clusterFileHash->{pattern}]\n";

    # we found zero files for this pattern in all the clusters
    return 0;

}

sub _loadCSVFileAsArray
{
    my $self = shift;
    my $filePath = shift;

    my $parser = Text::CSV::Simple->new;
    my @csvData = $parser->read_file($filePath);

    return \@csvData;

}

sub _rowContainsClusterName
{
    my $self = shift;
    my $row = lc shift;

    my @clusters = split(' ', $self->{conf}->{clusters});

    for (@clusters)
    {
        return 1 if ($row eq $_);
    }

    return 0;
}

sub saveFilePath
{
    my $self = shift;
    my $filePathsHash = shift;

    my $cluster = $filePathsHash->{cluster};
    my $institution = $filePathsHash->{institution};
    my $pattern = $filePathsHash->{pattern};
    my @files = @{$filePathsHash->{files}};

    for my $path (@files)
    {
        my $query = "
       INSERT INTO patron_import_files(cluster, institution, pattern, filename)
       values (
            '$cluster',
            '$institution',
            '$pattern',
            '$path'
       );
";

        $self->{db}->update($query);
    }

    exit;

}

1;