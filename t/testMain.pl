#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib qw(../lib);
use MOBIUS::Utils;


print "working...\n";

my $utils = MOBIUS::Utils->new();

print $utils->generateRandomString();
print $utils->generateRandomString();


1;