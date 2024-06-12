#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

# my $e = "read timeout at /usr/local/share/perl/5.38.2/Net/HTTP/Methods.pm line 274.";
my $e = "ead timeout at /usr/local/share/perl/5.38.2/Net/HTTP/Methods.pm line 274.";

if ($e !~ /read timeout at/)
{
    print "timeout!\n";
}
