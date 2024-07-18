#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use JSON;


my $string = "Álvaro";

$string =~ s/Á/`A/g;

print $string;
