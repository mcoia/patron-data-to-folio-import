#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

print "-------- Sandbox --------\n";


my $data = "0155m 004lmb    06-30-24";

my @d = $data =~ /^0(\d{3}).*/gm;
my $test = ($data =~ /^0(\d{3}).*/gm)[0];

# print "@d\n";
print "$test\n";