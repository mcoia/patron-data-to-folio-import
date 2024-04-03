package FolioService;
use strict;
use warnings FATAL => 'all';

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
use HTTP::CookieJar::LWP ();

=pod

# getting https going is a pain so this apt install gets it all in 1 shot
# sudo apt install liblwp-protocol-https-perl


agent                   "libwww-perl/#.###"
conn_cache              undef
cookie_jar              undef
cookie_jar_class        HTTP::Cookies
default_headers         HTTP::Headers->new
from                    undef
local_address           undef
max_redirect            7
max_size                undef
no_proxy                []
parse_head              1
protocols_allowed       undef
protocols_forbidden     undef
proxy                   {}
requests_redirectable   ['GET', 'HEAD']
send_te                 1
show_progress           undef
ssl_opts                { verify_hostname => 1 }
timeout                 180

=cut



sub new
{
    my $class = shift;
    my $self = {
        'username' => shift,
        'password' => shift,
        'tenant'   => shift,
        'baseURL'  => shift,
        'cookies'  => 0,
    };
    bless $self, $class;
    return $self;
}

sub login
{
    my $self = shift;

    my $header = [
        'x-okapi-tenant' => "$self->{tenant}",
        'content-type'   => 'application/json'
    ];

    my $user = encode_json({ username => $self->{username}, password => $self->{password} });

    my $response = $self->HTTPRequest("POST", "/authn/login-with-expiry", $header, $user);

    # set our FART tokens. Folio-Access-Refresh-Tokens
    $self->{'tokens'}->{'AT'} = ($response->{'_headers'}->{'set-cookie'}->[0] =~ /=(.*?);\s/g)[0];
    $self->{'tokens'}->{'RT'} = ($response->{'_headers'}->{'set-cookie'}->[1] =~ /=(.*?);\s/g)[0];

    return $self;
}

=pod

The default expiration of an AT is 10 minutes. If client code needs to use this token after this 10 minute period is up,
client code should request a new AT by logging in again. Note that once the AT reaches the FOLIO system the AT is
converted into a non-expiring token. So a long-running operation that takes more than 10 minutes won't be subject to the
expiration of the original AT.

=cut
sub refreshTokens
{

}

sub HTTPRequest
{
    my $self = shift;

    my $type = shift;
    my $url = shift;
    my $header = shift;
    my $payload = shift;

    my $request = HTTP::Request->new($type, "$self->{baseURL}$url", $header, $payload);

    my $jar = HTTP::CookieJar::LWP->new();
    my $userAgent = LWP::UserAgent->new(
        'cookie_jar' => $jar
    );

    return $userAgent->request($request);

}

1;