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
    my $self = shift;
    bless $self, $class;
    return $self;
}

sub importPatrons
{
    my $self = shift;

    print "importing patrons into folio";
    while ($main::dao->getPatronImportPendingSize() > 0)
    {

        # grab some patrons
        my $patrons = $main::dao->getPatrons2Import();

        # build the json template
        my @patronJson = ();
        push(@patronJson, $self->buildPatronTemplate($_)) for (@{$patrons});

        for (@patronJson)
        {print "$_\n";}
        exit;

        # ship it!
        # my $response = $self->importIntoFolio(\@patronJson);

    }

    return $self;

}

sub login
{
    my $self = shift;

    my $header = [
        'x-okapi-tenant' => "$main::conf->{tenant}",
        'content-type'   => 'application/json'
    ];

    my $user = encode_json({ username => $self->{username}, password => $self->{password} });

    my $response = $self->HTTPRequest("POST", $main::conf->{loginURL}, $header, $user);

    # Check our login for cookies, if we didn't get any we failed and need to exit
    if (!defined($response->{'_headers'}->{'set-cookie'}->[0]))
    {
        $main::log->addLine("Log in failed! Please set your username:password in the environment variables folio_username and folio_password");
        print "Log in failed! Please set your username:password in the environment variables folio_username and folio_password\n";
        exit;
    }

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

found this in the folio docs
The default expiration of an AT is 10 minutes. If client code needs to use this token after this 10 minute period is up,
 client code should request a new AT by logging in again. Note that once the AT reaches the FOLIO system the AT is converted
 into a non-expiring token. So a long-running operation that takes more than 10 minutes won't be subject to the expiration of the original AT.

=cut

sub HTTPRequest
{
    my $self = shift;

    my $type = shift;
    my $url = shift;
    my $header = shift;
    my $payload = shift;

    my $request = HTTP::Request->new($type, "$main::conf->{baseURL}$url", $header, $payload);

    my $jar = HTTP::CookieJar::LWP->new();
    my $userAgent = LWP::UserAgent->new(
        'cookie_jar' => $jar
    );

    return $userAgent->request($request);

}

sub buildPatronTemplate
{
    my $self = shift;
    my $patron = shift;

    my $debug = 1;
    my $template = "
                        {
                          'username': '$patron->{username}',
                          'externalSystemId': '$patron->{ex}',
                          'barcode': '$patron->{barcode}',
                          'active': true,
                          'patronGroup': '$patron->{patrongroup }',
                          'personal': {
                            'lastName': '$patron->{lastname}',
                            'firstName': '$patron->{firstname}',
                            'middleName': '$patron->{middlename}',
                            'preferredFirstName': '$patron->{preferredname}',
                            'phone': '$patron->{phone}',
                            'mobilePhone': '$patron->{mobilephone}',
                            'dateOfBirth': '$patron->{dateofbirth}',
                            'addresses': [
                              {
                                'countryId': 'HU',
                                'addressLine1': 'Andrássy Street 1.',
                                'addressLine2': '',
                                'city': 'Budapest',
                                'region': 'Pest',
                                'postalCode': '1061',
                                'addressTypeId': 'Home',
                                'primaryAddress': true
                              }
                            ],
                            'preferredContactTypeId': 'mail'
                          },
                          'enrollmentDate': '$patron->{enrollmentdate}',
                          'expirationDate': '$patron->{expirationdate}',
                        },";

    return $template;

}

1;