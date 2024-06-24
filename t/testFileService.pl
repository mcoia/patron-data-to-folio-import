#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib qw(../lib);
use MOBIUS::DBhandler;
use MOBIUS::Utils;
use DAO;
use Parser;
use FileService;

use Data::Dumper;

our ($conf, $log);
initConf();
initLog();

our $dao = DAO->new();
$dao->_initDatabaseCache();

our $files = FileService->new();
our $parser = Parser->new();

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "../patron-import.conf";
    $conf = $utils->readConfFile($configFile);

    exit if ($conf eq "false");

}

sub initLog
{
    $log = Loghandler->new("test.log");
    $log->truncFile("");
}

# test_buildDCBPtypeMappingFromCSV();
sub test_buildDCBPtypeMappingFromCSV
{
    $files->buildPtypeMappingFromCSV();
}

# test_DAO_buildInstitutionMapTableData();
sub test_DAO_buildInstitutionMapTableData
{
    $files->buildInstitutionTableData();
}

# buildPtypeMappingFromCSV();
sub buildPtypeMappingFromCSV
{
    $files->buildPtypeMappingFromCSV();
}

test_patronFileDiscovery();
sub test_patronFileDiscovery
{

    my $institutions = $main::dao->getInstitutionsFoldersAndFilesHash();

    for my $institution (@{$institutions})
    {
        print Dumper($institution->{folder}->{files});

    }

}

1;