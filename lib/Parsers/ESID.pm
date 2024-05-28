package Parsers::ESID;
use strict;
use warnings FATAL => 'all';
use Try::Tiny;

=pod

Okay, here is what I found.
These institutions need to have the suffix dropped from the ESID:

Columbia College:  "3406536" rather than "3406536CC"
Logan:  "000070103" rather than "000070103L"
Metropolitan Community College:  "1413784" rather than "1413784MCC"
Rockhurst:  "770719" rather than "770719RG"
State Fair:  "000284132" rather than "000284132SFCC"
These institutions need to have the ESID padded out to 7-digits:
East Central:  "0179959" rather than "179959"
Maryville:  "0962514" rather than "962514"
North Central also needs to be padded out with leading zeroes in the ESID "000164269" rather than "164269"

Misc:
I'm not sure when St. Charles dropped the suffix from their Unique ID, but I don't see it in the patron file.  I wonder if we need to add it back.  Help Desk folks?
And Truman is just a mess and keeps changing everything but I think we are using email as the ESID for them.  I'm seeing it two different ways in the sheet.
Otherwise, looks good!

https://docs.google.com/spreadsheets/d/1Q9EqkKqCkEchKzcumMcMWxr-UlPSB__xD0ddPPZaj7M/edit#gid=154768990

=cut

sub getESID
{
    my $patron = shift;
    my $institution = shift;

    my $esid = "";


    # if ($institution->{'esid'} ne '' && $patron->{'esid'} eq '');




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