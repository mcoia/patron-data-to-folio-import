package Parsers::ESID;
use strict;
use warnings FATAL => 'all';
use Try::Tiny;

=pod

Okay, here is what I found.
These institutions need to have the suffix dropped from the ESID:

✓ Columbia College:  "3406536" rather than "3406536CC" <== remove suffix
✓ Logan:  "000070103" rather than "000070103L" <== remove suffix
✓ Metropolitan Community College:  "1413784" rather than "1413784MCC" <== remove suffix
✓ Rockhurst:  "770719" rather than "770719RG" <== remove suffix
✓ State Fair:  "000284132" rather than "000284132SFCC" <== remove suffix

These institutions need to have the ESID padded out to 7-digits:
✓ East Central:  "0179959" rather than "179959" <== padLeft
? Maryville:  "0962514" rather than "962514" <== padLeft
North Central also needs to be padded out with leading zeroes in the ESID "000164269" rather than "164269" <== padLeft

Misc:
I'm not sure when St. Charles dropped the suffix from their Unique ID, but I don't see it in the patron file.  I wonder if we need to add it back.  Help Desk folks?
And Truman is just a mess and keeps changing everything but I think we are using email as the ESID for them.  I'm seeing it two different ways in the sheet.
Otherwise, looks good!

https://docs.google.com/spreadsheets/d/1Q9EqkKqCkEchKzcumMcMWxr-UlPSB__xD0ddPPZaj7M/edit#gid=154768990

=cut

sub new
{
    my $class = shift;
    my $self = {
        'institution' => shift,
        'patron'      => shift,
    };
    bless $self, $class;
    return $self;
}

sub getESID
{
    my $self = shift;

    my $esid = "";

    # check for defined esid's in the patron record
    $self->{patron}->{esid} = "" if (!defined($self->{patron}->{esid}));

    return $self->{patron}->{esid} if ($self->{patron}->{esid} ne '');

    # check the institution esid, some are blank!
    return $self->returnBlankESIDLogErrorMessage() if (!defined($self->{institution}->{esid}));
    return $self->returnBlankESIDLogErrorMessage() if ($self->{institution}->{esid} eq '');

    try
    {

        # loop over the $self->{patron} keys, if the key matches the $self->{institution}->{esid} then return that value
        # this is to replace those if statements and decouple the data from the logic.
        foreach my $key (keys %{$self->{patron}})
        {return $self->{patron}->{$key} if ($key eq $self->{institution}->{esid});}

        eval '$esid=$self->' . $self->{institution}->{esid} . '';

    }
    catch
    {
        return "";
    };

    return $esid;

}

sub returnBlankESIDLogErrorMessage
{
    my $self = shift;

    print "No ESID found for " . $self->{institution}->{name} . "\n";
    $main::log->addLine("No ESID found for " . $self->{institution}->{name});
    return "";

}

# add $padChar to the left of the esid until it equals the $size specified.
sub padLeft
{
    my $self = shift;
    my $esid = shift;
    my $padChar = shift;
    my $size = shift;

    while (length($esid) < $size)
    {
        $esid = $padChar . $esid;
    }

    return $esid;

}

# remove the $suffix from the end of the $esid
sub removeSuffix
{
    my $self = shift;
    my $esid = shift;
    my $suffix = shift;

    $esid =~ s/$suffix$//g;

    return $esid;

}

sub removePrefix
{
    my $self = shift;
    my $esid = shift;
    my $prefix = shift;

    $esid =~ s/^$prefix//g;

    return $esid;

}

sub addSuffix
{
    my $self = shift;
    my $esid = shift;
    my $suffix = shift;

    $esid =~ s/$/$suffix/g;

    return $esid;

}

sub addPrefix
{
    my $self = shift;
    my $esid = shift;
    my $prefix = shift;

    $esid =~ s/^/$prefix/g;

    return $esid;

}

1;