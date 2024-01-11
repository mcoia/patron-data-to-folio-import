#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);

use MOBIUS::Loghandler;
use MOBIUS::Utils;

use PatronImportFiles;
use SierraFolioParser;
use Data::Dumper;
our $conf;
initConf();

print Dumper($conf);

our $log = Loghandler->new("test.log");
$log->truncFile("");

my $files = PatronImportFiles->new($conf, $log);

# my $patronFilePath = "../resources/test-files/incoming/SLCCStaff";
# my @data = @{$files->readPatronFile($patronFilePath)};

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "/home/owner/repo/mobius/folio/patron-import/patron-import.conf";
    $conf = $utils->readConfFile($configFile);

    exit if ($conf eq "false");

    # leave it de-reffed, talk with blake about this being the norm.
    # %conf = %{$conf};

}

$files->getSierraImportFilePaths();



1;