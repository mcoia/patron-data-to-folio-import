#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

my $x = "Hello World!!!";
my $y = $x;
$y =~ s/Hello/Goodbye/gm;

print "$x\n";
print "$y\n";
