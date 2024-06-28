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

our ($conf, $log, $dao, $files, $parser, $folio, $getFolioUserByUsername, $getFolioUserByESID, $getFolioPatronGroupByInstitutionId);

GetOptions(
    "config=s"                             => \$configFile,
    "getFolioUserByUsername:s"             => \$getFolioUserByUsername,
    "getFolioUserByESID:s"                 => \$getFolioUserByESID,
    "getFolioPatronGroupByInstitutionId:s" => \$getFolioPatronGroupByInstitutionId,
)
    or die("Error in command line arguments\nPlease see --help for more information.\n");

initConf();
initLogger();
instantiateObjects();
main();

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

sub instantiateObjects
{
    # Create our main objects
    $dao = DAO->new();
    $files = FileService->new();
    $dao->_cacheTableColumns();
    $parser = Parser->new();
    $folio = FolioService->new();
}

sub main
{

    # Used to run specific methods from the command line.
    $folio->getFolioUserByUsername($getFolioUserByUsername) if (defined $getFolioUserByUsername);
    $folio->getFolioUserByESID($getFolioUserByESID) if (defined $getFolioUserByESID);
    $folio->getFolioPatronGroupsByInstitutionId($getFolioPatronGroupByInstitutionId) if (defined $getFolioPatronGroupByInstitutionId);

}

