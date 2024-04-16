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

    my $json = $files->readFileAsString("../resources/json/patron.json");

    my $tenant = "cs00000001_0053";

    # my $response = $folio->login($main::conf->{primaryTenant})->importIntoFolio($tenant, $json);
    my $response = $folio->login($main::conf->{primaryTenant})->importIntoFolio($tenant, $json);

    print Dumper($response);
    print "\n" for(0..10);

    my $jsonResponse = decode_json($response->{_content});
    for my $fail (@{$jsonResponse->{failedUsers}})
    {
        print Dumper($fail);
    }

}

# test_otherEndPoints();
sub test_otherEndPoints
{

    # example: http://localhost:<port>/configurations/entries?query=scope.institution_id=aaa%20sortBy%20enabled

    # /consortia
    # /consortia/<consortia-uuid>/tenants
    my $tenant = "cs00000001_0053";

    # $folio->login($main::conf->{primaryTenant});
    $folio->login($tenant);


    # (username=="ab*" or personal.firstName=="ab*" or personal.lastName=="ab*") and active=="true" sortby personal.lastName personal.firstName barcode
    # active=true sortBy username

    my $endpoint = "users?query=username=mobius*";
    # my $endpoint = "accounts?query=username=mobius*";

    my $response = $folio->HTTPRequest("GET", "/" . $endpoint);

    my $json = $response->{_content};

    # print Dumper($response);
    # print "\n" for(0..10);
    print $response->{_content} . "\n";

}
