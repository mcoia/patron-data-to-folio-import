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
initDatabaseConnection();
main();

sub main
{
    my $jobID = getJobID();
    $files = PatronImportFiles->new($conf, $log, $db);
    $parser = SierraFolioParser->new($conf, $log, $db, $files);

    # Find patron files
    my $patronFiles = $files->getPatronFilePaths();

    # loop over our discovered files. Parse, Load, Report
    for my $patronFile (@$patronFiles) # can I do this [0] to eliminate the nested array? for my $patronFile (@$patronFiles[0])
    {

        for my $file (@{$patronFile->{files}})
        {

            # Read patron file into an array
            my $data = $files->readFileToArray($file);

            # Parse our data into usable json.
            my $jsonArray = $parser->parse($file, $patronFile->{cluster}, $patronFile->{institution}, $data);

            for my $json ($jsonArray)
            {
                print "$json\n";
                $log->addLine($json);
            }


=pod
            https://github.com/folio-org/mod-user-import
            Note: $jsonArray is just the user portion of the request. There's more to this json POST request.
            We still need to wrap the jsonArray into an official folio compatible request.
            $jsonArray is essentially the array of "users":[] listed below.

           This is the rest of our json.

           {
               "users": [@$jsonArray], <-- but with commas after each {data},
               "totalRecords": 1,
               "deactivateMissingUsers": $conf->{deactivateMissingUsers},
               "updateOnlyPresentFields": $conf->{updateOnlyPresentFields},
               "sourceType": "test"
           }

=cut

            # Build json from template for parsed patrons


            # submit to folio

            # generate any reports/emails

        }

    }

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

sub initDatabaseConnection
{
    eval {$db = DBhandler->new($conf->{db}, $conf->{dbhost}, $conf->{dbuser}, $conf->{dbpass}, $conf->{port} || 5432, "postgres", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n";
        exit 1;
    }
}

sub getJobID
{

    my $query = "insert into job(start_time,stop_time) values (CURRENT_TIMESTAMP, CURRENT_TIMESTAMP);";
    $db->update($query);

    $query = "select * from job where start_time = stop_time order by ID desc limit 1;";

    my @results = @{$db->query($query)};
    my $id = $results[0][0];

    print Dumper($id);
    print "id: " . $id . "\n";

    exit;

}

exit;