#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib qw(../lib);
use MOBIUS::DBhandler;
use MOBIUS::Utils;
use Data::Dumper;

my ($conf, $dbHandler);

initConf();
initDatabaseConnection();

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

sub initDatabaseConnection
{
    eval {$dbHandler = DBhandler->new($conf->{db}, $conf->{dbhost}, $conf->{dbuser}, $conf->{dbpass}, $conf->{port} || 5432, "postgres", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n";
        exit 1;
    }
}












1;