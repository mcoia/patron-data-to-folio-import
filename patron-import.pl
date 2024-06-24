#!/usr/bin/perl

use strict;
use warnings;

# use lib qw(lib);
use lib qw(lib patron-data-to-folio-import/lib);

# Imports
use Getopt::Long;
use Data::Dumper;
use MOBIUS::Email;
use MOBIUS::Loghandler;
use MOBIUS::DBhandler;
use JSON;
use MOBIUS::Utils;
use FileService;
use FolioService;
use Parser;
use DAO;

my $configFile;
my $help;

our ($conf, $log, $dao, $files, $parser, $folio, $jobID, $import, $stage, $test, $getFolioUserByUsername, $getFolioUserByESID);

GetOptions(
    "config=s"                 => \$configFile,
    "help:s"                   => \$help,
    "import:s"                 => \$import,
    "stage:s"                  => \$stage,
    "test:s"                   => \$test,
    "getFolioUserByUsername:s" => \$getFolioUserByUsername,
    "getFolioUserByESID:s"     => \$getFolioUserByESID,
)
    or die("Error in command line arguments\nPlease see --help for more information.\n");

checkOptions();
getHelpMessage() if (defined $help);

initConf();
initLogger();
main();

sub main
{

    # Create our main objects
    $dao = DAO->new();
    $files = FileService->new();
    $dao->_cacheTableColumns();
    $parser = Parser->new();
    $folio = FolioService->new();

    # check if we're a command line api call. These functions exit
    commandLineAPICall();

    startJob();

    $parser->stagePatronRecords() if ($stage);
    $folio->importPatrons() if ($import);

    finishJob();

}

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    $configFile = "patron-import.conf" if (!defined $configFile);
    # $configFile = "/home/owner/repo/mobius/folio/patron-data-to-folio-import/patron-import.conf" if (!defined $configFile);
    # $configFile = "patron-data-to-folio-import/patron-import.conf" if (!defined $configFile);
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

sub commandLineAPICall
{
    # Used to run specific methods from the command line.

    $folio->getFolioUserByUsername($getFolioUserByUsername) if (defined $getFolioUserByUsername);
    $folio->getFolioUserByESID($getFolioUserByESID) if (defined $getFolioUserByESID);

}

sub startJob
{

    my $jobType = "";
    $jobType .= "_stage" if ($stage);
    $jobType .= "_import" if ($import);

    my $job = {
        'job_type'   => "$stage$import",
        'start_time' => $dao->_getCurrentTimestamp,
        'stop_time'  => $dao->_getCurrentTimestamp,
    };

    $dao->_insertHashIntoTable("job", $job);
    $jobID = $dao->getLastJobID();

}

sub finishJob
{

    my $job_type = shift;

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
        --config                                      [Path to the config file] If none is specified patron-import.conf is used.
        --stage                                       This will stage patron records
        --import                                      This will load import records into folio.

        --getFolioUserByUsername                      returns a json users[] array of the folio user using the username as the search parameter
        --getFolioUserByESID                          returns a json users[] array of the folio user using the external system id as the search parameter
        \n";
    exit;
}

sub checkOptions
{

    # print a test message. Mainly for testing for our perl modules without actually executing any other code.
    if (defined($test))
    {
        print "We are working!\n";
        exit;
    }


    # god this is so dumb. I was watching youtube videos about binary and must have gotten inspired.
    # I'm going to fix this nonsense.

    # It's true/false 1 or 0 booleans. Binary
    # First is stage
    # This is kind of dumb. There's only 2 types so I guess it's not that bad.
    $stage = (defined($stage) ? 1 : 0);
    $import = (defined($import) ? 1 : 0);

    # if no args are passed in, then we do everything.
    if (!$stage && !$import)
    {
        $stage = 1;
        $import = 1;
    }

}