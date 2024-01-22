package PatronImportFiles;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

=head1 new(conf, log)


=cut
sub new
{
    my $class = shift;
    my $self = {
        'conf' => shift,
        'log'  => shift,
    };
    bless $self, $class;
    return $self;
}

sub listFiles
{
    my $self = shift;
    my $path = shift;
    my @files = `ls -d $path/*`;
    chomp @files;
    return \@files;
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
    $self->{log}->addLogLine("Total lines read: [$lineCount]");
    $self->{log}->addLogLine("Total array size: [$arraySize]");

    return \@data;

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

    my $filePath = "$self->{conf}->{patronTypeMappingSheetPath}/$cluster.csv";

    return $self->loadCSVFileAsArray($filePath);
}

# sub getPatronLoadsFilePatters
sub buildFilePatterns
{
    my $self = shift;
    my $clusterFileHashArray = shift;
    my $filePatterns;

    for my $clusterFileHash (@{$clusterFileHashArray})
    {

        my $file = $clusterFileHash->{file};

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

sub loadMOBIUSPatronLoadsCSV
{

    my $self = shift;
    my $csv = $self->loadCSVFileAsArray($self->{conf}->{clusterFilesMappingSheetPath});
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

sub getPatronFilePaths
{
    my $self = shift;
    my @filePathsArray = ();

    my $clusterFileHashArray = $self->loadMOBIUSPatronLoadsCSV();
    $clusterFileHashArray = $self->buildFilePatterns($clusterFileHashArray);

    for my $clusterFileHash (@$clusterFileHashArray)
    {
        $self->{log}->addLine("Processing File Pattern: [$clusterFileHash->{file}][$clusterFileHash->{pattern}]:[$clusterFileHash->{cluster}]:[$clusterFileHash->{institution}]");

        my $filePaths = $self->patronFileDiscovery($clusterFileHash);
        push(@filePathsArray, $filePaths);

    }

    return \@filePathsArray;
}

sub patronFileDiscovery
{
    my $self = shift;
    my $clusterFileHash = shift;

    my @filePaths = ();

    my $command = "find $self->{conf}->{rootPath}/$clusterFileHash->{cluster}/home/$clusterFileHash->{cluster}/incoming/* -name $clusterFileHash->{pattern}*";

    $self->{log}->addLine("Looking for patron files: [$command]");
    print "Looking for patron files: [$command]";

    my @paths = `$command`;
    push(@filePaths, @paths) if (@paths);

    return \@filePaths if (@filePaths);

    $self->{log}->addLine("File NOT FOUND! File Pattern: [$clusterFileHash]");

    # we found zero files for this pattern in all the clusters
    return 0;

}

sub loadCSVFileAsArray
{
    my $self = shift;
    my $filePath = shift;

    my $parser = Text::CSV::Simple->new;
    my @csvData = $parser->read_file($filePath);

    return \@csvData;

}

sub rowContainsClusterName
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

1;