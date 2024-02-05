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

our $db;
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
initDatabase();

print "runType: [$runType]\n";
print "help: \n" if (defined $help);

sub main
{
    startJob();

    # Create our main objects
    $files = PatronImportFiles->new($conf, $log, $db);
    $parser = Parser->new($conf, $log, $db, $files);

    ########## stage | load ##########
    # We need to split this so we can run parsers and api loads separate
    $parser->stagePatronRecords() if($runType eq "stage");








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

sub initDatabase
{
    initDatabaseConnection();
    dropTables(); # TODO; Remove for production.
    initDatabaseSchema();
}

sub initDatabaseConnection
{
    eval {$db = DBhandler->new($conf->{db}, $conf->{dbhost}, $conf->{dbuser}, $conf->{dbpass}, $conf->{port} || 5432, "postgres", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n";
        exit 1;
    }
}

sub dropTables
{
    my $query = "drop table if exists job,patron_import_files,patron,stage_patron;";
    $db->update($query);
}

sub initDatabaseSchema
{

    my $filePath = $conf->{sqlFilePath};

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";

    my $query = "";
    while (my $line = <$fileHandle>)
    {$query = $query . $line;}
    close $fileHandle;
    $db->update($query);

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
        \n";
}

exit;