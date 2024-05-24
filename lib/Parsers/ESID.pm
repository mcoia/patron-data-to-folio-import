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
        # I was getting some issues with this when esid is blank and there was no lookup.
        # being that we only have a few options I decided to just type it out instead to prevent future bugs.
        # I was getting esid=$VAR1 which was bombing the program.
        # $esid = eval "$institution->{esid}(\$patron)";

        $esid = $patron->{unique_id} if ($institution->{esid} eq "unique_id");
        $esid = $patron->{email} if ($institution->{esid} eq "email");
        $esid = $patron->{barcode} if ($institution->{esid} eq "barcode");
        $esid = $patron->{note} if ($institution->{esid} eq "note");

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

# this one looks pretty sketchy
sub note
{
    my $patron = shift;
    return $patron->{note};
}

1;