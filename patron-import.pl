#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib);


# Imports
use Getopt::Long;
use MOBIUS::email;
use MOBIUS::Loghandler;
use JSON;
use Data::Dumper;
use MOBIUS::Utils;
use PatronFiles;
use SierraFolioParser;

our $configFile;
our $debug = 0;
our $dbHandler;
our %conf;
our $log;

# Local imports  
our $parser;
our $files;

GetOptions(
    "config=s" => \$configFile,
    "debug"    => \$debug,
)
    or die("Error in command line arguments\nYou can specify
--config                                      [Path to the config file]
--debug                                       [Cause more log output]
\n");

# Should this be in our conf file? 
our @clusters = qw(archway arthur avalon bridges explore kc-towers palmer swan swbts);

init();
main();

sub init
{

    initConf();
    initLogger();
    # initDatabase(); 
    initPatronFiles(\@clusters);
    initParser();

}

sub main
{

    # our $parser;
    # our $files;
    
    # file path: rootPath\{clusterName}\home\{clusterName}\incoming

    $log->addLogLine("****************** Starting ******************");
    $log->addLogLine("Root path: $conf{rootPath}\n");

    my $patronImportFilePaths = $files->getPatronImportFiles();
    
    
    
}

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    $configFile = "default.conf" if (!defined $configFile);
    my $conf = $utils->readConfFile($configFile);
    exit if ($conf eq "false");
    %conf = %{$conf};

}

sub initLogger
{
    $log = Loghandler->new($conf{"logfile"});
    $log->truncFile("");
}

sub initDatabase
{
    initDatabaseConnection();
    buildSchema();
}

sub initDatabaseConnection
{
    eval {$dbHandler = new DBhandler($conf{"db"}, $conf{"dbhost"}, $conf{"dbuser"}, $conf{"dbpass"}, $conf{"port"} || "3306", "mysql", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n";
        # exit 1;
    }
}

sub buildSchema
{
    # Placeholder, we may not need db connections

    # my $query = "";
    # $log->addLine($query);
    # $dbHandler->update($query);

}

sub initParser
{
    # Create our parser
    $parser = SierraFolioParser->new($log);

}

sub initPatronFiles
{
    my $clusters = shift;

    $files = PatronFiles->new(
        $log,
        $conf{rootPath},
        $clusters
    );


}

exit;