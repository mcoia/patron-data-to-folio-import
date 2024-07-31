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
use URI::Escape;
use Data::UUID;
use HTTP::CookieJar::LWP ();
use PatronImportReporter;
use Encode;
use JSON;

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

        print "Importing Patrons for [$institution->{name}] using tenant:[$tenant]\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->add("Importing Patrons for [$institution->{name}] using tenant:[$tenant]");
        $main::log->add("authenticating...");

        # Login to folio tenant
        my $loginStatus = $self->login($tenant);
        next if ($loginStatus == 0);

        print "authentication successful!\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->add("authentication successful!");

        my @importResponse = ();
        my @importFailedUsers = ();

        while ($main::dao->getPatronImportPendingSize($institution->{id}) > 0)
        {

            print "Getting patrons for $institution->{name}\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->add("");
            $main::log->add("____________________________________________");
            $main::log->add("Getting patrons for $institution->{name}");

            # grab some patrons
            my $patrons = $main::dao->getPatronBatch2Import($institution->{id});
            my $disablePatrons = 1;

            my $totalRecords = scalar(@{$patrons});

            print "Total Records:[$totalRecords]\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->add("Total Records:[$totalRecords]");

            my $json = "";
            for my $patron (@{$patrons})
            {$json .= $self->_buildPatronJSON($patron);}
            chop($json);
            chop($json);

            # Remove the empty fields from the json
            $json = $self->_buildFinalJSON($json, $totalRecords);
            $json = $self->_removeIllegalChars($json);
            $json = decode_json($json);
            $json = remove_empty_fields($json);
            $json = encode_json($json);

            # ship it!
            print "sending json to folio...\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->add("sending json to folio...");
            my $response = $self->_importIntoFolioUserImport($tenant, $json);

            # Deal with the response
            my $responseContent = $response->{_content};

            print "================= RESPONSE =================\n" if ($main::conf->{print2Console} eq 'true');
            print "$responseContent\n" if ($main::conf->{print2Console} eq 'true');

            # Invalid token, we probably timed out. Folio can be slow sometimes.
            if ($responseContent =~ /Invalid token/)
            {
                print "TOKEN Expired! Refreshing token\n" if ($main::conf->{print2Console} eq 'true');
                $main::log->addLine("TOKEN Expired! Refreshing token");
                $self->login($tenant);
                $disablePatrons = 0;
            }

            if ($responseContent =~ /Illegal unquoted character/ || $responseContent =~ /malformed JSON string/)
            {
                print $json . "\n" if ($main::conf->{print2Console} eq 'true');
                $main::log->add($json);
            }

            $main::log->add("================= RESPONSE =================");
            $main::log->add("$responseContent");

            if ($responseContent =~ 'read timeout at')
            {
                print "\n============== FOLIO TIMEOUT ===============\n" if ($main::conf->{print2Console} eq 'true');
                print "Reloading patrons and trying again.\n\n" if ($main::conf->{print2Console} eq 'true');
                $main::log->add("Reloading patrons and trying again.");
                $disablePatrons = 0;
            }

            # We disable so we don't try and reload the same patron. A fingerprint change will flip this.
            print "Updating patron jobID's\n" if ($main::conf->{print2Console} eq 'true');
            $main::log->add("Updating patron jobID's\n");
            $main::dao->finalizePatron($patrons) if ($disablePatrons);

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
        print "[$institution->{name}] Building a report\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->add("[$institution->{name}] Building a report");

        my $importResponseTotals = $self->_getImportUserImportResponseTotals(\@importResponse);

        PatronImportReporter->new($institution, $importResponseTotals, \@importFailedUsers)->buildReport()->sendEmail()
            if ($importResponseTotals->{total} > 0 || $importResponseTotals->{failed} > 0 || $importResponseTotals->{created} > 0 || $importResponseTotals->{updated} > 0);

    }

    return $self;

}

# This doesn't seem to be working as expected.
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

sub remove_empty_fields
{
    my $hash = shift;

    foreach my $key (keys %$hash)
    {
        if (ref $hash->{$key} eq 'HASH')
        {
            remove_empty_fields($hash->{$key});
            delete $hash->{$key} if !%{$hash->{$key}};
        }
        elsif (ref $hash->{$key} eq 'ARRAY')
        {
            foreach my $item (@{$hash->{$key}})
            {
                remove_empty_fields($item) if ref $item eq 'HASH';
            }
            @{$hash->{$key}} = grep {ref $_ ne 'HASH' || %$_} @{$hash->{$key}};
            delete $hash->{$key} if !@{$hash->{$key}};
        }
        else
        {
            delete $hash->{$key} if !defined($hash->{$key}) || $hash->{$key} eq '';
        }
    }
    return $hash;
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
    # $json =~ s/^null$/""/g;

    return $json;

}

sub _buildPatronJSON_BROKE {

    my ($self, $patron) = @_;

    # Sanitize and handle undefined values
    for my $key (keys %$patron) {
        if (defined $patron->{$key}) {
            $patron->{$key} = $self->_escapeIllegalChars($patron->{$key});
        } else {
            $patron->{$key} = "";
        }
    }

    my $address = $self->_buildAddressJSON($patron->{address});

    my $json_data = {
        username => $patron->{username},
        externalSystemId => $patron->{externalsystemid},
        barcode => $patron->{barcode},
        active => 'true',
        patronGroup => $patron->{patrongroup},
        type => "patron",
        personal => {
            lastName => $patron->{lastname},
            firstName => $patron->{firstname},
            middleName => $patron->{middlename},
            preferredFirstName => $patron->{preferredfirstname},
            phone => $patron->{phone},
            mobilePhone => $patron->{mobilephone},
            dateOfBirth => $patron->{dateofbirth},
            addresses => $address,
            email => $patron->{email},
            preferredContactTypeId => $patron->{preferredcontacttypeid}
        },
        enrollmentDate => $patron->{enrollmentdate},
        expirationDate => $patron->{expirationdate}
    };

    return encode_json($json_data);

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

        print "\n\n=====================================================================================================\n" if ($main::conf->{print2Console} eq 'true');
        print "                                 !!! Log in failed !!!\n" if ($main::conf->{print2Console} eq 'true');
        print "                    Login failed for tenant: $tenant\n" if ($main::conf->{print2Console} eq 'true');
        print "                    $main::conf->{baseURL}$main::conf->{loginURL}\n" if ($main::conf->{print2Console} eq 'true');
        print "                    Do we have a login for $tenant?\n" if ($main::conf->{print2Console} eq 'true');
        print "=====================================================================================================\n\n" if ($main::conf->{print2Console} eq 'true');

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

sub _removeIllegalChars
{

    my $self = shift;
    my $string = shift;

    $string = decode('UTF-8', $string);
    $string =~ s/\x{fffd}//g;
    $string = encode('UTF-8', $string);

    return $string;
}

##### API oriented methods below ############################
sub getFolioUserJSONByUsername
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
    my $user = $json->{users};
    my $jsonUser = encode_json($user);

    return $jsonUser;

}

sub getFolioUserJSONByESID
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

    my $user = $json->{users};

    my $jsonUser = encode_json($user);

    return $jsonUser;

}

sub getFolioUserJSONByBarcodeAndInstitutionId
{
    my $self = shift;
    my $institution_id = shift;
    my $barcode = shift;

    my $query = "(barcode==\"$barcode\")";
    my $endPoint = "/users?query=$query";

    # this works because we only allow 1 username. they have to be unique.
    my $tenant = $main::dao->getTenantByInstitutionId($institution_id);
    $self->login($tenant);
    my $response = $self->HTTPRequest("GET", $endPoint);

    my $json = decode_json($response->{_content});
    my $user = $json->{users};
    my $jsonUser = encode_json($user);

    return $jsonUser;

}

sub getJSONByEndpoint
{

    # /groups being the endpoint, the query is the cql query.
    # example endpoint: "/groups?query=cql.allRecords=1%20sortby%20group&limit=2000"

    my $self = shift;
    my $institution_id = shift;
    my $endPoint = shift;

    my $tenant = $main::dao->getInstitutionHashById($institution_id)->{tenant};
    $self->login($tenant);

    my $response = $self->HTTPRequest("GET", $endPoint);

    return $response->{_content};

}

sub getFolioPatronGroupsByInstitutionId
{
    my $self = shift;
    my $institution_id = shift;

    my $tenant = $main::dao->getInstitutionHashById($institution_id)->{tenant};
    $self->login($tenant);

    my $endPoint = "/groups?query=cql.allRecords=1%20sortby%20group&limit=2000";
    my $response = $self->HTTPRequest("GET", $endPoint);

    my $json = decode_json($response->{_content});
    my $patronGroups = encode_json($json->{usergroups});

    return $patronGroups;

}

sub generateFailedPatronsCSVReports
{

    my $self = shift;
    my $institution_id = shift;
    my $job_id = shift;

=pod

    The plan...
    ------------------------
    Create a CSV of all the failed patrons for a specific job and institution.
    where we Do folio api calls checking the most typical failed reasons.

    -- Most common failed reasons.
    ESID != ESID
    Username != Username
    Barcode.empty != Barcode.found
        Begs the question. What if another user has the same barcode?
    Patron Group not found

    Do inactive users fail?
    ------------------------

    Get all the failed users per job per institution

    Patron information.
    Job information

=cut

    # for my $patron (@{$main::dao->getFailedUsersByInstitutionId($institution_id)})
    # used to help guide copilot. This is the same query in getFailedUsersByInstitutionId(id)
    my @patronReportArray = ();
    for my $patronRow (@{$main::dao->query("SELECT
                                       ir.job_id,
                                       ifu.errormessage,
                                       p.id,
                                       p.institution_id,
                                       p.externalsystemid,
                                       p.username,
                                       p.barcode,
                                       p.lastname,
                                       p.firstname,
                                       p.expirationdate,
                                       p.patrongroup,
                                       p.raw_data
                                FROM patron_import.import_failed_users ifu
                                         join patron_import.import_response ir on ifu.import_response_id = ir.id
                                         join patron_import.patron p on ifu.username = p.username and p.externalsystemid = ifu.externalsystemid
                                where ir.institution_id = $institution_id and ir.job_id = $job_id
                                order by ir.job_id desc, ifu.id asc;")})
    {

        my $patron = {
            job_id           => $patronRow->[0],
            errormessage     => $patronRow->[1],
            id               => $patronRow->[2],
            institution_id   => $patronRow->[3],
            externalsystemid => $patronRow->[4],
            username         => $patronRow->[5],
            barcode          => $patronRow->[6],
            lastname         => $patronRow->[7],
            firstname        => $patronRow->[8],
            expirationdate   => $patronRow->[9],
            patrongroup      => $patronRow->[10],
            raw_data         => $self->sanitizeForCSV($patronRow->[11]),
        };

        $patron = $self->_getFailedReason($patron);

        print "=" x 100 . "\n";
        print Dumper($patron->{failMessage});

        push(@patronReportArray, $patron);

    }

    $self->generateFailedPatronsCSVReport(\@patronReportArray);
    @patronReportArray = ();

}

sub generateFailedPatronsCSVReport
{
    my $self = shift;
    my $patrons = shift;

    # CSV header
    my $csv = join(',',
        'MOBIUS fail message',
        'patron file externalsystemid',
        'folio externalsystemid',
        'patron file username',
        'folio username',
        'patron barcode',
        'folio barcode',
        'folio error message',
        'job id',
        'patron id',
        'lastname',
        'firstname',
        'patrongroup'
    ) . "\n";

    # Process each patron
    for my $patron (@{$patrons})
    {
        my $failedMessages = join('', map {"[$_]"} @{$patron->{failMessage}});

        # List of required keys in $patron hash
        my @required_keys = (
            'job_id', 'errormessage', 'id', 'institution_id', 'externalsystemid',
            'folioUserByUsername', 'username', 'folioUserByESID', 'barcode',
            'lastname', 'firstname', 'expirationdate', 'patrongroup'
        );

        # Ensure all required keys exist and are initialized
        for my $key (@required_keys)
        {
            $patron->{$key} //= '';
        }

        # Handle nested keys separately
        $patron->{folioUserByUsername} //= {};
        $patron->{folioUserByESID} //= {};

        # Ensure nested keys are initialized
        $patron->{folioUserByUsername}->{externalSystemId} //= '';
        $patron->{folioUserByESID}->{username} //= '';
        $patron->{folioUserByESID}->{barcode} //= '';

        # Concatenate the CSV string
        $csv .= join(',',
            $failedMessages,
            $patron->{externalsystemid},
            $patron->{folioUserByUsername}->{externalSystemId},
            $patron->{username},
            $patron->{folioUserByESID}->{username},
            $patron->{barcode},
            $patron->{folioUserByESID}->{barcode},
            $patron->{errormessage},
            $patron->{job_id},
            $patron->{id},
            $patron->{lastname},
            $patron->{firstname},
            $patron->{patrongroup}
        ) . "\n";
    }

    # Generate filename
    my $filename = $self->getFailedPatronsCSVFilename($patrons->[0]);
    print "Writing to file: $filename\n";

    # Write to file
    open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
    print $fh $csv;
    close $fh;

}

sub getFailedPatronsCSVFilename
{
    my $self = shift;
    my $patron = shift;

    my $institution = $main::dao->getInstitutionHashById($patron->{institution_id});
    my $jobID = $patron->{job_id};

    my $time = localtime();
    my $epoch = time();
    $time =~ s/\d\d:\d\d:\d\d\s//g;
    $time =~ s/\s/_/g;

    # todo: this is a filepath and needs to have the directory added to it.
    my $filename = $institution->{name} . "_job" . $jobID . "_" . $time . ".csv";

    return $filename;

}

sub _getFailedReason
{

    # This function is like a frat party the next day. It's a mess.

    my $self = shift;
    my $patron = shift;

    # Initialize failMessage as an array reference
    $patron->{failMessage} = [];

    my $folioUserByESIDJSON = $self->getFolioUserJSONByESID($patron->{externalsystemid});
    my $folioUserByUsernameJSON = $self->getFolioUserJSONByUsername($patron->{username});
    my $folioUserByBarcodeJSON = $self->getFolioUserJSONByBarcodeAndInstitutionId($patron->{institution_id}, $patron->{barcode});

    my $folioUserByESID = decode_json($folioUserByESIDJSON)->[0];
    my $folioUserByUsername = decode_json($folioUserByUsernameJSON)->[0];
    my $folioUserByBarcode = decode_json($folioUserByBarcodeJSON)->[0];

    # user has esid and they match, but the username doesn't.
    if (defined($folioUserByESID))
    {
        if (defined($folioUserByESID->{username}))
        {

            push @{$patron->{failMessage}}, "The existing folio patron username does not match the one supplied in your patron file"
                if ($patron->{username} ne $folioUserByESID->{username});

        }
        else
        {
            push @{$patron->{failMessage}}, "This folio user does not have a username";
        }
    }

    # usernames match, but esid doesn't
    if (defined($folioUserByUsername))
    {
        if (defined($folioUserByUsername->{externalSystemId}))
        {
            push @{$patron->{failMessage}}, "The folio ESID does not match the one supplied in your patron file"
                if ($patron->{externalsystemid} ne $folioUserByUsername->{externalSystemId});
        }
        else
        {
            push @{$patron->{failMessage}}, "This folio user does not have an externalSystemId";
        }
    }

    # Barcodes
    # At this point we have a match on both username and esid
    # let's check the barcode for when folio has a barcode but we don't supply one.
    if (defined($folioUserByUsername))
    {
        if (defined($folioUserByUsername->{barcode}))
        {

            # push @{$patron->{failMessage}}, "The existing folio patron has a barcode while none was supplied in your patron file"
            #     if ($folioUserByUsername->{barcode} ne '' && !defined($patron->{barcode}));
            #
            # push @{$patron->{failMessage}}, "The existing folio patron has a barcode while none was supplied in your patron file"
            #     if ($folioUserByUsername->{barcode} ne '' && $patron->{barcode} eq '');

            # I'm not sure this matters does it? Can we update barcodes?
            push @{$patron->{failMessage}}, "Barcode does not match"
                if ($folioUserByUsername->{barcode} ne $patron->{barcode} && $patron->{barcode} ne '' && defined($patron->{barcode}));

        }
    }

    # Barcode
    if (defined($folioUserByBarcode))
    {

        if (!$folioUserByBarcode->{active})
        {
            push @{$patron->{failMessage}}, "The folio patron is not active.";
        }

        if ($patron->{barcode} ne $folioUserByBarcode->{barcode} &&
            $folioUserByBarcode->{username} ne $patron->{username})
        {
            push @{$patron->{failMessage}}, "This barcode is taken by another patron.";
        }

        if ($patron->{barcode} ne $folioUserByBarcode->{barcode} &&
            $patron->{externalsystemid} ne $folioUserByBarcode->{externalSystemId})
        {
            push @{$patron->{failMessage}}, "This barcode is taken by another patron.";
        }
    }

    # Check our patron groups
    my $folioPatronGroupJSONArray = $self->getFolioPatronGroupsByInstitutionId($patron->{institution_id});
    my $folioPatronGroupArray = decode_json($folioPatronGroupJSONArray);
    my $foundPatronGroup = 0;
    for (@{$folioPatronGroupArray})
    {
        $foundPatronGroup = 1 if ($_->{group} eq $patron->{patrongroup});
    }
    push @{$patron->{failMessage}}, "Patron Group not found in folio" if ($foundPatronGroup == 0);

    # Not sure if this is how folio works?
    push @{$patron->{failMessage}}, "Patron Not Active" if ($folioUserByESIDJSON =~ /"active":false/);

    push @{$patron->{failMessage}}, "Unknown" if (!@{$patron->{failMessage}});

    # We add these fields to the CSV report.
    $patron->{folioUserByESID} = {
        username => "Folio Username Not Found by ESID $patron->{externalsystemid}",
        barcode  => "Barcode Not Found by ESID $patron->{externalsystemid}",
    };

    $patron->{folioUserByUsername} = {
        externalSystemId => "External System ID Not Found in Folio by Username $patron->{username}",
        barcode          => "Barcode Not Found in Folio by Username $patron->{username}",
    };

    $patron->{folioUserByUsername} = $folioUserByUsername if (defined($folioUserByUsername));
    $patron->{folioUserByESID} = $folioUserByESID if (defined($folioUserByESID));

    return $patron;
}

sub sanitizeForCSV
{
    my $self = shift;
    my $string = shift;

    $string =~ s/\n/ /g;
    $string =~ s/\r/ /g;
    $string =~ s/\t/ /g;
    $string =~ s/"/""/g;

    # remove comma
    $string =~ s/,/<replace-with-comma-here>/g;

    return $string;

}

1;
