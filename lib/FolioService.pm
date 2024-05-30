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
use PatronImportReporter;

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
    my $self = {};
    bless $self, $class;
    return $self;
}

sub importPatrons
{
    my $self = shift;

    my $institutions = $main::dao->getInstitutionsHashByEnabled();

    for my $institution (@{$institutions})
    {

        # We need the tenant for this institution
        my $tenant = $institution->{tenant};

        print "Importing Patrons for [$institution->{name}] using tenant:[$tenant]\n";
        $main::log->add("Importing Patrons for [$institution->{name}] using tenant:[$tenant]");
        $main::log->add("authenticating...");

        # Login to folio tenant
        my $loginStatus = $self->login($tenant);
        next if ($loginStatus == 0);

        print "authentication successful!\n";
        $main::log->add("authentication successful!");

        my @importResponse = ();
        my @importFailedUsers = ();

        # fix this. It needs to be a for loop.
        while ($main::dao->getPatronImportPendingSize($institution->{id}) > 0) # <== todo: I do NOT like this while loop. It has no 'REAL' break condition.
        {

            print "Getting patrons for $institution->{name}\n";
            $main::log->add("Getting patrons for $institution->{name}");

            # grab some patrons
            my $patrons = $main::dao->getPatronBatch2Import($institution->{id});

            my $totalRecords = scalar(@{$patrons});

            print "Total Records:[$totalRecords]\n";
            $main::log->add("Total Records:[$totalRecords]");

            my $json = "";
            for my $patron (@{$patrons})
            {$json .= $self->buildPatronJSON($patron);}
            chop($json);
            chop($json);

            $json = $self->buildFinalJSON($json, $totalRecords);

            print "sending json to folio...\n";
            $main::log->add("sending json to folio...");
            $main::log->add("$json");

            # ship it!
            my $response = $self->importIntoFolio($tenant, $json);

            # Deal with the response
            my $responseContent = $response->{_content};

            print "================= RESPONSE =================\n";
            print "$responseContent\n";

            if ($responseContent =~ /Illegal unquoted character/)
            {
                print $json . "\n";
            }

            $main::log->add("================= RESPONSE =================");
            $main::log->add("$responseContent");

            # We will bomb here if these patron records get goofy chars in them. \ <== talking to you backspace!
            # We're filtering out some of these chars in fileService->readFileToArray but are we catching them all?
            my $responseHash = decode_json($responseContent);
            my $importResponseHash = {
                'institution_id' => $institution->{id},
                'job_id'         => $main::jobID,
                'message'        => $responseHash->{message},
                'created'        => $responseHash->{createdRecords},
                'updated'        => $responseHash->{updatedRecords},
                'failed'         => $responseHash->{failedRecords},
                'total'          => $responseHash->{totalRecords},
            };
            $main::dao->_insertHashIntoTable("import_response", $importResponseHash);
            push(@importResponse, $importResponseHash);

            my $import_response_id = $main::dao->getLastImportResponseID();

            for my $failedUser (@{$responseHash->{failedUsers}})
            {

                my $importFailedUsersHash = {
                    'import_response_id' => $import_response_id,
                    'externalSystemId'   => $failedUser->{externalSystemId},
                    'username'           => $failedUser->{username},
                    'errorMessage'       => $failedUser->{errorMessage},
                };
                $main::dao->_insertHashIntoTable("import_failed_users", $importFailedUsersHash);

                # Contain this list size for email.
                my $importFailedUsersSize = scalar(@importFailedUsers);
                push(@importFailedUsers, $importFailedUsersHash) if ($main::conf->{maxFailedUsers} >= $importFailedUsersSize);

            }

            # Save the failed json object for inspection.
            $main::dao->_insertHashIntoTable("import_failed_users_json", {
                'import_response_id' => $import_response_id,
                'json'               => $json,
            }) if ($responseHash->{failedRecords} > 0);

            # We disable so we don't try and reload the same patron. The fingerprint change will flip this.
            $main::dao->disablePatrons($patrons);

        }

        # Build our report.
        print "[$institution->{name}] Building a report\n";
        $main::log->add("[$institution->{name}] Building a report");

        my $importResponseTotals = $self->getImportResponseTotals(\@importResponse);
        PatronImportReporter->new($institution, $importResponseTotals, \@importFailedUsers)->buildReport()->sendEmail();

    }
    return $self;

}

sub login
{
    my $self = shift;
    my $tenant = shift;

    my $credentials = shift || $main::dao->getFolioCredentials($tenant);


    my $header = [
        'x-okapi-tenant' => "$tenant",
        'content-type'   => 'application/json'
    ];

    return $self->logLoginFailed($tenant) if (!defined($credentials->{username}) || !defined($credentials->{password}));

    my $userJSON = encode_json({ username => $credentials->{username}, password => $credentials->{password} });

    $self->{cookies} = HTTP::CookieJar::LWP->new();
    my $response = $self->HTTPRequest("POST", $main::conf->{loginURL}, $header, $userJSON);

    $main::log->add(Dumper($response)) if (!defined($response->{'_headers'}->{'set-cookie'}->[0]));

    # Don't forget to cpan install LWP::Protocol::https
    # Check our login for cookies, if we didn't get any we failed and need to exit
    return $self->logLoginFailed($tenant) if (!defined($response->{'_headers'}->{'set-cookie'}->[0]));

    # set our FART tokens. Folio-Access-Refresh-Tokens
    $self->{'tokens'}->{'AT'} = ($response->{'_headers'}->{'set-cookie'}->[0] =~ /=(.*?);\s/g)[0];
    $self->{'tokens'}->{'RT'} = ($response->{'_headers'}->{'set-cookie'}->[1] =~ /=(.*?);\s/g)[0];

    return 1;
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
    {
        # This is to remove all illegal chars in the json string
        $patron->{$k} = $self->escapeIllegalChars($v) if (defined($v));

        # we can't concat undef
        $patron->{$k} = "" if (!defined($v));
    }

    # my $address = "";
    my $address = $self->buildAddressJSON($patron->{address});

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
                "email": "$patron->{email}",
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

sub logLoginFailed
{
    my $self = shift;
    my $tenant = shift;

    {

        print "\n\n=====================================================================================================\n";
        print "                                 !!! Log in failed !!!\n";
        print "                    Login failed for tenant: $tenant\n";
        print "                    $main::conf->{baseURL}$main::conf->{loginURL}\n";
        print "                    Do we have a login for $tenant?\n";
        print "=====================================================================================================\n\n";

        $main::log->add("\n\n=====================================================================================================\n");
        $main::log->add("                                 !!! Log in failed !!!\n");
        $main::log->add("                    Login failed for tenant: $tenant\n");
        $main::log->add("                    $main::conf->{baseURL}$main::conf->{loginURL}\n");
        $main::log->add("=====================================================================================================\n\n");

    }

    return 0;

}

sub getImportResponseTotals
{
    my $self = shift;
    my $importResponse = shift;

    my $created = 0;
    my $updated = 0;
    my $failed = 0;
    my $total = 0;

    for my $h (@{$importResponse})
    {
        $created += $h->{created} if (defined($h->{created}));
        $updated += $h->{updated} if (defined($h->{updated}));
        $failed += $h->{failed} if (defined($h->{failed}));
        $total += $h->{total} if (defined($h->{total}));
    }

    return {
        created => $created,
        updated => $updated,
        failed  => $failed,
        total   => $total
    };

}

sub escapeIllegalChars
{
    my $self = shift;
    my $string = shift;

    # We need to escape all characters from chr(0) -> chr(31) in our json
    for (0 .. 31)
    {
        my $char = chr($_);
        $string =~ s/$char/\\$char/g;
    }

    return $string;

}

1;
