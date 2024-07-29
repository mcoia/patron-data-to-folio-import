#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use JSON;
use Try::Tiny;

my $data = "0020f-   fcb  --8-1-24";

# \d{1,2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}
my $date = "";

try
{
    $date = ($data =~ /(\d{1,2}-\d{1,2}-\d{2,4})$/gm)[0];
}
catch
{
    print "didn't work\n";
};

print $date . "\n";
print $data . "\n";
