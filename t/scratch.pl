#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

# my @specialChar = ("-", ".", "+", "*", "?", "^", "\$", "(", ")", "[", "]", "{", "}", "|");
my @specialChar = ("-", ".");

for my $pattern (@patterns)
{
    $pattern = lc $pattern;
    # next if ($pattern eq 'n/a' || $pattern !~ 'dd' || $pattern !~ 'mm'|| $pattern !~ 'yy');
    next if ($pattern eq 'n/a');

    print "$pattern,";
    $pattern =~ s/\-/\\-/g;
    $pattern =~ s/\./\\./g;
    $pattern =~ s/dd/\\d{2}/g;
    $pattern =~ s/mm/\\d{2}/g;
    $pattern =~ s/yyyy/\\d{4}/g;
    $pattern =~ s/yy/\\d{2}/g;
    print "$pattern\n";

}

sub dirtrav
{
    my $self = shift;
    my $f = shift;
    my $pwd = shift;
    my @files = @{$f};
    opendir(DIR, "$pwd") or die "Cannot open $pwd\n";
    my @thisdir = readdir(DIR);
    closedir(DIR);
    foreach my $file (@thisdir)
    {
        if (($file ne ".") and ($file ne ".."))
        {
            if (-d "$pwd/$file")
            {
                push(@files, "$pwd/$file");
                @files = @{dirtrav($self, \@files, "$pwd/$file")};
            }
            elsif (-f "$pwd/$file")
            {
                push(@files, "$pwd/$file");
            }
        }
    }
    return \@files;
}

my $path = "/mnt/dropbox/avalon/home/avalon/incoming";
my $self = {};
my @files = ();
@files = @{dirtrav($self, \@files, $path)};
# print "$_\n" for (@files);

# MACStaff\d{2}\d{2}\d{2}\.txt

my @patronFiles = grep(/ATSU_\d{2}\d{2}\d{4}\.txt/, @files);
print "$_\n" for (@patronFiles);