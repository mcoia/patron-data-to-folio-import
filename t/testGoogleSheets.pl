#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use MOBIUS::GoogleSheets;
use Data::Dumper;

my $url = "https://docs.google.com/spreadsheets/d/1MaQlncNOAMpT_-mWUfd650f88Vv1xFOZKw7pIfqr5qE/edit#gid=1585277753";

# my $google = MOBIUS::GoogleSheets->new($url);
my $google = MOBIUS::GoogleSheets->new();

my $sheets = $google->setURL($url)->getSheets();
# my $sheets = $google->getSheets();

