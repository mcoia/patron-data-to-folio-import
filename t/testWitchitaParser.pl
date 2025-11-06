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
    # For WITCHITA, ESID comes from CSV, but this is fallback
    return $self->{patron}->{esid} || $self->{patron}->{unique_id} || "default-esid";
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
my $csv_file = "/mnt/dropbox/kc-towers/home/kc-towers/incoming/patron-import/WITCHITA/import/patron_load.csv";

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

# Load the actual WitchitaParser code
require "Parsers/WitchitaParser.pm";

# Create test institution
my $institution = {
    id     => 99,
    name   => "WITCHITA",
    tenant => "witchita_tenant",
    esid   => "unique_id"  # ESID from username field
};

# Create parser instance
my $parser = Parsers::WichitaParser->new($institution);

# Test the parser with our actual CSV file
print "Testing parse() function with $csv_file...\n";

# Mock folder and file structure
$parser->{institution}->{folders} = [
    {
        name  => "WITCHITA Folder",
        files => [
            {
                name  => "patron_load.csv",
                paths => [ $csv_file ]
            }
        ]
    }
];

# Run the parser
my $patrons = $parser->parse();

# Display results
print "\n" . "=" x 80 . "\n";
print "PARSED PATRONS:\n";
print "=" x 80 . "\n";

print "Total patrons parsed: " . scalar(@$patrons) . "\n\n";

# Display first few patrons in detail
my $count = 0;
foreach my $patron (@$patrons) {
    $count++;
    print "-" x 80 . "\n";
    print "PATRON $count:\n";
    print "-" x 80 . "\n";

    # Display key fields
    print "Name:             " . ($patron->{name} || "") . "\n";
    print "Barcode:          " . ($patron->{barcode} || "") . "\n";
    print "Email:            " . ($patron->{email_address} || "") . "\n";
    print "ESID:             " . ($patron->{esid} || "") . "\n";
    print "Unique ID:        " . ($patron->{unique_id} || "") . "\n";
    print "Patron Type:      " . ($patron->{patron_type} || "") . "\n";
    print "PCODE1:           " . ($patron->{pcode1} || "") . "\n";
    print "PCODE2:           " . ($patron->{pcode2} || "") . "\n";
    print "PCODE3:           " . ($patron->{pcode3} || "") . "\n";
    print "Home Library:     " . ($patron->{home_library} || "") . "\n";
    print "Expiration Date:  " . ($patron->{patron_expiration_date} || "") . "\n";
    print "Address:          " . ($patron->{address} || "") . "\n";
    print "Telephone:        " . ($patron->{telephone} || "") . "\n";
    print "Address2:         " . ($patron->{address2} || "") . "\n";
    print "Telephone2:       " . ($patron->{telephone2} || "") . "\n";
    print "Fingerprint:      " . ($patron->{fingerprint} || "") . "\n";

    last if $count >= 5; # Show first 5 patrons in detail
}

print "\n" . "=" x 80 . "\n";
print "TEST COMPLETE\n";
print "=" x 80 . "\n";
