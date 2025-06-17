#!/usr/bin/perl

use strict;
use warnings;
use Data::Dumper;
use lib '../lib'; # Adjust based on your directory structure


# Mock necessary modules and globals
package Parsers::ESID;
sub new
{
    my ($class, $institution, $patron) = @_;
    return bless {
        institution => $institution,
        patron      => $patron
    }, $class;
}
sub getESID
{
    my $self = shift;
    return $self->{patron}->{unique_id} || "default-esid";
}
1;

package MOBIUS::Utils;
sub new
{return bless {}, shift;}
sub getHash
{return "mock-fingerprint-" . int(rand(1000));}
1;

package main;

# Path to your actual CSV file
my $csv_file = "../StateTechPatrons.csv";

# Create test environment
our $conf = { print2Console => 1 };
our $jobID = 1234;
our $dao = bless {}, 'MockDAO';
sub MockDAO::getFileTrackerIDByJobIDAndFilePath
{return 5678;}

our $parserManager = bless {}, 'MockParserManager';
sub MockParserManager::getPatronFingerPrint
{return MOBIUS::Utils->new()->getHash(shift);}

our $log = bless {}, 'MockLog';
sub MockLog::addLine
{print "LOG: " . shift . "\n";}

# Load the actual StateTechParser code
require "Parsers/StateTechParser.pm";

# Create test institution
my $institution = {
    id     => 42,
    name   => "State Tech",
    tenant => "state_tech_tenant",
    esid   => "unique_id"
};

# Create parser instance
my $parser = Parsers::StateTechParser->new($institution);

# Test the parser with our actual CSV file
print "Testing parse() function with $csv_file...\n";

# Mock folder and file structure
$parser->{institution}->{folders} = [
    {
        name  => "State Tech Folder",
        files => [
            {
                name  => "StateTechPatrons.csv",
                paths => [ $csv_file ]
            }
        ]
    }
];

my $parsed_patrons = $parser->parse();
print "Total patrons parsed: " . scalar(@$parsed_patrons) . "\n";

# Print the first few patrons as a sample
my $sample_size = 3;
for (my $i = 0; $i < $sample_size && $i < scalar(@$parsed_patrons); $i++)
{
    print "\nPatron " . ($i + 1) . ":\n";
    print Dumper($parsed_patrons->[$i]);
}

print "\nTest completed!\n";