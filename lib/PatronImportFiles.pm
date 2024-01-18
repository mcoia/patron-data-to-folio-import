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

    my @csvData = ();

    my $filePath = "$self->{conf}->{patronTypeMappingSheetPath}/$cluster.csv";
    print "\n\n $filePath \n\n";

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";

    my $count = 0;
    while (my $line = <$fileHandle>)
    {
        # chomp $line;
        print $line;

        # my @row = split(',', $line);
        # my $colCount = 0;
        # for my $rowLine (@row)
        # {
        #     print "$rowLine";
        #     $colCount++;
        # }
        #
        # push(@csvData, \@row);
    }

    close $fileHandle;

    return \@csvData;
}

=head1 getSierraImportFilePaths()

Get the sheet from here
# https://docs.google.com/spreadsheets/d/1Bm8cRxcrhthtDEaKduYiKrNU5l_9VtR7bhRtNH-gTSY/edit#gid=1394736163

Save it and put it in the resources/mapping folder.

set the name in conf

=cut
sub getSierraImportFilePaths
{
    my $self = shift;
    my $filePath = $self->{clusterFilesMappingSheetPath};

    # print "CSV filename: [$self->{conf}->{clusterFilesMappingSheetPath}]\n";

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";
    while (my $line = <$fileHandle>)
    {
        # chomp $line;
        # push(@data, $line);
    }

    close $fileHandle;

=pod
sudo code...

for(googleSheetRows){

if(col[0] ne '')
    cluster = col[0];

// logic stuff.
institution = col[1] if ne ''
ect...

}

basically loop over everything and if we have a value in that column ,set it otherwise it rolls on to the next.
or... I just modify the damn thing to fit my needs. Tell them how I needs it.

Ultimately it returns an array of hashes.


=cut

}

1;