#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);

use MOBIUS::Loghandler;
use MOBIUS::Utils;

use PatronImportFiles;
use SierraFolioParser;
use Text::CSV::Simple;
use Data::Dumper;

our $conf;
initConf();

# print Dumper($conf);

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

sub test_getPTYPEMappingSheet
{

    # my $csv = $files->getPTYPEMappingSheet('archway');
    # my $csv = $files->getPTYPEMappingSheet('arthur');
    # my $csv = $files->getPTYPEMappingSheet('avalon');
    my $csv = $files->getPTYPEMappingSheet('bridges');
    # my $csv = $files->getPTYPEMappingSheet('explore');
    # my $csv = $files->getPTYPEMappingSheet('kc-towers');
    # my $csv = $files->getPTYPEMappingSheet('palmer');
    # my $csv = $files->getPTYPEMappingSheet('swan');
    # my $csv = $files->getPTYPEMappingSheet('swbts');

    for my $row (@{$csv})
    {
        for my $cell (@{$row})
        {
            print "[$cell]";
        }
        print "\n";
    }
}


my $importFilesPaths = $files->getSierraImportFilePaths();

1;
