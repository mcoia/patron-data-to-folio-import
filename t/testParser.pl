#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);

use SierraFolioParser;

my $log = Loghandler->new($conf->{"logfile"});
$log->truncFile("");

my $parser = SierraFolioParser->new();



1;