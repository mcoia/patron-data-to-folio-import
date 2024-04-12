#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use Data::Dumper;

use MOBIUS::Utils;
use MOBIUS::Loghandler;

use DAO;
use FileService;
use FolioService;
use Parser;
use Parsers::GenericParser;
use JSON;

our ($conf, $log);

initConf();
initLog();

our $dao = DAO->new()->_cacheTableColumns();
our $files = FileService->new();
our $parser = Parser->new();

our $folio = FolioService->new({
    'username' => $ENV{folio_username},
    'password' => $ENV{folio_password},
    'cookies'  => 0,
});

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "../patron-import.conf";

    $conf = eval {$utils->readConfFile($configFile);};

    if ($conf eq 'false')
    {
        print "trying other location... we must be debugging\n";
        $configFile = "./patron-import.conf";
        $conf = eval {$utils->readConfFile($configFile);};
    }

}

sub initLog
{
    $log = Loghandler->new("test.log");
    $log->truncFile("");
}

test_1RecordLoad();
sub test_1RecordLoad
{

    my $json = <<'json';

{
  "users": [
    {
      "username": "jhandey001",
      "externalSystemId": "jhandey_externalId",
      "patronGroup": "ATSU Student"
    }
  ],
  "totalRecords": 1,
  "deactivateMissingUsers": false,
  "updateOnlyPresentFields": true
}

json

    my $tenant = "cs00000001_0053";

    # my $response = $folio->login($main::conf->{primaryTenant})->importIntoFolio($tenant, $json);
    my $response = $folio->login($tenant)->importIntoFolio($tenant, $json);
    print Dumper($response);

}
