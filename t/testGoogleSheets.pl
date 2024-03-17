#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use MOBIUS::GoogleSheets;
use Data::Dumper;

# my $url = "https://docs.google.com/spreadsheets/d/1MaQlncNOAMpT_-mWUfd650f88Vv1xFOZKw7pIfqr5qE/edit#gid=1585277753";
my $url = "https://docs.google.com/spreadsheets/d/1kAdsJ9Hk9iW6cW9S9uAiosutIo_eBtFE7zRQy8iczbY/edit#gid=0";
my $google = MOBIUS::GoogleSheet->new($url);
my $sheets = $google->getSheets();
