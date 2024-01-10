package PatronFiles;
use strict;
use warnings FATAL => 'all';

=head1 new(log, rootPath)


=cut
sub new
{
    my $class = shift;
    my $self = {
        'log'      => shift,
        'rootPath' => shift,
        'clusters' => shift,
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
    return $self->listFiles($self->{rootPath});
}

sub getPatronImportFiles
{

    my $self = shift;
    my @patronImportFiles = ();

    # loop over clusters & get all of our files 
    for my $cluster (@{$self->{clusters}})
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

1;