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
use DAO;

my $configFile;
my $runType;
my $help;

our ($conf, $log, $dao, $files, $parser);

GetOptions(
    "config=s" => \$configFile,
    "run:s"    => \$runType,
    "help:s"   => \$help,
)
    or die("Error in command line arguments\nPlease see --help for more information.\n");

$runType = "all" if (!defined $runType);

print "[$runType]\n";

if (defined $help)
{
    print getHelpMessage();
    exit;
}

initConf();
initLogger();
main();

sub main
{

    # Create our main objects
    $dao = DAO->new();
    $files = PatronImportFiles->new();
    $parser = Parser->new();

    $dao->checkDatabaseStatus();

    startJob();
    ########## stage | import #########################################
    # $dao->resetStagePatronTable() if ($runType eq "stage" || $runType eq "all");
    $parser->stagePatronRecords() if ($runType eq "stage" || $runType eq "all");
    $parser->migrate()  if ($runType eq "migrate" || $runType eq "all");
    # $folio->importPatrons() if($runType eq "import" || $runType eq "all");
    ########## stage | import #########################################
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

    my @data = (
        $dao->_getCurrentTimestamp,
        $dao->_getCurrentTimestamp,
    );

    $dao->_insertIntoTable("job", \@data);

    $conf->{jobID} = $dao->getLastJobID();

}

sub finishJob
{
    my $jobID = $conf->{jobID};
    my $schema = $conf->{schema};
    my $timestamp = $dao->_getCurrentTimestamp();
    my $query = "update $schema.job
                 set stop_time='$timestamp' where id=$jobID;";

    # print $query;
    $dao->{db}->update($query);

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