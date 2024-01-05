package ParserFiles;
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

############################## Print functions ##############################

sub printRootPath
{
    my $self = shift;
    print "rootPath: $self->{rootPath}\n";
}

sub printFiles
{
    my $self = shift;
    my $files = shift;
    print "$_\n" for (@{$files});
}

1;