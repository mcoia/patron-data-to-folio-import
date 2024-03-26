#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

# Tue Mar 26 12:10:25 2024

my $time = localtime();
$time =~ s/\d\d:\d\d:\d\d\s//g;
$time =~ s/\s/_/g;

print "$time\n";