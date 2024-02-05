#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use lib qw(./);

use Test1;
use Test2;

sub getTest
{

    my $t = shift;

    return Test1::doWork($t) if ($t == 1);
    return Test2::doWork($t) if ($t == 2);

}

my $institution = "archway";
my $query = "select module from parser_modules where institution = '$institution';";


