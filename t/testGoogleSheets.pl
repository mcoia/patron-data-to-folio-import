#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use MOBIUS::GoogleSheets;
use Data::Dumper;

my $url = "https://docs.google.com/spreadsheets/d/1MaQlncNOAMpT_-mWUfd650f88Vv1xFOZKw7pIfqr5qE/edit#gid=1585277753";
my $google = MOBIUS::GoogleSheets->new($url)->getSheets()->_downloadZip();

# my $sheets = $google->getSheets();


# $google->getSheets()->_downloadZip();


