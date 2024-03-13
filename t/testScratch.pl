#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use POSIX;

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

test_hello();
sub test_hello
{

    printHeader();

    # insert into table (col)
    # Values
    #     (row1_val),
    #     (row2_val),
    #     (row3_val)
    # ;


    my $createTableSQL = "create table if not exists patron_import.test (id     SERIAL primary key, rand   int, word text);";
    $dao->query($createTableSQL);

    my @data = ();
    push(@data, ceil(rand(100))) for (0 .. 10);
    print "@data\n";

    my $dataSize = @data;

    my $values = "";
    $values .= "(\$" . $_ . ")," for (1 .. $dataSize);
    chop($values);

    my $query = "INSERT INTO patron_import.test (rand) values $values";
    print $query;
    $dao->{db}->updateWithParameters($query, \@data);

    printHeader();
}

sub printHeader
{
    print "\n\n";
    print "==================================================";
    print "\n\n";

}

# test_01();
sub test_01
{
print "\n\n\n";
    my $query = "INSERT INTO patron_import.stage_patron
        (esid,fingerprint,field_code,patron_type,pcode1,pcode2,pcode3,home_library,patron_message_code,patron_block_code,patron_expiration_date,name,address,telephone,address2,telephone2,department,unique_id,barcode,email_address,note)
    values (\$1),(\$2)";
    my @record = (
        "",
        "d4e82aac5c65e1bd16b5b97340c95aa55d5e1b34",
        "0",
        "003",
        "e",
        "-",
        "001",
        "ecb  ",
        "-",
        "-",
        "05-08-24",
        "Johnsen, Donya R",
        "550 Crestfall Dr\$Washington, MO  63090-7123",
        "573-205-1594",
        "",
        "",
        "ecb",
        "0005468EC",
        "0005468",
        "donya.johnsen\@student.eastcentral.edu",
        "");

    print scalar(@record) . "\n";
    print @record;
    print "\n";
    print "@record\n";

    my @data = ();
    push(@data, \@record);
    push(@data, \@record);

    # $main::dao->update($query, \@data);

}

1;