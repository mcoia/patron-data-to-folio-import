package Parsers::KCKCCParser;
use strict;
use warnings FATAL => 'all';
use parent 'Parsers::SierraParser';

sub afterParse
{
    my $self = shift;

    # set the barcode = unique_id without 'KCKCC' at the end
    @{$self->{parsedPatrons}} = grep {$_->{barcode} = $_->{unique_id} =~ s/(?i)KCKCC$//r;1} @{$self->{parsedPatrons}};

}

1;