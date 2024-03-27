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
use FileService;
use Parser;
use DAO;

my $configFile;
my $runType;
my $help;
our $dropSchema;

our ($conf, $log, $dao, $files, $parser, $jobID);

GetOptions(
    "config=s"      => \$configFile,
    "run:s"         => \$runType,
    "help:s"        => \$help,
    "drop_schema:s" => \$dropSchema,
)
    or die("Error in command line arguments\nPlease see --help for more information.\n");

$runType = "all" if (!defined $runType);
getHelpMessage() if (defined $help);

initConf();
initLogger();
main();

sub main
{

    # Create our main objects
    $dao = DAO->new();
    $files = FileService->new();
    $parser = Parser->new();

    $dao->checkDatabaseStatus() if ($runType eq "init" || $runType eq "all");

    startJob();
    ########## stage | import #########################################
    $parser->stagePatronRecords() if ($runType eq "stage" || $runType eq "all");
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

    my $time = localtime();
    my $epoch = time();
    $time =~ s/\d\d:\d\d:\d\d\s//g;
    $time =~ s/\s/_/g;

    my $logFileName = $conf->{logfile};
    $logFileName = lc $conf->{logfile} =~ s/\{time\}/_$time/gr if ($conf->{logfile} =~ /\{time\}/);
    $logFileName = lc $conf->{logfile} =~ s/\{epoch\}/_$epoch/gr if ($conf->{logfile} =~ /\{epoch\}/);

    $log = Loghandler->new($logFileName);
    $log->truncFile("");

}

sub startJob
{

    my $job = {
        'start_time' => $dao->_getCurrentTimestamp,
        'stop_time'  => $dao->_getCurrentTimestamp,
    };

    $dao->_insertHashIntoTable("job", $job);

    $jobID = $dao->getLastJobID();

    # $conf->{jobID} = $dao->getLastJobID();

}

sub finishJob
{

    my $schema = $conf->{schema};
    my $timestamp = $dao->_getCurrentTimestamp();
    my $query = "update $schema.job
                 set stop_time='$timestamp' where id=$jobID;";

    # print $query;
    $dao->{db}->update($query);

}

sub getHelpMessage
{

    print
        "You can specify
        --config                                      [Path to the config file]
        --run                                         [stage | load]
                                                      stage: This will stage patron records
                                                      load:  This will load patron records into folio.
        \n";
    exit;
}