package Parsers::KCKCCParser;
use strict;
use warnings FATAL => 'all';
use parent 'Parsers::SierraParser';

sub afterParse
{
    my $self = shift;

    # set the barcode = unique_id
    @{$self->{parsedPatrons}} = grep {$_->{barcode} = $_->{unique_id}; 1} @{$self->{parsedPatrons}};

}

1;