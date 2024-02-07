#!/usr/bin/perl

use strict;
use warnings;
use lib qw(lib);


# Imports
use Getopt::Long;
use Data::Dumper;
use MOBIUS::email;
use MOBIUS::Loghandler;
use MOBIUS::DBhandler;
use JSON;
use MOBIUS::Utils;
use PatronImportFiles;
use Parser;

our $configFile;
our $runType;
our $help;

our $dao;
our $conf;
our $log;

# Local imports  
our $parser;
our $files;

GetOptions(
    "config=s" => \$configFile,
    "run:s"    => \$runType,
    "help:s"   => \$help,
)
    or die("Error in command line arguments\nPlease see --help for more information.\n");

if (defined $help)
{
    print getHelpMessage();
    exit;
}

initConf();
initLogger();

sub main
{
    startJob();

    # Create our main objects
    $dao = DAO->new($conf, $log);
    $files = PatronImportFiles->new($conf, $log, $dao);
    $parser = Parser->new($conf, $log, $dao, $files);

    ########## stage | load ##########
    # We need to split this so we can run parsers and api loads separate
    $parser->stagePatronRecords() if ($runType eq "stage");

    finishJob();

}

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    $configFile = "patron-import.conf" if (!defined $configFile);
    $conf = $utils->readConfFile($configFile);

    exit if ($conf eq "false");

    # leave it de-reffed, talk with blake about this being the norm.
    # %conf = %{$conf};

}

sub initLogger
{
    $log = Loghandler->new($conf->{logfile});
    $log->truncFile("");
}

sub startJob
{

    # Insert a new job
    my $query = "insert into job(start_time,stop_time) values (CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);";
    $db->update($query);

    # Get the ID of the last job
    $query = "select * from job where start_time = stop_time order by ID desc limit 1;";
    my @results = @{$db->query($query)};

    # Set it in our $conf
    $conf->{jobID} = $results[0][0];

}

sub finishJob
{
    my $jobID = shift;

    my $query = "
        update job
        set stop_time=CURRENT_TIMESTAMP where id=$conf->{jobID};
    ";
    $db->update($query);

}

sub getHelpMessage
{
    return
        "You can specify
        --config                                      [Path to the config file]
        --run                                         [stage | load]
                                                      stage: This will stage patron records
                                                      load:  This will load patron records into folio.
        \n";
}

exit;