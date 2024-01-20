package PatronImportFiles;
use strict;
use warnings FATAL => 'all';

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

sub getClusterDirectories
{
    my $self = shift;
    return $self->listFiles($self->{conf}->{rootPath});
}

sub getPatronImportFiles
{

    my $self = shift;
    my @patronImportFiles = ();

    my @clusters = split(' ', $self->{conf}->{clusters});

    # loop over clusters & get all of our files 
    for my $cluster (@clusters)
    {

        # TODO: Write this!!! 


        print "cluster: $cluster\n";

    }

    return \@patronImportFiles;

}

sub readPatronFile
{

    my $self = shift;
    my $filePath = shift;

    $self->{log}->addLogLine("reading patron file: [$filePath]");

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

    $self->{log}->addLogLine("total lines read: [$lineCount]");

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

=head1 getSierraImportFilePaths() returns a hash of cluster names with file paths as an array.

example:
my $importFilePaths = getSierraImportFilePaths();
my @arthurFilePaths = $importFilePaths->{arthur};









Get the sheet from here
# https://docs.google.com/spreadsheets/d/1Bm8cRxcrhthtDEaKduYiKrNU5l_9VtR7bhRtNH-gTSY/edit#gid=1394736163

Save it and put it in the resources/mapping folder.

set the name in conf

=cut
sub getSierraImportFilePaths_old
{

    my $self = shift;
    my $csv = $self->loadCSVFileAsArray($self->{conf}->{clusterFilesMappingSheetPath});

    my %filePathHash;
    my $filePathHash = \%filePathHash;
    my $currentCluster = '';
    my $institution = '';
    my @files = ();

    for my $row (@{$csv})
    {

        $currentCluster = lc $row->[0] if ($row->[0] ne '' && $self->rowContainsClusterName($row->[0]));
        if ($row->[1] ne '' && $row->[1] ne 'Institution')
        {
            $institution = lc $row->[1];
            @files = ();
        }

        push(@files, $row->[2]) if ($row->[2] ne '' && $row->[2] ne 'n/a');

        my $fileSize = @files;
        $filePathHash->{$currentCluster}->{$institution} = \@files if ($fileSize && $currentCluster && $institution);

    }

    return $filePathHash;

}

sub getFilePatterns
{
    my $self = shift;
    my $files = shift;
    my @filePatterns = ();

    for my $file (@{$files})
    {
        $file =~ s/dd.*//g;
        $file =~ s/mm.*//g;
        $file =~ s/yy.*//g;

        push(@filePatterns, $file);

    }

    return \@filePatterns;
}

sub getSierraImportFilePaths
{

    my $self = shift;
    my $csv = $self->loadCSVFileAsArray($self->{conf}->{clusterFilesMappingSheetPath});
    my @files = ();

    for my $row (@{$csv})
    {
        push(@files, $row->[2]) if ($row->[2] ne '' && $row->[2] ne 'n/a');
    }

    return \@files;
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