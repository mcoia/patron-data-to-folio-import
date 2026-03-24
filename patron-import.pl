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

our ($conf, $log, $dao, $files, $parserManager, $folio, $jobID, $import, $stage, $test, $initDB, $email, $institution, $debug);

GetOptions(
    "config=s"       => \$configFile,
    "help"           => \$help,
    "import"         => \$import,
    "stage"          => \$stage,
    "test"           => \$test,
    "email=s"        => \$email,
    "institution=i"  => \$institution,
    "debug"          => \$debug,
    "initDB"         => \$initDB,
)
    or die("Error in command line arguments\nPlease see --help for more information.\n");

getHelpMessage() if (defined $help);

initConf();
initLogger();
checkOptions();
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
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime();
    $year += 1900;
    $mon += 1;

    my $time = sprintf("%04d-%02d-%02d_%02d%02d", $year, $mon, $mday, $hour, $min);

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
        if ( (defined($email)) && (defined($institution)) )
        {
            $dao = DAO->new();
            $dao->_cacheTableColumns();
            $files = FileService->new();
            my $institutions = $dao->getInstitutionsHashByEnabled();
            my $didSomething = 0;
            foreach(@$institutions)
            {
                if($_->{id} == $institution)
                {
                    # Override the To email address(es) with the user provided test email address
                    $_->{emailsuccess} = $email;
                    $jobID = $dao->getLastJobIDForInstitution($institution);
                    my $importResponseTotals = $dao->getImportResponseTotalsForInstitution($institution, $jobID);
                    print Dumper($_) if $debug;
                    print Dumper($jobID) if $debug;
                    print Dumper($importResponseTotals) if $debug;
                    my @importFailedUsers = ();
                    PatronImportReporter->new($_, $importResponseTotals, \@importFailedUsers, $debug)->buildReport()->sendEmail();
                    $didSomething = 1;
                }
            }
            print "Provided institution wasn't enabled or doesn't exit" unless $didSomething;
        }

        exit;
    }

    # if no args are passed in, then we do everything.
    if (!$stage && !$import)
    {
        $stage = 1;
        $import = 1;
    }

}