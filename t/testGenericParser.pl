#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use lib qw(../lib);

use Parser;
use Parsers::GenericParser;

test_parse();
sub test_parse
{

    # Searching for files...
    # Harris-Stowe State University: /mnt/dropbox/bridges/home/bridges/incoming
    # File Found: [Harris-Stowe State University]:[/mnt/dropbox/bridges/home/bridges/incoming/HSSU]
    # Total Patrons: [0]

    # Fontbonne University: /mnt/dropbox/bridges/home/bridges/incoming
    # File Found: [Fontbonne University]:[/mnt/dropbox/bridges/home/bridges/incoming/FCstuPAT.DAT]
    # File Found: [Fontbonne University]:[/mnt/dropbox/bridges/home/bridges/incoming/FCfacPAT.DAT]
    # Total Patrons: [2]

    # Logan University: /mnt/dropbox/bridges/home/bridges/incoming
    # File Found: [Logan University]:[/mnt/dropbox/bridges/home/bridges/incoming/loganstu.txt]

    # File Found: [Kansas City KS Community College]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/KCKCC_LIB_STU.txt]
    # File Found: [Kansas City KS Community College]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/KCKCC_LIB_EMP.txt]
    # File Found: [Kansas City KS Community College]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/KCKCC_LIB_EMP_102623_0848]

    # the first few records in this section finished really quick
    # File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuugr.txt]
    # File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsugr.txt]
    # File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsufac.txt]
    # File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuexp.txt]
    # File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuadj.txt]
    # File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuinst.txt]
    # File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuwdraw.txt]
    # Total Patrons: [4555]

    # Rockhurst University: /mnt/dropbox/kc-towers/home/kc-towers/incoming
    # File Found: [Rockhurst University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/RKRST_Stu_01-17-2024.txt]
    # File Found: [Rockhurst University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/RKRST_Staff_01-10-2024.txt]
    # File Found: [Rockhurst University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/RKRST_Faculty_01-10-2024.txt]
    # Total Patrons: [3314]

    # Drury University: /mnt/dropbox/swan/home/swan/incoming
    # File Found: [Drury University]:[/mnt/dropbox/swan/home/swan/incoming/DRURYPAT_students.TXT]
    # File Found: [Drury University]:[/mnt/dropbox/swan/home/swan/incoming/DRURYPAT_employees.TXT]
    # File Found: [Drury University]:[/mnt/dropbox/swan/home/swan/incoming/DRURYPAT_alumni.TXT]
    # Total Patrons: [3]

    # /mnt/dropbox/swan/home/swan/incoming/DRURYPAT_students.TXT
    # /mnt/dropbox/swan/home/swan/incoming/DRURYPAT_employees.TXT
    # /mnt/dropbox/swan/home/swan/incoming/DRURYPAT_alumni.TXT

    my $path = "/mnt/dropbox/swan/home/swan/incoming/DRURYPAT_employees.TXT";

    my $parser = Parsers::GenericParser->new();

    my @parsedPatrons = ();
    my @patronRecords = ();
    my @patronRecord = ();
    my $patronRecordSize = 0;

    # Read our patron file into an array.
    my $data = readFileToArray($path);

    for my $line (@{$data})
    {

        # if ($line =~ /^0/ && length($line) == 24)
        if ($line =~ /^0/)
        {
            $patronRecordSize = @patronRecord;
            my @patronRecordCopy = @patronRecord;
            push(@patronRecords, \@patronRecordCopy) if ($patronRecordSize > 0);
            @patronRecord = ();
        }

        push(@patronRecord, $line);

    }

    # Push our last record
    $patronRecordSize = @patronRecord;
    push(@patronRecords, \@patronRecord) if ($patronRecordSize > 0);

    # Now we do the actual parsing of this data.
    for my $record (@patronRecords)
    {

        my $patron = $parser->_parsePatronRecord($record);

        # $patron->{fingerprint} = $self->getPatronFingerPrint($patron);

        push(@parsedPatrons, $patron);
        print Dumper($patron);
    }

    my $parsedPatronsSize = @parsedPatrons;
    print "total Records: $parsedPatronsSize\n";

}

sub readFileToArray
{

    my $filePath = shift;

    my @data = ();

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";
    my $lineCount = 0;
    while (my $line = <$fileHandle>)
    {
        $line =~ s/\n//g;
        $line =~ s/\r//g;
        push(@data, $line) if ($line ne '');
        $lineCount++;
    }

    close $fileHandle;

    my $arraySize = @data;

    return \@data;

}
