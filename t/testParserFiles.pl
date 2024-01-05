#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);

use ParserFiles;
use MOBIUS::Loghandler;

my $rootPath = "/mnt/dropbox";

my $log = Loghandler->new("test.log");
$log->truncFile("");

my $parserFiles = ParserFiles->new($log, $rootPath);
my $clusterDirectories = $parserFiles->listFiles($rootPath);

$parserFiles->printRootPath();
$parserFiles->printFiles($clusterDirectories);




1;