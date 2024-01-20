#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

# my $hash;
# $hash->{'title'} = 'something';
# print $hash->{'title'};


my %hash;
my $hash = \%hash;
$hash->{'title'} = 'something';
print $hash->{'title'};


1;