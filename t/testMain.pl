#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use Data::Dumper;

use MOBIUS::Utils;
use MOBIUS::Loghandler;
# use MOBIUS::DBhandler;
use DAO;
use Parser;
use PatronImportFiles;

# This is our test file
my $patronFilePath = "../resources/test-files/incoming/SLCCStaff";

our @clusters = qw(archway arthur avalon bridges explore kc-towers palmer swan swbts);

my ($conf, $log);

initConf();
initLog();

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

my $dao = DAO->new($conf, $log);
my $files = PatronImportFiles->new($conf, $log, $dao);
my $parser = Parser->new($conf, $log, $dao, $files);

# test_DAO_getDatabaseTableNames();
sub test_DAO_getDatabaseTableNames
{
    my $tableNames = $dao->_getDatabaseTableNames();
    print "[$_]\n" for (@{$tableNames});

}

# test_DAO_getTableColumnNames();
sub test_DAO_getTableColumnNames
{
    my $tableName = "file_tracker";
    my $columnNames = $dao->_getTableColumns($tableName);
    print "[$_]\n" for (@{$columnNames});
}

# test_DAO__insertIntoTable();
sub test_DAO__insertIntoTable
{
    my $tableName = "job";
    my @data = (
        $dao->_getCurrentTimestamp,
        $dao->_getCurrentTimestamp
    );

    # push(@data, $dao->_getCurrentTimestamp);
    # push(@data, $dao->_getCurrentTimestamp);

    $dao->_insertIntoTable($tableName, \@data);
}

# test_DAO__selectAllFromTable();
sub test_DAO__selectAllFromTable
{
    my $tableName = "institution_map";
    my $data = $dao->_selectAllFromTable($tableName);

    print Dumper($data);

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

# test__getInstitutionMapFromDatabase();
sub test__getInstitutionMapFromDatabase
{
    my $tableName = "institution_map";
    print Dumper(
        $dao->_convertQueryResultsToHash(
            $tableName, $dao->_selectAllFromTable($tableName)
        )
    );

}

# test_DAO_getInstitutionMapHashById();
sub test_DAO_getInstitutionMapHashById
{
    print Dumper(
        $dao->getInstitutionMapHashById(10)
    );

}

# test_DAO_getInstitutionMapHashByName();
sub test_DAO_getInstitutionMapHashByName
{
    my $name = "Central Methodist University";
    print Dumper(
        $dao->getInstitutionMapHashByName($name)
    );

}

# test_DAO_getLastFileTrackerEntry();
sub test_DAO_getLastFileTrackerEntry
{

    my $file = $dao->_convertQueryResultsToHash("file_tracker", $dao->getLastFileTrackerEntry())->[0];
    print Dumper($file);

    print $file->{id} . "\n";
    print $file->{job_id} . "\n";
    print $file->{institution_id} . "\n";
    print $file->{filename} . "\n";

}

# test_getPatronFilePaths();
sub test_getPatronFilePaths
{

    # real    2m11.809s
    $conf->{jobID} = 1;
    my $filesHashArray = $files->getPatronFilePaths();

    print Dumper($filesHashArray);

}

# test_DAO_getLastJobID();
sub test_DAO_getLastJobID
{

    my $id = $dao->getLastJobID();
    print "id:[$id]\n";

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

1;