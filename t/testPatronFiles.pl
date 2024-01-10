#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);

use MOBIUS::Loghandler;

use PatronFiles;
use SierraFolioParser;

our $log = Loghandler->new("test.log");
$log->truncFile("");

our @clusters = qw(archway arthur avalon bridges explore kc-towers palmer swan swbts);

my $files = PatronFiles->new($log, ".", \@clusters);

my $patronFilePath = "../resources/test-files/incoming/SLCCStaff";

my @data = @{$files->readPatronFile($patronFilePath)};


1;