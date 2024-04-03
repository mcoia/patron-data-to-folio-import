#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use JSON;

use HTTP::Request ();
use HTTP::Response ();
use HTTP::Date ();

use LWP ();
use HTTP::Status ();
use LWP::Protocol ();

my $request = HTTP::Request->new('GET', "https://news.yahoo.com/cicadas-natures-weirdos-pee-stronger-135529485.html");
my $userAgent = LWP::UserAgent->new();
my $response = $userAgent->request($request);

print $response->{_content};

# print Dumper($response);

# sudo apt install liblwp-protocol-https-perl

# require HTTP::Request;
# $request = HTTP::Request->new(GET => 'http://www.example.com/');
# and usually used like this:
# $ua = LWP::UserAgent->new;
# $response = $ua->request($request);
