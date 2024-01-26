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

# Create a table
my $query = "DROP TABLE IF EXISTS cars";
$dbHandler->update($query);

$query = "
CREATE TABLE cars (
    brand VARCHAR(255),
        model VARCHAR(255),
            year INT
)";
$dbHandler->update($query);

# Insert Data
$query = "INSERT INTO cars (brand,model,year) VALUES ('Ford', 'Focus', 2007)";
$dbHandler->update($query);
$query = "INSERT INTO cars (brand, model, year) VALUES ('Ford', 'Mustang', 1964)";
$dbHandler->update($query);

$query = "SELECT * FROM cars";

my @cars = $dbHandler->query($query);

print Dumper(\@cars);

$query = "DROP TABLE IF EXISTS cars";
$dbHandler->update($query);


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