package Parsers::TrumanParser;
use strict;
use warnings FATAL => 'all';
use parent 'Parsers::SierraParser';

sub afterParse
{
    my $self = shift;

    my $patrons = $self->{parsedPatrons};
    for my $patron (@{$patrons})
    {

        # We need to massage the custom_fields.
        # "Other Barcode 1":["00136489301"] : "otherBarcode":"00136489301"
        # replace 'Other Barcode 1' with 'otherBarcode

        $patron->{custom_fields} =~ s/Other Barcode 1/otherBarcode/g if ($patron->{custom_fields} =~ 'Other Barcode 1');
        $patron->{custom_fields} =~ s/\[//g if ($patron->{custom_fields} =~ /\[/);
        $patron->{custom_fields} =~ s/\]//g if ($patron->{custom_fields} =~ /\]/);

    }

}

1;