#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use lib qw(../lib);
use MOBIUS::DBhandler;
use MOBIUS::Utils;
use DAO;
use Parser;
use PatronImportFiles;

use Data::Dumper;

our ($conf, $log);
initConf();
initLog();

our $dao = DAO->new();
$dao->_initDatabaseCache();

our $files = PatronImportFiles->new();
our $parser = Parser->new();

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "/home/owner/repo/mobius/folio/patron-import/patron-import.conf";
    $conf = $utils->readConfFile($configFile);

    exit if ($conf eq "false");

}

sub initLog
{
    $log = Loghandler->new("test.log");
    $log->truncFile("");
}

# test_initDatabaseCache();
sub test_initDatabaseCache
{

    $dao->_initDatabaseCache();
    print Dumper($dao);

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

    $dao->_insertArrayIntoTable($tableName, \@data);
}

# test_DAO__selectAllFromTable();
sub test_DAO__selectAllFromTable
{
    my $tableName = "institution_map";
    my $data = $dao->_selectAllFromTable($tableName);

    print Dumper($data);

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
    our $jobID = 1;
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

# test_DAO_getStagedPatrons();
sub test_DAO_getStagedPatrons
{
    my $patrons = $dao->getStagedPatrons(0, 100);
    print Dumper($patrons);

}

# test_checkNames();
sub test_checkNames
{

    my @institutions = (
        'A.T. Still University',
        'Avila University',
        'Benedictine College',
        'Calvary University',
        'Central Methodist University',
        'Columbia College',
        'Conception Abbey and Seminary College',
        'Concordia Seminary',
        'Cottey College',
        'Covenant Theological Seminary',
        'Crowder College',
        'Culver-Stockton College',
        'Drury University',
        'East Central College',
        'Evangel University',
        'Fontbonne University',
        'Goldfarb School of Nursing at Barnes-Jewish College',
        'Hannibal-LaGrange University',
        'Harris-Stowe State University',
        'Jefferson College',
        'Kansas City Art Institute',
        'Kansas City Kansas Community College',
        'Kansas City University',
        'Kenrick-Glennon Theological Seminary',
        'Lincoln University',
        'Lindenwood University',
        'Logan University',
        'Maryville University',
        'Metropolitan Community College',
        'Midwestern Baptist Theological Seminary',
        'Mineral Area College',
        'Missouri Baptist University',
        'Missouri Botanical Garden',
        'Missouri History Museum',
        'Missouri Southern State University',
        'Missouri State Library',
        'Missouri Valley College',
        'Missouri Western State University',
        'Moberly Area Community College',
        'Nazarene Theological Seminary',
        'North Central Missouri College',
        'Northwest Missouri State University',
        'Ozark Christian College',
        'Ozarks Technical Community College',
        'Park University',
        'Rockhurst University',
        'Saint Louis Art Museum',
        'Saint Paul School of Theology',
        'Southwest Baptist University',
        'Southwestern Baptist Theological Seminary',
        'St. Charles Community College',
        'St. Louis Community College',
        'State Fair Community College',
        'State Technical College of Missouri',
        'Stephens College',
        'Three Rivers College',
        'Truman State University',
        'University of Health Sciences and Pharmacy in St. Louis',
        'Webster University',
        'Westminster College',
        'William Jewell College',
        'William Woods University',


    );

    print "\n\n";
    print "==================================================\n";
    print "\n\n";
    for my $institution (@institutions)
    {

        my $query = "select count(id) from patron_import.institution_map where institution = '$institution'";

        my $results = $dao->query($query)->[0]->[0];
        print "$institution\n" if ($results == 0);

    }

    print "\n\n";
}

# test_getStagedPatronByUsername();
sub test_getStagedPatronByUsername
{

    my $patron = $dao->getStagedPatronByUsername();

}

# test__insertHash();
sub test__insertHash
{

    my $patron = {
        'job_id'         => 27,
        'institution_id' => 1,
        'file_id'        => 209,
        'esid'           => "donya.johnsen\@student.eastcentral.edu",
        # 'fingerprint'            => "6fed6323a384ad9c550e1a2073ea01fa3ae7b5c6",
        # 'field_code'             => "0",
        # 'patron_type'            => "003",
        # 'pcode1'                 => "e",
        # 'pcode2'                 => "-",
        # 'pcode3'                 => "001",
        # 'home_library'           => "ecb  ",
        # 'patron_message_code'    => "-",
        # 'patron_block_code'      => "-",
        # 'patron_expiration_date' => "05-08-24",
        'name'           => "Johnsen, Donya R",
        # 'address'                => "550 Crestfall Dr\$Washington, MO  63090-7123",
        # 'telephone'              => "573-205-1594",
        # 'address2'               => "",
        # 'telephone2'             => "",
        # 'department'             => "ecb",
        # 'unique_id'              => "0005468EC",
        'barcode'        => "0005468",
        'email_address'  => "donya.johnsen\@student.eastcentral.edu",
        # 'note'                   => ""
    };

    $dao->_insertHashIntoTable("stage_patron", $patron);

}

# test_createTableFromHash();
sub test_createTableFromHash
{
    my $hash = {
        'name'       => 'Scott',
        'ptype'      => 5,
        'foliogroup' => 'staff'
    };

    # my $tableName = "ptype_mapping";
    my $tableName = "test";
    $dao->createTableFromHash($tableName, $hash);

}

# test_getFiles();
sub test_getFiles
{
    my $file = $dao->getFiles();
    print Dumper($file);
}

# test_getAllRecordsByTableName();
sub test_getAllRecordsByTableName
{
    my $results = $dao->_getAllRecordsByTableName("institution");
    print Dumper($results->[15]);

}

test_getInstitutionsFoldersAndFilesHash();
sub test_getInstitutionsFoldersAndFilesHash
{
    print "\n\ngetInstitutionsFoldersAndFilesHash()\n";
    print "==================================================================\n\n";
    $dao->getInstitutionsFoldersAndFilesHash();
    print "\n==================================================================\n\n";
}

1;