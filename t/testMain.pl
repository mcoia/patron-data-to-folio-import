#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Try::Tiny;
use lib qw(../lib);
use Data::Dumper;

use MOBIUS::Utils;
use MOBIUS::Loghandler;

use DAO;
use FileService;
use Parser;
use Parsers::GenericParser;

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
'123 Main St$Anytown, USA 12345-6789',
'456 Elm St$Anytown, USA 12345-6789',
'789 Maple Ave$Anytown, USA 12345-6789',
'1011 Oak St$Anytown, USA 12345-6789',
'1213 Pine St$Anytown, USA 12345-6789',
'1415 Cedar St$Anytown, USA 12345-6789',
'1617 Birch St$Anytown, USA 12345-6789',
'1819 Walnut St$Anytown, USA 12345-6789',
'2021 Chestnut St$Anytown, USA 12345-6789',
'2223 Ash St$Anytown, USA 12345-6789',
'2425 Spruce St$Anytown, USA 12345-6789',
'2627 Fir St$Anytown, USA 12345-6789',
'2829 Redwood St$Anytown, USA 12345-6789',
'3031 Palm St$Anytown, USA 12345-6789',
'3233 Cypress St$Anytown, USA 12345-6789',
'3435 Hickory St$Anytown, USA 12345-6789',
'3637 Dogwood St$Anytown, USA 12345-6789',
'3839 Magnolia St$Anytown, USA 12345-6789',
'4041 Poplar St$Anytown, USA 12345-6789',
'4243 Willow St$Anytown, USA 12345-6789',
'4445 Sycamore St$Anytown, USA 12345-6789',
'4647 Beech St$Anytown, USA 12345-6789',
'4849 Maplewood St$Anytown, USA 12345-6789',
'5051 Sequoia St$Anytown, USA 12345-6789',
'5253 Laurel St$Anytown, USA 12345-6789',
'5455 Juniper St$Anytown, USA 12345-6789',
'5657 Myrtle St$Anytown, USA 12345-6789',
'5859 Cedarwood St$Anytown, USA 12345-6789',
'6061 Pinewood St$Anytown, USA 12345-6789',
'6263 Elmwood St$Anytown, USA 12345-6789',
'6465 Maplewood St$Anytown, USA 12345-6789',
'6667 Birchwood St$Anytown, USA 12345-6789',
'6869 Redwoodwood St$Anytown, USA 12345-6789',
'7071 Firwood St$Anytown, USA 12345-6789',
'7273 Willowwood St$Anytown, USA 12345-6789',
'7475 Poplarwood St$Anytown, USA 12345-6789',
'7677 Magnoliawood St$Anytown, USA 12345-6789',
'7879 Dogwoodwood St$Anytown, USA 12345-6789',
'8081 Hickorywood St$Anytown, USA 12345-6789',
'8283 Cypresswood St$Anytown, USA 12345-6789',
'8485 Palmwood St$Anytown, USA 12345-6789'
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

# test_query();
sub test_query
{

    my $query = "select * from patron_import.address a limit 10";
    print Dumper($dao->query($query));

}

# scanFilesForIllegalChars();
sub scanFilesForIllegalChars
{

    my $query = "select * from patron_import.file_tracker ft";
    my $data = $dao->query($query);

    my @illegalChars = qw(" \ \b \f \n \r \t);

    my @illegalCharsFound = ();
    my $lineNumber = 0;

    for my $row (@{$data})
    {

        $lineNumber = 0;
        my $path = $row->[3];
        print "Scanning $path\n";
        my $file = $files->readFileToArray($path);
        for my $line (@{$file})
        {

            # loop thru each char in the line and compare it to $ascii. If it's not in $ascii, print it.
            for my $char (split(//, $line))
            {

                # check $char against @illegalChars and if it's in there, print it out
                if (grep {$_ eq $char} @illegalChars)
                {
                    # print "Illegal character found: $char\n";
                    push(@illegalCharsFound, {
                        path  => $row->[3],
                        line  => $lineNumber,
                        char  => $char,
                        ascii => ord($char),
                        hex   => sprintf("%x", ord($char)),
                        dec   => ord($char),
                    });
                }


            }

            $lineNumber++;
        }
    }

    # print out all the illegal chars
    print Dumper(\@illegalCharsFound);

}

# test_patronRawData();
sub test_patronRawData
{

    my $query = "select p.raw_data from patron_import.patron p limit 3";

    for (@{$dao->query($query)})
    {
        my @rawData = split(/\n/, $_->[0]);

        my $zeroLine = shift(@rawData);

        my $ptype = substr($zeroLine, 1, 3);

        print $ptype . "\n";

    }

}

# rebuildJeffersonPatronFile();
sub rebuildJeffersonPatronFile
{

    my $query = "select p.raw_data from patron_import.patron p where p.institution_id =3 ";

    my $results = $dao->query($query);

    my $filename = "./jcpat.txt";
    for (@{$results})
    {
        print $_->[0];

        # save $_->[0] to a file called jcpat.txt
        open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
        print $fh $_->[0];
        close $fh;

    }

}

# test_deleteFile();
sub test_deleteFile
{

    my $path = "/home/owner/tmp/search";
    print "deleting $path\n";
    unlink $path;

}

1;
