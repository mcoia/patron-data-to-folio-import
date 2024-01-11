#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use lib qw(../lib);
use MOBIUS::Loghandler;

our $log = Loghandler->new("test.log");
$log->truncFile("");

print "-------- Sandbox --------\n";

my $filePath = "/home/owner/repo/mobius/folio/patron-import/resources/mapping/patron-type/archway-patron-mapping-2.csv";

my @mappingData = @{openMappingSheet($filePath)};

print "=============== Test\n";

sub openMappingSheet
{
    my @data = ();

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";
    while (my $line = <$fileHandle>)
    {
        chomp ($line);

        if (!($line =~ /Sierra PTYPE/) && !($line =~ /^0/))
        {
            my @row = split(',', $line);
            # push(@data, \@row) if($row[]);
            push(@data, \@row);
        }
    }

    close $fileHandle;
    return \@data;
}


my @a = ();
for(0..100){

    my $data;
    $data->{count} = $_;
    $data->{time} = localtime;
    push(@a, $data);

}

print  $a[1]->{count} . "\n";