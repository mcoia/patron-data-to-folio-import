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

$| = 1;  # Disable output buffering on STDOUT

my $configFile;

our ($conf, $log, $dao, $files, $parserManager, $folio, $getFolioUserByUsername, $getFolioUserByESID, $getFolioPatronGroupByInstitutionId, $processInstitutionId);

GetOptions(
    "config=s"                             => \$configFile,
    "getFolioUserByUsername:s"             => \$getFolioUserByUsername,
    "getFolioUserByESID:s"                 => \$getFolioUserByESID,
    "getFolioPatronGroupByInstitutionId:s" => \$getFolioPatronGroupByInstitutionId,
    "processInstitutionId:s"               => \$processInstitutionId,
)
    or die("Error in command line arguments\nPlease see --help for more information.\n");

initConf();
initLogger();
instantiateObjects();
main();

=pod

                !!!! PLEASE NOTE !!!!
                You have to symlink the patron-data-to-folio-import in the server/ directory for the angular app.

                We print to the console and express.js reads whatever this thing prints out.
                Of course we just print out JSON so we can use this as an API.
                if you print something else to the console, it will be read by express.js and sent to the client.
                That's why this api.pl was created, to simplify api request and contain these print statements.


=cut

sub main
{

    # Used to run specific methods from the command line.
    print $folio->getFolioUserJSONByUsername($getFolioUserByUsername) if (defined $getFolioUserByUsername);
    print $folio->getFolioUserJSONByESID($getFolioUserByESID) if (defined $getFolioUserByESID);
    print $folio->getFolioPatronGroupsByInstitutionId($getFolioPatronGroupByInstitutionId) if (defined $getFolioPatronGroupByInstitutionId);
    processInstitutionId() if (defined $processInstitutionId);

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

    if ($processInstitutionId)
    {
        $logFileName = lc $conf->{logfile} =~ s/\{epoch\}/_$epoch/gr if ($conf->{logfile} =~ /\{epoch\}/);
        $logFileName = $processInstitutionId . "_manual_$epoch.log";
    }

    $log = Loghandler->new($logFileName);
    $log->truncFile("");

}

sub instantiateObjects
{
    # Create our main objects
    $dao = DAO->new();
    $files = FileService->new();
    $dao->_cacheTableColumns();
    $parserManager = ParserManager->new();
    $folio = FolioService->new();
}

sub processInstitutionId
{

    my $institution_id = $processInstitutionId;

    # Create our main objects
    $dao = DAO->new();
    $files = FileService->new();
    $dao->_cacheTableColumns();

    $dao->startJob();

    $parserManager->stagePatronRecords($main::dao->getInstitutionsFoldersAndFilesHash($institution_id));
    $folio->importPatronsByInstitutionId($institution_id) if($conf->{web_import} eq 'true');

    $dao->finishJob();

}
