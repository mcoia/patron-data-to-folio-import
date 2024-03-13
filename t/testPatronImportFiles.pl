#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib qw(../lib);
use MOBIUS::DBhandler;
use MOBIUS::Utils;
use DAO;
use Parser;
use PatronImportFiles;

use Data::Dumper;

our ($conf, $log);
initConf();
initLog();

our $dao = DAO->new();
$dao->_initDatabaseCache();

our $files = PatronImportFiles->new();
our $parser = Parser->new();

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "/home/owner/repo/mobius/folio/patron-import/patron-import.conf";
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

# test_patronFileDiscovery();
sub test_patronFileDiscovery
{
    my $institution = {
        'name'   => 'Drury University',
        'id'     => 56,
        'folder' => {
            'files' => [
                {
                    'pattern'   => 'COTT',
                    'name'      => 'COTTyyyymmdd.txt',
                    'folder_id' => 7,
                    'id'        => 80
                },
                {
                    'pattern'   => 'ccstupat',
                    'name'      => 'ccstupat.txt',
                    'folder_id' => 7,
                    'id'        => 81
                },
                {
                    'id'        => 82,
                    'name'      => 'DRURYPAT_students.txt',
                    'folder_id' => 7,
                    'pattern'   => 'DRURYPAT_students'
                },
                {
                    'id'        => 83,
                    'folder_id' => 7,
                    'name'      => 'DRURYPAT_employees.txt',
                    'pattern'   => 'DRURYPAT_employees'
                },
                {
                    'name'      => 'DRURYPAT_alumni.txt',
                    'folder_id' => 7,
                    'pattern'   => 'DRURYPAT_alumni',
                    'id'        => 84
                },
                {
                    'pattern'   => 'EUPatronCamsExport_',
                    'name'      => 'EUPatronCamsExport_month_day_year',
                    'folder_id' => 7,
                    'id'        => 85
                },
                {
                    'folder_id' => 7,
                    'name'      => 'MSSCALL',
                    'pattern'   => 'MSSCALL',
                    'id'        => 86
                },
                {
                    'folder_id' => 7,
                    'name'      => 'MobiusUploadyyyydd.txt',
                    'pattern'   => 'MobiusUpload',
                    'id'        => 87
                },
                {
                    'pattern'   => 'otcpat',
                    'name'      => 'otcpat.txt',
                    'folder_id' => 7,
                    'id'        => 88
                },
                {
                    'pattern'   => 'SBUPATRONS',
                    'folder_id' => 7,
                    'name'      => 'SBUPATRONS',
                    'id'        => 89
                }
            ],
            'path'  => '/mnt/dropbox/swan/home/swan/incoming',
            'id'    => 7
        },
        'esid'   => '',
        'module' => 'GenericParser'
    };

    my $filesFound = $files->patronFileDiscovery($institution);

    print Dumper($filesFound);

}

1;