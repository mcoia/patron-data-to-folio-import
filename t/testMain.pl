#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use Data::Dumper;

use MOBIUS::Utils;
use MOBIUS::Loghandler;

use DAO;
use FileService;
use Parser;
use Parsers::GenericParser;

# This is our test file
my $patronFilePath = "../resources/test-files/incoming/SLCCStaff";

our @clusters = qw(archway arthur avalon bridges explore kc-towers palmer swan swbts);

our ($conf, $log);

initConf();
initLog();

our $dao = DAO->new();
our $files = FileService->new();
our $parser = Parser->new();

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "../patron-import.conf";

    $conf = eval {$utils->readConfFile($configFile);};

    if ($conf eq 'false')
    {
        print "trying other location... we must be debugging\n";
        $configFile = "./patron-import.conf";
        $conf = eval {$utils->readConfFile($configFile);};
    }

}

sub initLog
{
    $log = Loghandler->new("test.log");
    $log->truncFile("");
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

# test_getStagedPatrons();
sub test_getStagedPatrons
{

    my $patrons = $parser->getStagedPatrons();

    print Dumper($patrons);

}

# test_loadMOBIUSPatronLoadsCSV();
sub test_loadMOBIUSPatronLoadsCSV
{

    my $csv = $files->_loadMOBIUSPatronLoadsCSV();
    print Dumper($csv);

}

# test_buildDCBPtypeMappingFromCSV();
sub test_buildDCBPtypeMappingFromCSV
{
    $files->buildPtypeMappingFromCSV();
}

# test__loadSSO_ESID_MappingCSV();
sub test__loadSSO_ESID_MappingCSV
{
    $dao->_initDatabaseCache();
    print "_loadSSO_ESID_MappingCSV\n";
    $files->_loadSSO_ESID_MappingCSV();
}

# test_parsePatronRecord();
sub test_parsePatronRecord
{
    my $institution = {
        'name'   => 'TEST',
        'id'     => 1,
        'folder' => {
            'id'    => 1,
            'files' => [
                {
                    'id'             => 1,
                    'name'           => 'ccstupat.txt',
                    'paths'          => [
                        '/mnt/dropbox/swan/home/swan/incoming/ccstupat.txt'
                    ],
                    'institution_id' => 1,
                    'pattern'        => 'ccstupat'
                }
            ],
            'path'  => '/mnt/dropbox/swan/home/swan/incoming'
        },
        'esid'   => '',
        'module' => 'GenericParser'
    };

    my $genericParser = Parsers::GenericParser->new();
    my $data = $genericParser->parse($institution);

}

# test_ptypeMappingIssue();
sub test_ptypeMappingIssue
{
=pod
I want to load up all the patron files that don't map to a ptype and figure out why.
=cut

    my $query = "drop table if exists patron_import.issue; create table if not exists patron_import.issue (zeroline text, path text)";
    $dao->{db}->query($query);
    $dao->_cacheTableColumns();

    # get all the paths where
    $query = "select distinct ft.path
                from patron_import.file_tracker ft
                     join patron_import.institution i on ft.institution_id = i.id
                     join patron_import.patron p on p.institution_id = i.id
              where p.patrongroup is NULL;";

    my $data = $dao->{db}->query($query);

    for my $path (@{$data})
    {

        print "Grabbing all zero fields... $path->[0]\n";
        for my $file ($files->readFileToArray($path->[0]))
        {
            for my $line (@{$file})
            {
                $dao->_insertHashIntoTable("issue", {
                    'zeroline' => $line,
                    'path'     => $path->[0]
                }) if ($line =~ /^0/);;

            }
        }

    }

}

# extract_patron_files();
sub extract_patron_files
{

    my $query = "select ft.path from patron_import.file_tracker ft;";
    for my $row (@{$dao->query($query)})
    {
        my $path = $row->[0];
        print "adding $path\n";
        my $command = `zip -r patron-import.zip $path`
            if ($path !~ "KCAI");
    }

}

testTings();
sub testTings
{
   print "getPatronImportPendingSize: [" . $dao->getPatronImportPendingSize() . "]\n";
}

1;