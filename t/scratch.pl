#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my $hash = 1;

my $arrays = 'while (my $row = $query->fetchrow_arrayref())';
my $hashes = 'while (my $row = $query->fetchrow_hashref())';
my $whileLoop = $hash ? $arrays : $hashes;

print "$whileLoop\n";
