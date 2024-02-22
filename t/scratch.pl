#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my $results = "email (tag z) > tag e";
$results = ($results =~ /^(\w*)/)[0];


print "$results\n";

1;