package Parsers::ESID;
use strict;
use warnings FATAL => 'all';
use Try::Tiny;

=pod

We don't actually instantiate this class.

=cut

sub getESID
{
    my $patron = shift;
    my $institution = shift;

    my $esid = "";

    # I'm trying to error check this. I want a try/catch
    try
    {
        $esid = eval "$institution->{esid}(\$patron)";
    }
    catch
    {
        return "";
    };

    return $esid;

}

sub unique_id
{
    my $patron = shift;
    return $patron->{unique_id};
}

sub email
{
    my $patron = shift;
    return $patron->{email_address};
}

sub barcode
{
    my $patron = shift;
    return $patron->{barcode};
}

1;