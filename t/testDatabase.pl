#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib qw(../lib);
use MOBIUS::DBhandler;
use MOBIUS::Utils;
use Data::Dumper;

my ($conf, $dbHandler);

initConf();
initDatabaseConnection();

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "/home/owner/repo/mobius/folio/patron-import/patron-import.conf";
    $conf = $utils->readConfFile($configFile);

    exit if ($conf eq "false");

}

sub initDatabaseConnection
{
    eval {$dbHandler = DBhandler->new($conf->{db}, $conf->{dbhost}, $conf->{dbuser}, $conf->{dbpass}, $conf->{port} || 5432, "postgres", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n";
        exit 1;
    }
}


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

# test_DAO_buildInstitutionMapTableData();
sub test_DAO_buildInstitutionMapTableData
{
    $dao->buildInstitutionMapTableData();
}

# test_DAO_getInstitutionMapTableSize();
sub test_DAO_getInstitutionMapTableSize
{
    my $size = $dao->getInstitutionMapTableSize();
    print "institution_map table size:[$size]\n";
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

# test_GenericParser_parse();
sub test_GenericParser_parse
{

    my $filePath = "/mnt/dropbox/archway/home/archway/incoming/eccpat.txt";

    my $patronFile = {
        'filename'       => $filePath,
        'job_id'         => 1,
        'id'             => 1,
        'institution_id' => => 1,
    };

    my $generic = Parsers::GenericParser->new();
    my $patronRecords = $generic->parse($patronFile);

    print Dumper($patronRecords);

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

# test_DAO_getLastFileTrackerEntryByFilename();
sub test_DAO_getLastFileTrackerEntryByFilename
{
    my $file_tracker = $dao->getLastFileTrackerEntryByFilename("/mnt/dropbox/archway/home/archway/incoming/eccpat.txt");
    print Dumper($file_tracker);

    $file_tracker = $dao->_convertQueryResultsToHash("file_tracker", $file_tracker);

    print Dumper($file_tracker);

}










1;