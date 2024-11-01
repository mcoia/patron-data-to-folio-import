package Parsers::KCKCCParser;
use strict;
use warnings FATAL => 'all';
use parent 'Parsers::SierraParser';

sub new
{
    my $class = shift;
    my $self = {
        institution => shift,
    };
    bless $self, $class;
    return $self;
}

sub afterParse
{
    my $self = shift;

    my $patrons = $self->{parsedPatrons};
    for my $patron (@{$patrons})
    {
        $patron->{barcode} = $patron->{unique_id};
        print $patron->{unique_id} . ":" . $patron->{barcode} . "\n";
    }

}

1;