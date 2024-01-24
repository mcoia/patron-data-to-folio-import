#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use Data::Dumper;

use MOBIUS::Utils;
use MOBIUS::Loghandler;

use SierraFolioParser;
use PatronImportFiles;

# This is our test file
my $patronFilePath = "../resources/test-files/incoming/SLCCStaff";
# my $patronFilePath = "../resources/test-files/incoming/SLCCStaff-1";

my $log = Loghandler->new("test.log");
$log->truncFile("");

our @clusters = qw(archway arthur avalon bridges explore kc-towers palmer swan swbts);

my $conf;

my $parser = SierraFolioParser->new($log);
my $files = PatronImportFiles->new($conf, $log, ".", \@clusters);


test_processPatronRecord();

sub test01
{
    my @data = @{$files->readFileToArray($patronFilePath)};
    my $json = $parser->parse(\@data);
   
    print $json;
}

sub test02
{
    my $patron;
    $patron->{username} = "scott";

    my $json = $parser->_jsonTemplate($patron);

    print $json;

}

sub test_processPatronRecord
{
    # my $patronRecord = shift;
    
    my @patronRecord = ();

    push(@patronRecord, "0012--000srb  --07-31-24");
    push(@patronRecord, "nSOUCHEK, MARILYN KAY");
    push(@patronRecord, "a239 MARTIGNEY DR\$SAINT LOUIS, MO 63129-3411");
    push(@patronRecord, "t618-789-2955");
    push(@patronRecord, "h239 MARTIGNEY DR\$SAINT LOUIS, MO 63129-3411");
    push(@patronRecord, "t618-789-2955");
    push(@patronRecord, "dlmb");
    push(@patronRecord, "uA02559733ST");
    push(@patronRecord, "bA02559733ST");
  
    print "0155m 004lmb    06-30-24\n";
    my $patronHash = $parser->_parsePatronRecord(\@patronRecord);

    print Dumper($patronHash);
   
    
   
    print "Note: $patronHash->{note}\n";
    
    
    
    
}

1;