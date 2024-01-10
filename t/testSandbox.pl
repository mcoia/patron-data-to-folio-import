#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

my $hash;

$hash->{test} = "test";

print "hash: $hash->{test}\n";
print Dumper($hash);



