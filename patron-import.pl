#!/usr/bin/perl

# use strict;
# use warnings;

use lib qw(lib);

# Imports
use Getopt::Long;

use MOBIUS::email;
use MOBIUS::Loghandler;
use JSON;
use Data::Dumper;
use MOBIUS::Utils;
use SierraFolioParser;

our $configFile;
our $debug = 0;
our $dbHandler;
our %conf;
our $log;
our $parser;

GetOptions(
    "config=s" => \$configFile,
    "debug"    => \$debug,
)
    or die("Error in command line arguments\nYou can specify
--config                                      [Path to the config file]
--debug                                       [Cause more log output]
\n");

sub init {

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    $configFile = "config.conf" if (!defined $configFile);
    our $conf = $utils->readConfFile($configFile);
    exit if ($conf eq "false");
    %conf = %{$conf};

    initLogger();

    ########## Database  ####################
    # Uncomment when needed
    # initDatabaseConnection();
    # createDatabase();
    ########## Database  ####################


    $parser = SierraFolioParser->new($log);

}

sub main {


    # file path: rootPath\{clusterName}\home\{clusterName}\incoming

    $log->addLogLine("****************** Starting ******************");

    print "dropbox path: $conf{dropboxPath}\n";

}

init();
main();

sub initLogger
{
    $log = new Loghandler($conf->{"logfile"});
    $log->truncFile("");
}

sub initDatabaseConnection
{
    eval {$dbHandler = new DBhandler($conf{"db"}, $conf{"dbhost"}, $conf{"dbuser"}, $conf{"dbpass"}, $conf{"port"} || "3306", "mysql", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n";
        exit 1;
    }
}

sub createDatabase
{
    # Placeholder, we may not need db connections

    # my $query = "";
    # $log->addLine($query);
    # $dbHandler->update($query);

}

exit;