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

    my $institutions = $main::dao->getInstitutionsHashByEnabled();

    for my $institution (@{$institutions})
    {
        while ($main::dao->getPatronImportPendingSize($institution->{id}) > 0)
        {

            # grab some patrons
            my $patrons = $main::dao->getPatronBatch2Import($institution->{id});

            my $totalRecords = scalar(@{$patrons});

            my $json = "";
            for my $patron (@{$patrons})
            {$json .= $self->buildPatronJSON($patron);}
            chop($json);
            chop($json);

            $json = $self->buildFinalJSON($json, $totalRecords);

            # We need the tenant for this institution!
            my $tenant = $institution->{tenant};

            # ship it!
            my $response = $self->importIntoFolio($tenant, $json);
            print Dumper($response);

            # example json response
            # "message" : "Users were imported successfully.",
            # "createdRecords" : 3,
            # "updatedRecords" : 0,
            # "failedRecords" : 0,
            # "failedUsers" : [],
            # "totalRecords" : 3

            my $responseHash = decode_json($response->{_content});
            $main::dao->_insertHashIntoTable("import_response", {
                'institution_id' => $institution->{id},
                'job_id'         => $main::jobID,
                'message'        => $responseHash->{message},
                'created'        => $responseHash->{createdRecords},
                'updated'        => $responseHash->{updatedRecords},
                'failed'         => $responseHash->{failedRecords},
                'total'          => $responseHash->{totalRecords},
            });

            my $import_response_id = $main::dao->getLastImportResponseID();

            for my $failedUser (@{$responseHash->{failedUsers}})
            {

                # example failed user response
                # "username" : "V00261368JC",
                # "externalSystemId" : "V00261368",
                # "errorMessage" : "Patron group does not exist in the system: [JC StudentXXX]"

                $main::dao->_insertHashIntoTable("import_failed_users", {
                    'import_response_id' => $import_response_id,
                    'externalSystemId'   => $failedUser->{externalSystemId},
                    'username'           => $failedUser->{username},
                    'errorMessage'       => $failedUser->{errorMessage},
                });

            }

            # Save the failed json object for inspection.
            $main::dao->_insertHashIntoTable("import_failed_users_json", {
                'import_response_id' => $import_response_id,
                'json'               => $json,
            }) if ($responseHash->{failedRecords} > 0);

            $main::dao->disablePatrons($patrons);

        }
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
    my $patron = shift;

    my $json = "";

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
              "type": "patron",
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
            },
json
    $json .= $template;

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

    my $finalJSON = <<json;
        {
          "users": [$json],
          "totalRecords": $totalRecords,
          "deactivateMissingUsers": $main::conf->{deactivateMissingUsers},
          "updateOnlyPresentFields": $main::conf->{updateOnlyPresentFields},
          "sourceType": "$sourceType"
        }
json

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
