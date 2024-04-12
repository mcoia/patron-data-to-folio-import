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

    while ($main::dao->getPatronImportPendingSize() > 0)
    {

        # grab some patrons
        my $patrons = $main::dao->getPatronBatch2Import();

        my $totalRecords = scalar(@{$patrons});

        # build the json template
        my $json = $self->buildPatronJSON($patrons);

        $json = $self->buildFinalJSON($json, $totalRecords);

        $main::log->addLine($json);

        # ship it!
        my $response = $self->importIntoFolio($json);
        print Dumper($response);
        exit;

    }

    return $self;

}

sub login
{
    my $self = shift;
    my $tenant = shift;


    # store our tenant for future use.
    $self->{tenant} = $tenant;

    my $header = [
        'x-okapi-tenant' => "$tenant",
        'content-type'   => 'application/json'
    ];

    my $user = encode_json({ username => $self->{username}, password => $self->{password} });

    my $response = $self->HTTPRequest("POST", $main::conf->{loginURL}, $header, $user);


    # print Dumper($response);
    # mobius_atsu_patronload

    # Check our login for cookies, if we didn't get any we failed and need to exit
    if (!defined($response->{'_headers'}->{'set-cookie'}->[0]))
    {
        $main::log->addLine("Log in failed! Please set your username:password in the environment variables folio_username and folio_password");
        print "\n\n=====================================================================================================\n";
        print "                                 !!! Log in failed !!! \nPlease set your username:password with the environment variables folio_username and folio_password";
        print "\n=====================================================================================================\n\n";
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

    print Dumper($request);
    print "\n\n\n\n";
    print "\n\n\n\n";
    print "\n\n\n\n";
    print "\n\n\n\n";

    my $response = $userAgent->request($request);

    print Dumper($response);
    print "\n\n\n\n";
    print "\n\n\n\n";
    print "\n\n\n\n";
    print "\n\n\n\n";
    print "\n\n\n\n";
    print "\n\n\n\n";

    return $response;

}

sub buildPatronJSON
{
    my $self = shift;
    my $patrons = shift;

    my $json = "";
    for my $patron (@{$patrons})
    {

        # remove unwanted columns
        delete($patron->{id});
        delete($patron->{institution_id});
        delete($patron->{file_id});
        delete($patron->{job_id});
        delete($patron->{fingerprint});
        delete($patron->{ready});
        delete($patron->{error});
        delete($patron->{errormessage});

        my $addressIndex = 0;
        for ($patron->{address})
        {
            delete($patron->{address}->[$addressIndex]->{id});
            delete($patron->{address}->[$addressIndex]->{patron_id});
            $addressIndex++;
        }

        # # Use of uninitialized value in concatenation (.) or string at ...
        # # fix these pesky undef values.
        keys %$patron;
        while (my ($k, $v) = each %$patron)
        {$patron->{$k} = "" if (!defined($v));}

        # my $address = "";
        my $address = $self->buildAddressJSON($patron->{address});


        # '_content' => 'Cannot deserialize value of type `java.util.Date` from String "07-25-24":
        # not a valid representation (error: Failed to parse Date value \'07-25-24\': Cannot parse date "07-25-24":
        # not compatible with any of standard forms ("yyyy-MM-dd\'T\'HH:mm:ss.SSSX", "yyyy-MM-dd\'T\'HH:mm:ss.SSS", "EEE,
        # dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd"))

        my $template = "
            {
              \"username\": \"$patron->{username}\",
              \"externalSystemId\": \"$patron->{externalsystemid}\",
              \"barcode\": \"$patron->{barcode}\",
              \"active\": true,
              \"patronGroup\": \"$patron->{patrongroup}\",
              \"personal\": {
                \"lastName\": \"$patron->{lastname}\",
                \"firstName\": \"$patron->{firstname}\",
                \"middleName\": \"$patron->{middlename}\",
                \"preferredFirstName\": \"$patron->{preferredfirstname}\",
                \"phone\": \"$patron->{phone}\",
                \"mobilePhone\": \"$patron->{mobilephone}\",
                \"dateOfBirth\": \"$patron->{dateofbirth}\",
                \"addresses\": $address,
                \"preferredContactTypeId\": \"$patron->{preferredcontacttypeid}\"
              },
              \"enrollmentDate\": \"$patron->{enrollmentdate}\",
              \"expirationDate\": \"$patron->{expirationdate}\"
            },";

        $json .= $template;

    }

    # remove the last ,
    chop($json);

    return $json;

}

sub buildAddressJSON
{
    my $self = shift;
    my $addresses = shift;

    # {
    #     "countryId": "HU",
    #     "addressLine1": "Andrássy Street 1.",
    #     "addressLine2": "",
    #     "city": "Budapest",
    #     "region": "Pest",
    #     "postalCode": "1061",
    #     "addressTypeId": "Home",
    #     "primaryAddress": true
    # }

    my @addressArray = ();
    for my $address (@{$addresses})
    {

        keys %$address;
        while (my ($k, $v) = each %$address)
        {$address->{$k} = "" if (!defined($v));}

        my $jsonAddress = {
            "countryId"      => $address->{countryid},
            "addressLine1"   => $address->{addressline1},
            "addressLine2"   => $address->{addressline2},
            "city"           => $address->{city},
            "region"         => $address->{region},
            "postalCode"     => $address->{postalcode},
            "addressTypeId"  => $address->{addresstypeid},
            "primaryAddress" => $address->{primaryAddress} = 1 ? 'true' : 'false'
        };
        push(@addressArray, $jsonAddress);
    }

    return encode_json(\@addressArray);

}

sub buildFinalJSON
{
    my $self = shift;
    my $json = shift;
    my $totalRecords = shift;
    my $sourceType = shift || "";

    my $finalJSON = "
        {
          \"users\": [$json],
          \"totalRecords\": $totalRecords,
          \"deactivateMissingUsers\": $main::conf->{deactivateMissingUsers},
          \"updateOnlyPresentFields\": $main::conf->{updateOnlyPresentFields},
          \"sourceType\": \"$sourceType\"
        }";
    return $finalJSON;

}

sub importIntoFolio
{
    my $self = shift;
    my $tenant = shift;
    my $json = shift;

    my $url = "/user-import";

    my $header = [
        'x-okapi-tenant' => "$tenant",
        'Content-Type'   => 'application/json',
        'x-okapi-token'  => $self->{'tokens'}->{'AT'}
    ];

    my $response = $self->HTTPRequest("POST", $url, $header, $json);

    return $response;

}

1;
