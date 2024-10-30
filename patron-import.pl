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
use ParserManager;
use DAO;

my $configFile;
my $help;

our ($conf, $log, $dao, $files, $parserManager, $folio, $jobID, $import, $stage, $test, $initDB);

GetOptions(
    "config=s" => \$configFile,
    "help:s"   => \$help,
    "import:s" => \$import,
    "stage:s"  => \$stage,
    "test:s"   => \$test,
    "initDB:s" => \$initDB,
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

    $dao->startJob();
    $folio = FolioService->new();
    $parserManager = ParserManager->new();

    $parserManager->stagePatronRecords($main::dao->getInstitutionsFoldersAndFilesHash()) if ($stage);
    $folio->importPatronsForEnabledInstitutions() if ($import);

    $dao->finishJob();

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
    # Extract hours and minutes
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
    my $hhmm = sprintf("%02d%02d", $hour, $min);

    $time =~ s/\d\d:\d\d:\d\d\s//g;
    $time =~ s/\s/_/g;

    # Append hhmm to time
    $time .= "_$hhmm";
    $time = lc $time;

    my $logFileName = $conf->{logfile};
    $logFileName = lc $conf->{logfile} =~ s/\{time\}/_$time/gr if ($conf->{logfile} =~ /\{time\}/);

    $log = Loghandler->new($logFileName);
    $log->truncFile("");
}

sub getHelpMessage
{

    print
        "You can specify
        --config                                      [Path to the config file] If none is specified patron-import.conf is used.
        --stage                                       This will stage patron records
        --import                                      This will load import records into folio.
        --initDB                                      This will initialize the database.

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