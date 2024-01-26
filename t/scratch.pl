#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use POSIX;

# print "press enter to continue...\n"; my $a = <STDIN>;


my $time = time();
my $x = "123456890" + time();
my $y = "123456890$time";

print "$time\n";
print "$x\n";
print "$y\n";