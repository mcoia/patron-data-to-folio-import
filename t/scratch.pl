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


my $response->{'_headers'}->{'set-cookie'}->[0] = 'folioRefreshToken=eyJlbmMiOiJBMjU2R0NNIiwiYWxnIjoiZGlyIn0..U5UWLuS82Yy00b9B.2Pfa4u8sgslLDBoC6zUwuygIJ1VN_EYf-mOLHEsqMWuTaU3RW5EYu4-E8iKFY_MT6xJEW3A_OiDlbdc_89xkDS3QviaktvyNqwgWslHxGZdp156HNwv3EHq1P5FZsTnHMRyzcmWyaW-q0pdpX_9D8HoCJlDTvCyeAEtRI76ltdhvk5Z6JPo34zE8msvr9udWsEgF_N2YXyJtynaBwf6ifW80CRDF-E0Bd3LXhaIfo_zBXop0-Vg3ATMAg96yHpylVk4wmqdFvpNUDNRmT17BDdMBcpmexDpGxHaC6TD1mZE.S2XTcjzuTFlIucZfWWVypw; Max-Age=3600; Expires=Wed, 03 Apr 2024 21:18:29 GMT; Path=/authn; Secure; HTTPOnly; SameSite=Lax';
$response->{'_headers'}->{'set-cookie'}->[1] = 'folioAccessToken=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJlY3NfYWRtaW4iLCJ1c2VyX2lkIjoiZGEzOWY1YTgtZGFjMC00ZTZlLTg3MzEtODY1YzEzM2FkMTg3IiwidHlwZSI6ImFjY2VzcyIsImV4cCI6MTcxMjE3OTEwOSwiaWF0IjoxNzEyMTc1NTA5LCJ0ZW5hbnQiOiJjczAwMDAwaW50In0.igzFwtcthhZ_p79LQF9pRck6BQzo9VKt6JLq0yTWh_s; Max-Age=3600; Expires=Wed, 03 Apr 2024 21:18:29 GMT; Path=/; Secure; HTTPOnly; SameSite=Lax';

# my $AT = ($response->{'_headers'}->{'set-cookie'}->[0] =~ /=([a-zA-Z0-9\.\-_])\s/g)[0];
my $AT = ($response->{'_headers'}->{'set-cookie'}->[0] =~ /=(.*?);\s/g)[0];
my $RT = ($response->{'_headers'}->{'set-cookie'}->[1] =~ /=(.*?);\s/g)[0];



print "$response->{'_headers'}->{'set-cookie'}->[0]\n\n\n";
print "AT: [$AT]\n";
# print "RT: [$RT]\n";

























# my $FART = {
#     'AT' => $response->{'_headers'}->{'set-cookie'}->[0],
#     'RT' => $response->{'_headers'}->{'set-cookie'}->[1],
# };

# 'folioRefreshToken=eyJlbmMiOiJBMjU2R0NNIiwiYWxnIjoiZGlyIn0..U5UWLuS82Yy00b9B.2Pfa4u8sgslLDBoC6zUwuygIJ1VN_EYf-mOLHEsqMWuTaU3RW5EYu4-E8iKFY_MT6xJEW3A_OiDlbdc_89xkDS3QviaktvyNqwgWslHxGZdp156HNwv3EHq1P5FZsTnHMRyzcmWyaW-q0pdpX_9D8HoCJlDTvCyeAEtRI76ltdhvk5Z6JPo34zE8msvr9udWsEgF_N2YXyJtynaBwf6ifW80CRDF-E0Bd3LXhaIfo_zBXop0-Vg3ATMAg96yHpylVk4wmqdFvpNUDNRmT17BDdMBcpmexDpGxHaC6TD1mZE.S2XTcjzuTFlIucZfWWVypw; Max-Age=3600; Expires=Wed, 03 Apr 2024 21:18:29 GMT; Path=/authn; Secure; HTTPOnly; SameSite=Lax',
# 'folioAccessToken=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJlY3NfYWRtaW4iLCJ1c2VyX2lkIjoiZGEzOWY1YTgtZGFjMC00ZTZlLTg3MzEtODY1YzEzM2FkMTg3IiwidHlwZSI6ImFjY2VzcyIsImV4cCI6MTcxMjE3OTEwOSwiaWF0IjoxNzEyMTc1NTA5LCJ0ZW5hbnQiOiJjczAwMDAwaW50In0.igzFwtcthhZ_p79LQF9pRck6BQzo9VKt6JLq0yTWh_s; Max-Age=3600; Expires=Wed, 03 Apr 2024 21:18:29 GMT; Path=/; Secure; HTTPOnly; SameSite=Lax'


# print Dumper($response);

# sudo apt install liblwp-protocol-https-perl

# require HTTP::Request;
# $request = HTTP::Request->new(GET => 'http://www.example.com/');
# and usually used like this:
# $ua = LWP::UserAgent->new;
# $response = $ua->request($request);
