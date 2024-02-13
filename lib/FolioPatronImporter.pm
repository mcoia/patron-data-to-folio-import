package FolioPatronImporter;
use strict;
use warnings FATAL => 'all';

sub new
{
    my $class = shift;
    my $self = {
        '' => shift,
    };
    bless $self, $class;
    return $self;
}

1;