#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use HTTP::Request;

test_scrape();
sub test_scrape
{

    my $URL = "https://metacpan.org/pod/HTTP::Soup";

    my $request = HTTP::Request->new("GET", "$URL");

    # my $jar = HTTP::CookieJar::LWP->new();
    my $userAgent = LWP::UserAgent->new();
    # 'cookie_jar' => $jar
    # );

    my $response = $userAgent->request($request);

    my $html = $response->{_content};

    use HTML::Parser;

    my $p = HTML::Parser->new();
    my $obj = $p->parse($html);

    print Dumper($obj);

}
