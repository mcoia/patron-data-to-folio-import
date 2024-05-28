#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

sub removeSuffix
{
    my $esid = shift;
    my $suffix = shift;

    $esid =~ s/$suffix$//g;

    return $esid;

}
# example: change V00115420JC to V00115420
my $esid = removeSuffix("V00115420JC", "JC");
print $esid . "\n" ;


