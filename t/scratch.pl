#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;


# $patron->{'field_code'} = '0' if ($data =~ /^0/);



# 0012M-01 mfb  --12/31/24
my $data = "  0012M-01 mfb  --12/31/24     ";
$data =~ s/^\s*//g;
$data =~ s/\s*$//g;
print "[$data]\n";

