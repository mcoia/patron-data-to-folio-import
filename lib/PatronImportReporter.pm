package PatronImportReporter;
use strict;
use warnings FATAL => 'all';

sub new
{
    my $class = shift;
    my $self = {
        'pType' => (),
    };
    bless $self, $class;
    return $self;
}

1;