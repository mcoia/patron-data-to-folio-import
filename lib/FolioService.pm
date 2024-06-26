package FolioService;
use strict;
use warnings FATAL => 'all';

use Getopt::Long;
use Cwd;
use File::Path;
use File::Copy;
use Data::Dumper;
use Try::Tiny;
use Net::Address::IP::Local;
use utf8;
use LWP;
use JSON;
use URI::Escape;
use Data::UUID;
use HTTP::CookieJar::LWP ();
use PatronImportReporter;
use Encode;

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

sub login
{
    # https://folio-org.atlassian.net/wiki/spaces/FOLIJET/pages/1396980/Refresh+Token+Rotation+RTR
    my $self = shift;
    my $tenant = shift;

    my $credentials = shift || $main::dao->getFolioCredentials($tenant);
    my $printResponse = shift || 0;

    my $header = [
        'x-okapi-tenant' => "$tenant",
        'content-type'   => 'application/json'
    ];

    return $self->_logLoginFailed($tenant) if (!defined($credentials->{username}) || !defined($credentials->{password}));

    my $userJSON = encode_json({ username => $credentials->{username}, password => $credentials->{password} });

    $self->{cookies} = HTTP::CookieJar::LWP->new();
    my $response = $self->HTTPRequest("POST", $main::conf->{loginURL}, $header, $userJSON);

    print Dumper($response) if ($printResponse && $main::conf->{print2Console});

    $main::log->add(Dumper($response)) if (!defined($response->{'_headers'}->{'set-cookie'}->[0]));

    # Don't forget to cpan install LWP::Protocol::https
    # Check our login for cookies, if we didn't get any we failed and need to exit
    return $self->_logLoginFailed($tenant) if (!defined($response->{'_headers'}->{'set-cookie'}->[0]));

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

sub importPatrons
{
    my $self = shift;

    my $institutions = $main::dao->getInstitutionsHashByEnabled();

    for my $institution (@{$institutions})
    {

        # We need the tenant for this institution
        my $tenant = $institution->{tenant};

        print "Importing Patrons for [$institution->{name}] using tenant:[$tenant]\n" if ($main::conf->{print2Console});
        $main::log->add("Importing Patrons for [$institution->{name}] using tenant:[$tenant]");
        $main::log->add("authenticating...");

        # Login to folio tenant
        my $loginStatus = $self->login($tenant);
        next if ($loginStatus == 0);

        print "authentication successful!\n" if ($main::conf->{print2Console});
        $main::log->add("authentication successful!");

        my @importResponse = ();
        my @importFailedUsers = ();

        # fix this. It needs to be a for loop.
        while ($main::dao->getPatronImportPendingSize($institution->{id}) > 0) # <== todo: I do NOT like this while loop. It has no 'REAL' break condition.
        {

            print "Getting patrons for $institution->{name}\n" if ($main::conf->{print2Console});
            $main::log->add("");
            $main::log->add("____________________________________________");
            $main::log->add("Getting patrons for $institution->{name}");

            # grab some patrons
            my $patrons = $main::dao->getPatronBatch2Import($institution->{id});
            my $disablePatrons = 1;

            my $totalRecords = scalar(@{$patrons});

            print "Total Records:[$totalRecords]\n" if ($main::conf->{print2Console});
            $main::log->add("Total Records:[$totalRecords]");

            my $json = "";
            for my $patron (@{$patrons})
            {$json .= $self->_buildPatronJSON($patron);}
            chop($json);
            chop($json);

            $json = $self->_buildFinalJSON($json, $totalRecords);
            $json = $self->_removeEmptyFields($json);

            # ship it!
            print "sending json to folio...\n" if ($main::conf->{print2Console});
            $main::log->add("sending json to folio...");
            $main::log->add("$json");
            my $response = $self->_importIntoFolioUserImport($tenant, $json);

            # Deal with the response
            my $responseContent = $response->{_content};

            print "================= RESPONSE =================\n" if ($main::conf->{print2Console});
            print "$responseContent\n" if ($main::conf->{print2Console});

            # Invalid token, we probably timed out. Folio can be slow sometimes.
            if ($responseContent =~ /Invalid token/)
            {
                print "TOKEN Expired! Refreshing token\n" if ($main::conf->{print2Console});
                $main::log->addLine("TOKEN Expired! Refreshing token");
                $self->login($tenant);
                $disablePatrons = 0;
            }

            if ($responseContent =~ /Illegal unquoted character/ || $responseContent =~ /malformed JSON string/)
            {
                print $json . "\n" if ($main::conf->{print2Console});
                $main::log->add($json);
            }

            $main::log->add("================= RESPONSE =================");
            $main::log->add("$responseContent");

            if ($responseContent =~ 'read timeout at')
            {
                print "\n============== FOLIO TIMEOUT ===============\n" if ($main::conf->{print2Console});
                print "Reloading patrons and trying again.\n\n" if ($main::conf->{print2Console});
                $main::log->add("Reloading patrons and trying again.");
                $disablePatrons = 0;
            }

            # We disable so we don't try and reload the same patron. A fingerprint change will flip this.
            $main::dao->disablePatrons($patrons) if ($disablePatrons);

            try
            {

                # We will bomb here if these patron records get goofy chars in them. \ <== talking to you backspace!
                # We're filtering out some of these chars in fileService->readFileToArray but are we catching them all?
                # Ahh.... folio strikes again! It's not my code but folio sending out garbage json. we have to wrap this
                # in a try/catch now.
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

            }
            catch
            {
                $main::log->addLine("FOLIO sent back bad JSON.");
                $main::log->addLine($json);
                $main::log->addLine($responseContent);
            };

        }


        # Build our report.
        print "[$institution->{name}] Building a report\n" if ($main::conf->{print2Console});
        $main::log->add("[$institution->{name}] Building a report");

        my $importResponseTotals = $self->_getImportUserImportResponseTotals(\@importResponse);

        PatronImportReporter->new($institution, $importResponseTotals, \@importFailedUsers)->buildReport()->sendEmail()
            if ($importResponseTotals->{total} > 0 || $importResponseTotals->{failed} > 0 || $importResponseTotals->{created} > 0 || $importResponseTotals->{updated} > 0);

    }

    # should I check for patrons again? recursion?
    # $self->importPatrons() if ($main::dao->getPatronImportPendingSize($institution->{id}) > 0);

    return $self;

}

sub _removeEmptyFields
{
    my $self = shift;
    my $json = shift;

    $json = encode('UTF-8', $json);

    my $perlJSON = "";

    try
    {
        $perlJSON = decode_json($json);
    }
    catch
    {
        $main::log->addLine("FAILED DECODE");
        $main::log->addLine($json);
        exit;
    };

    for my $user (@{$perlJSON->{users}})
    {

        # loop thru the $user hash and print out the key value pairs
        while (my ($k, $v) = each %$user)
        {
            delete($user->{$k}) if (!defined($v) || $v eq '');

            # clean up this null garbage
            my $addresses = $user->{personal}->{addresses};
            my @indexesToRemove = ();

            my $index = 0;
            for my $address (@{$addresses})
            {
                while (my ($ak, $av) = each %$address)
                {delete $address->{$ak} if (!defined($av) || $av eq 'null');}

                # if we're only 1 key in this hash it's the primaryAddress field and we need to remove it.
                delete($address->{primaryAddress}) if (scalar(keys %$address) == 1);

                # if $address only contains 1 element add the index to @indexesToRemove
                push(@indexesToRemove, $index) if (scalar(keys %$address) == 0);

                $index++;

            }

            # was getting something like... addresses: { addressLine1: { primary: true }}
            # which isn't going to work. I'm not sure how to remove an element from a looped array while inside the loop
            # so I grab the index and just remove it after the for loop.

            # remove the empty hashes from the array
            for my $indexToRemove (@indexesToRemove)
            {splice(@{$addresses}, $indexToRemove, 1);}

        }
    }

    $json = encode_json($perlJSON);

    return $json;

}

sub _buildPatronJSON
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
        $patron->{$k} = $self->_escapeIllegalChars($v) if (defined($v));

        # we can't concat undef
        $patron->{$k} = "" if (!defined($v));
    }

    # my $address = "";
    my $address = $self->_buildAddressJSON($patron->{address});

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

    # replace null with ""
    # $json =~ s/null/""/g;

    return $json;

}

sub _buildAddressJSON
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

sub _buildFinalJSON
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

sub _importIntoFolioUserImport
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

sub _logLoginFailed
{
    my $self = shift;
    my $tenant = shift;

    {

        print "\n\n=====================================================================================================\n" if ($main::conf->{print2Console});
        print "                                 !!! Log in failed !!!\n" if ($main::conf->{print2Console});
        print "                    Login failed for tenant: $tenant\n" if ($main::conf->{print2Console});
        print "                    $main::conf->{baseURL}$main::conf->{loginURL}\n" if ($main::conf->{print2Console});
        print "                    Do we have a login for $tenant?\n" if ($main::conf->{print2Console});
        print "=====================================================================================================\n\n" if ($main::conf->{print2Console});

        $main::log->add("\n\n=====================================================================================================\n");
        $main::log->add("                                 !!! Log in failed !!!\n");
        $main::log->add("                    Login failed for tenant: $tenant\n");
        $main::log->add("                    $main::conf->{baseURL}$main::conf->{loginURL}\n");
        $main::log->add("=====================================================================================================\n\n");

    }

    return 0;

}

sub _getImportUserImportResponseTotals
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

sub _escapeIllegalChars
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


##### API oriented methods below ############################

sub getFolioUserByUsername
{
    my $self = shift;

    my $username = shift;
    my $query = "(username==\"$username\")";
    my $endPoint = "/users?query=$query";

    # this works because we only allow 1 username. they have to be unique.
    my $tenant = $main::dao->getTenantByUsername($username);
    $self->login($tenant);
    my $response = $self->HTTPRequest("GET", $endPoint);

    my $json = decode_json($response->{_content});
    print encode_json($json->{users});

    exit;

}

sub getFolioUserByESID
{

    my $self = shift;
    my $esid = shift;

    my $query = "(externalSystemId==\"$esid\")";
    my $endPoint = "/users?query=$query";

    # this works because we only allow 1 username. they have to be unique.
    my $tenant = $main::dao->getTenantByESID($esid);
    $self->login($tenant);
    my $response = $self->HTTPRequest("GET", $endPoint);

    my $json = decode_json($response->{_content});
    print encode_json($json->{users});

    exit;

}

sub getFolioPatronGroupsByInstitutionId
{
    my $self = shift;
    my $institution_id = shift;

    my $tenant = $main::dao->getInstitutionHashById($institution_id)->{tenant};
    $self->login($tenant);

    my $endPoint = "/groups";
    my $response = $self->HTTPRequest("GET", $endPoint);
    my $json = decode_json($response->{_content});
    print encode_json($json->{usergroups});

    exit;

}

1;
