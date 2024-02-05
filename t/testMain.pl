#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use Data::Dumper;

use MOBIUS::Utils;
use MOBIUS::Loghandler;
use MOBIUS::DBhandler;
use SierraFolioParser;
use PatronImportFiles;

# This is our test file
my $patronFilePath = "../resources/test-files/incoming/SLCCStaff";

our @clusters = qw(archway arthur avalon bridges explore kc-towers palmer swan swbts);

my ($conf, $log, $db);

initConf();
initLog();
initDatabaseConnection();

my $files = PatronImportFiles->new($conf, $log, $db, \@clusters);
my $parser = Parser->new($conf, $log, $db, $files);

sub readPtypeWorksheet
{

    my $worksheet = $files->getPTYPEMappingSheet("scratch");
    my $patronFiles = $files->getPatronFilePaths();

    for my $row (@$worksheet)
    {


    }

}

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

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "../patron-import.conf";
    $conf = $utils->readConfFile($configFile);

}

sub initLog
{
    $log = Loghandler->new("test.log");
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

# test_parseName();
sub test_parseName
{

    my @a = (
        'Altis, Daniel M.',
    );

    for (@a)
    {

        my $patron = {
            'name' => $_,
        };

        $patron = $parser->_parseName($patron);
        print Dumper($patron);

    }

}

# test_parseAddress();
sub test_parseAddress
{

    my @address = (
        '550 Crestfall Dr$Washington, MO  63090-7123',
        '201 Washington Heights Dr.$Washington, MO  63090',
        '860 Bellerive Pl$Washington, MO  63090',
        '2 Robin Way$Sullivan, MO  63080',
        '6569 Hwy JJ$Sullivan, MO  63080',
        'PO Box 1729$Washington, MO  63090',
        '651 Falcon Dr$Sullivan, MO  63080',
        '1350 Country Air Drive$St. Clair, MO  63077',
        '914 Glenn Ave.$Washington, MO  63090',
        '112 Jacqueline Drive$Washington, MO  63090',
        '1045 W 8th$Washington, MO  63090',
        '7203 Highway BB$Union, MO  63084',
        '35605 Maries Road 405$Belle, MO  65013',
        '7 Madison Ct$Villa Ridge, MO  63089',
        '231 Miller St$Sullivan, MO  63080',
        '110 Emmons St$New Haven, MO  63068',
        '344 Holtgrewe Farms Loop$Washington, MO  63090',
        '5372 Hwy 100$Washington, MO  63090',
        '915 Virginia Mines Rd$St. Clair, MO  63077',
        '114 Chapel Ridge Dr Apt 101$Union, MO  63084',
        '218 Wiley Lane$Union, MO  63084',
        '524 Hughes Ford Rd$Sullivan, MO  63080',
        '398 Excelsior Bluff Drive$New Haven, MO  63068',
        '1345 Thomas Dr$Rolla, MO  65401',
        '7281 Koko Beach Rd$Union, MO  63084',
        '108 Youngridge Dr$Union, MO  63084',
        '1000 N Christina Ave$Union, MO  63084',
        '10 Clark Dr$Union, MO  63084',
        '442 Pickles Ford Road$St. Clair, MO  63077',
        '120 E Vine$Sullivan, MO  63080',
        '11200 Greenfield Dr$Rolla, MO  65401',
        '1554 Villa Vista Drive$Owensville, MO  65066',
        '5801 Hwy 19$Cuba, MO  65453',
        '2405 Sue Lynn Dr$High Ridge, MO  63049',
        '1030 Prairie St.$Sullivan, MO  63080',
        '13 Buckingham Drive$Washington, MO  63090',
        '340 Saint Francis Ave$St. James, MO  65559');

    for (@address)
    {

        my $patron = {
            'address' => $_,
        };

        $patron = $parser->_parseAddress($patron);
        print Dumper($patron);

    }

}

test_getStagedPatrons();
sub test_getStagedPatrons
{

    my $patrons = $parser->getStagedPatrons();

    print Dumper($patrons);

}

sub test_getParserObject
{


    my $institution = "archway";
    my $patronRecord = "no-data";

    $parser->getParserObject($institution, $patronRecord);



}

1;