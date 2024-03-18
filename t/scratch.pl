#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use File::Find;
use Data::Dumper;


# Searching for files...
# Missouri Western State University: /mnt/dropbox/kc-towers/home/kc-towers/incoming
# Looking for pattern: [mwsuugr\.txt]
# File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuugr.txt]
# Looking for pattern: [mwsugr\.txt]
# File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsugr.txt]
# Looking for pattern: [mwsufac\.txt]
# File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsufac.txt]
# Looking for pattern: [mwsuexp\.txt]
# File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuexp.txt]
# Looking for pattern: [mwsuadj\.txt]
# File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuadj.txt]
# Looking for pattern: [mwsuinst\.txt]
# File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuinst.txt]
# Looking for pattern: [mwsuwdraw\.txt]
# File Found: [Missouri Western State University]:[/mnt/dropbox/kc-towers/home/kc-towers/incoming/mwsuwdraw.txt]
# Total Patrons in mwsuugr.txt: [2927]
# Total Patrons in mwsugr.txt: [207]
# Total Patrons in mwsufac.txt: [817]
# Total Patrons in mwsuexp.txt: [205]
# Total Patrons in mwsuadj.txt: [181]
# Total Patrons in mwsuinst.txt: [66]
# Total Patrons in mwsuwdraw.txt: [153]
# Total Patrons: [4556]

my $dir = "/mnt/dropbox/kc-towers/home/kc-towers/incoming";

my @files = ();
find(sub {push(@files, $File::Find::name)}, $dir);

my @file = grep(/mwsuugr\.txt/, @files);
# my @file = grep {/.*mwsuugr\.txt.*/} @files;

# print Dumper(\@files);
# print "$_\n" for(@files);

print "@file\n";