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
use SierraFolioParser;

our $configFile;
our $db;
our $conf;
our $log;

# Local imports  
our $parser;
our $files;

GetOptions(
    "config=s" => \$configFile,
)
    or die("Error in command line arguments\nYou can specify
--config                                      [Path to the config file]
\n");

initConf();
initLogger();
initDatabase();
main();

sub main
{
    setJobID();
    $files = PatronImportFiles->new($conf, $log, $db);
    $parser = SierraFolioParser->new($conf, $log, $db, $files);

    # Find patron files
    my $patronFiles = $files->getPatronFilePaths();

    # loop over our discovered files. Parse, Load, Report <== maybe these should be functions? Report(Load(Parsed())); lol
    for my $patronFile (@$patronFiles)
    {

        # Note: $patronFile is a hash vvvvvv not an array. I keep thinking this is a nested array at first glance. It's not.
        for my $file (@{$patronFile->{files}})
        {

            # Read patron file into an array
            my $data = $files->readFileToArray($file);

            # Parse our data into patron records
            my $patronRecords = $parser->parse($file, $patronFile->{cluster}, $patronFile->{institution}, $data);
            $parser->savePatronRecords($patronRecords);

        }

    }

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
    my $query = "drop table if exists job,patron_import_files,patron;";
    $db->update($query);
}

sub initDatabaseSchema
{

    my $filePath = $conf->{sqlFilePath};

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";

    my $query = "";
    while (my $line = <$fileHandle>) {$query = $query . $line;}
    close $fileHandle;
    $db->update($query);

}

sub setJobID
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

exit;