#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);

use MOBIUS::Loghandler;

use SierraFolioParser;
use PatronFiles;

# This is our test file
my $patronFilePath = "../resources/test-files/incoming/SLCCStaff";
# my $patronFilePath = "../resources/test-files/incoming/SLCCStaff-1";



my $log = Loghandler->new("test.log");
$log->truncFile("");

our @clusters = qw(archway arthur avalon bridges explore kc-towers palmer swan swbts);


my $parser = SierraFolioParser->new($log);
my $files = PatronFiles->new($log, ".", \@clusters);

my @data = @{$files->readPatronFile($patronFilePath)};

$parser->parse(\@data);


1;