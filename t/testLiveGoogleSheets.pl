#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

sub getGoogleSheetCSV
{
    # my $self = shift;
    my $sheetID = shift;
    my $gid = shift || '0';

    # https://docs.google.com/spreadsheets/u/1/d/18Svxcc7oqanAFVve8hwt2rDuy_-9DwUfIQq_eCx2yLg/export?format=csv&id=18Svxcc7oqanAFVve8hwt2rDuy_-9DwUfIQq_eCx2yLg&gid=1662551588

    # my $url = "https://docs.google.com/spreadsheets/d/$sheetID/export?format=csv&gid=$gid";

    my $url = "https://docs.google.com/spreadsheets/u/1/d/$sheetID/export?format=csv&id=$sheetID&gid=$gid" ;
    print "url: $url\n";

    my @wget = `wget -q -O /dev/stdout $url > /dev/null  2>&1`;
    chomp(@wget);

    return \@wget;

}

my $sheetID = "18Svxcc7oqanAFVve8hwt2rDuy_-9DwUfIQq_eCx2yLg";
my $gid = "84009416";
# my $gid = "1662551588";
my $id = "18Svxcc7oqanAFVve8hwt2rDuy_-9DwUfIQq_eCx2yLg";

my @wget = @{getGoogleSheetCSV($sheetID,$gid)};
chomp(@wget);

print "$_\n" for(@wget);

=pod

This is not working correctly. I can download the 1st sheet but not any other sheet. I'm scrapping this idea for now.
I think there's some javascript fuckery on googles side.
Works for 1 sheet.

=cut
