package Parsers::ESID;
use strict;
use warnings FATAL => 'all';
use Try::Tiny;
use Data::Dumper;

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

    # check for defined esid's in the patron record. Honestly, if we're not defined somethings wrong.
    # We instantiate this variable back in the parser.
    $self->{patron}->{esid} = "" if (!defined($self->{patron}->{esid}));

    # I knew I was checking for this!
    # So there seems to be some kind of issue with this statement. We were setting the esid and this was still triggering.
    return $self->{patron}->{esid} if ($self->{patron}->{esid} ne '' && $self->{institution}->{esid} !~ /self/);

    return $self->returnBlankESIDLogErrorMessage() if (!defined($self->{institution}->{esid}));
    return $self->returnBlankESIDLogErrorMessage() if ($self->{institution}->{esid} eq '');

    return $self->{patron}->{unique_id} if ($self->{institution}->{esid} eq "unique_id");
    return $self->{patron}->{email_address} if ($self->{institution}->{esid} eq "email");
    return $self->{patron}->{barcode} if ($self->{institution}->{esid} eq "barcode");
    return $self->{patron}->{note} if ($self->{institution}->{esid} eq "note");

    try
    {
        # loop over the $self->{patron} keys, if the key matches the $self->{institution}->{esid} then return that value
        # this is to replace those if statements and decouple the data from the logic.
        # foreach my $key (keys %{$self->{patron}})
        # {return $self->{patron}->{$key} if ($key eq $self->{institution}->{esid});}

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

    print "No ESID found for " . $self->{institution}->{name} . "\n" if ($main::conf->{print2Console});
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