package ParserFileManager;
use strict;
use warnings FATAL => 'all';

sub new
{
    my $class = shift;
    my $self = {
        'log' => shift,
    };
    bless $self, $class;
    return $self;
}




1;