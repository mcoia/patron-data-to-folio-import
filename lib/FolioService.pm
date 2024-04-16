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

    my $institutionIDArray = $self->getFolioImportInstitutionIDs();

    # while ($main::dao->getPatronImportPendingSize() > 0)
    for my $institutionID (@{$institutionIDArray})
    {

        # grab some patrons
        my $patrons = $main::dao->getPatronBatch2Import($institutionID);

        print Dumper($patrons);
        exit;

        my $totalRecords = scalar(@{$patrons});

        # build the json template
        my $json = $self->buildPatronJSON($patrons);
        $json = $self->buildFinalJSON($json, $totalRecords);

        print $json . "\n";


        # ship it!
        # my $response = $self->importIntoFolio($json);

        #     {
        #         "message" : "Users were imported successfully.",
        #         "createdRecords" : 1,
        #         "updatedRecords" : 1,
        #         "failedRecords" : 1,
        #         "failedUsers" : [ {
        #         "username" : "jsmith_002",
        #         "externalSystemId" : "002-ATSU",
        #         "errorMessage" : "Failed to create new user with externalSystemId: 002-ATSU"
        #     } ],
        #     "totalRecords" : 3
        # }'

        # my $jsonResponse = decode_json($response->{_content});

        # for my $fail (@{$jsonResponse->{failedUsers}})
        # {
        #     print Dumper($fail);
        # }
        #
        # print Dumper($response);
        exit;

    }

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

    $self->{cookies} = HTTP::CookieJar::LWP->new();
    my $response = $self->HTTPRequest("POST", $main::conf->{loginURL}, $header, $user);

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

sub HTTPRequest
{
    my $self = shift;

    my $type = shift;
    my $url = shift;
    my $header = shift;
    my $payload = shift;

    my $request = HTTP::Request->new($type, "$main::conf->{baseURL}$url", $header, $payload);

    my $userAgent = LWP::UserAgent->new(
        'cookie_jar' => $self->{cookies}
    );

    my $response = $userAgent->request($request);

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

        #todo: I don't like this... fix it!
        my $template = <<json;
            {
              "username": "$patron->{username}",
              "externalSystemId": "$patron->{externalsystemid}",
              "barcode": "$patron->{barcode}",
              "active": true,
              "patronGroup": "$patron->{patrongroup}",
              "personal": {
                "lastName": "$patron->{lastname}",
                "firstName": "$patron->{firstname}",
                "middleName": "$patron->{middlename}",
                "preferredFirstName": "$patron->{preferredfirstname}",
                "phone": "$patron->{phone}",
                "mobilePhone": "$patron->{mobilephone}",
                "dateOfBirth": "$patron->{dateofbirth}",
                "addresses": $address,
                "preferredContactTypeId": "$patron->{preferredcontacttypeid}"
              },
              "enrollmentDate": "$patron->{enrollmentdate}",
              "expirationDate": "$patron->{expirationdate}"
            },;
json
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

sub getFolioImportInstitutionIDs
{
    my $self = shift;

    # todo: actually write something here.
    # query = "select ...."

    my @ids = (4 .. 6);

    return \@ids;

}

1;
