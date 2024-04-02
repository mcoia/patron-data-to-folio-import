package FolioService;
# use strict;
# use warnings FATAL => 'all';

use Getopt::Long;
use Cwd;
use File::Path;
use File::Copy;
use Data::Dumper;
use Net::Address::IP::Local;
use utf8;
use LWP;
use JSON;
use URI::Escape;
use Data::UUID;

sub new
{
    my $class = shift;
    my $self = {
        'username' => shift,
        'password' => shift,
        'okapiURL' => shift,
    };
    bless $self, $class;
    return $self;
}

sub loginOKAPI
{
    my $self = shift;

    my $tenant = shift;
    my $header = [
        'X-Okapi-Tenant' => $tenant
    ];

    my $user = encode_json({
        username => $self->{username},
        password => $self->{password}
    });

    # my $answer = $self->HTTPRequest($header, encode_json($user), "POST", "/authn/login-with-expiry");
    my $answer = $self->HTTPRequest($header, $user, "POST", "/login");
    return $answer->header("x-okapi-token") if ($answer->is_success);
    return 0;
}

sub standardAuthHeader
{
    my $self = shift;

    my $authtoken = shift;
    my $tenant = shift;

    my $header = [
        'X-Okapi-Tenant' => $tenant,
        'X-Okapi-Token'  => $authtoken
    ];
    return $header;
}

sub HTTPRequest
{
    my $self = shift;

    my $header = shift;
    my $payload = shift;
    my $type = shift;
    my $url = shift;
    push(@{$header}, ('Content-Type' => 'application/json', 'Accept' => 'application/json, text/plain'));
    my $userAgent = LWP::UserAgent->new();
    my $request = HTTP::Request->new($type, "$self->{okapiURL}$url", $header, $payload);
    return $userAgent->request($request);
}


# sub sendConsortiumSetup
# {
#
#     my $authtoken = shift;
#     my $tenant = shift;
#     my $header = standardAuthHeader($authtoken, $tenant);
#
#     my $cardinalURL = "http://$local_ip/cardinal.json";
#     $cardinalURL = uri_escape($cardinalURL);
#     my $url = "/directory/api/addFriend?friendUrl=$cardinalURL";
#     my $answer = runHTTPReq($header,'', "GET", $url);
#     print Dumper($answer);
# }


1;