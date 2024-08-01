#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use lib qw(../lib);
use Data::Dumper;

use MOBIUS::Utils;
use MOBIUS::Loghandler;

use DAO;
use FileService;
use FolioService;
use Parser;
use Parsers::GenericParser;
use JSON;
use Test::More;
use ParallelExecutor;

our ($conf, $log);

initConf();
initLog();

our $dao = DAO->new()->_cacheTableColumns();
our $files = FileService->new();
our $parser = Parser->new();

our $folio = FolioService->new({
    'username' => $ENV{folio_username},
    'password' => $ENV{folio_password},
    'cookies'  => 0,
});

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "../patron-import.conf";

    $conf = eval {$utils->readConfFile($configFile);};

    if ($conf eq 'false')
    {
        print "trying other location... we must be debugging\n";
        $configFile = "./patron-import.conf";
        $conf = eval {$utils->readConfFile($configFile);};
    }

}

sub initLog
{
    $log = Loghandler->new("test.log");
    $log->truncFile("");
}

# test_1RecordLoad();
sub test_1RecordLoad
{

    my $tenant = "cs00000001_0024";

    my $password = $ENV{folio_password};

    # my $response = $folio->login($tenant, { username => 'mobius_api_kgbqs', password => $password });
    my $response = $folio->login($tenant, { username => 'mobius_api_irzsm', password => $password });

    my $json = <<"JSON";
    {
        "users": [
            {
                "username": "4268755EWL",
                "externalSystemId": "4268755",
                "barcode": "",
                "active": true,
                "patronGroup": "EWL-Webster Students International",
                "type": "patron",
                "personal": {
                    "lastName": "Zhou",
                    "firstName": "Zhenyu",
                    "middleName": "Zhenyu",
                    "preferredFirstName": "",
                    "phone": "",
                    "mobilePhone": "86 130 6785 1536",
                    "dateOfBirth": "",
                    "preferredContactTypeId": "email"
                },
                "expirationDate": "2025-01-10"
            }],
        "totalRecords": 1,
        "deactivateMissingUsers": false,
        "updateOnlyPresentFields": true,
        "sourceType": ""
    }

JSON


    $response = $folio->_importIntoFolioUserImport($tenant, $json);

    print $response->{_content} . "\n";

}

# test_otherEndPoints();
sub test_otherEndPoints
{

    # example: http://localhost:<port>/configurations/entries?query=scope.institution_id=aaa%20sortBy%20enabled

    # /consortia
    # /consortia/<consortia-uuid>/tenants
    my $tenant = "cs00000001_0053";

    # $folio->login($main::conf->{primaryTenant});
    $folio->login($tenant);


    # (username=="ab*" or personal.firstName=="ab*" or personal.lastName=="ab*") and active=="true" sortby personal.lastName personal.firstName barcode
    # active=true sortBy username

    my $endpoint = "users?query=username=mobius*";
    # my $endpoint = "accounts?query=username=mobius*";

    my $response = $folio->HTTPRequest("GET", "/" . $endpoint);

    my $json = $response->{_content};

    # print Dumper($response);
    # print "\n" for(0..10);
    print $response->{_content} . "\n";

}

# test_tenantLogins();
sub test_tenantLogins
{

    my $query = "SELECT i.tenant, i.name, l.username, l.password FROM patron_import.login l
                    join patron_import.institution i on i.id=l.institution_id;";

    my $results = $dao->query($query);
    for my $row (@{$results})
    {
        my $status = $folio->login($row->[0]);
        print "success: [$row->[1] - $row->[0]\n" if ($status == 1);
    }

}

# test_singleTenantLogin();
sub test_singleTenantLogin
{

    my $tenant = "cs00000001_0060";
    my $status = $folio->login($tenant);

    print "success: [$tenant]\n" if ($status == 1);

}

# test_getFolioCredentials();
sub test_getFolioCredentials
{

    my $tenant = "cs00000001_0060";
    my $credentials = $main::dao->getFolioCredentials($tenant);

    print Dumper($credentials);

}

# test_email();
sub test_email
{

    my $template = <<"HTML";
<h1>Test Email</h1>
<p>this is a p tag</p>
HTML

    print "\n\nTesting email\n";
    my @emailAddresses = qw(angelwilliamscott@gmail.com);
    print "email addresses: [@emailAddresses]\n";

    my $email = MOBIUS::Email->new("scottangel\@mobiusconsortium.org", \@emailAddresses, 0, 0);
    $email->sendHTML("test-email", "MOBIUS", $template);

}

# test_buildReport(); # and send()
sub test_buildReport
{

    my @importResponse = ();
    for (0 .. 10)
    {
        push(@importResponse, {
            'job_id'  => 1,
            'message' => "this is a test message",
            'created' => 10,
            'updated' => 5,
            'failed'  => 3,
            'total'   => 18
        });
    }

    my $response = $folio->_getImportUserImportResponseTotals(\@importResponse);

    # PatronImportReporter->new($institution, $importResponseTotals, \@importFailedUsers)->buildReport()->sendEmail();
    my $institution = {
        name         => 'MOBIUS TEST',
        emailsuccess => 'angelwilliamscott@gmail.com',
    };

    my @importFailedUsers = ();

    for (0 .. 10)
    {

        push(@importFailedUsers, {
            'externalSystemId' => "some-external-id-here",
            'username'         => "username-goes-here",
            'errorMessage'     => "some-error-message-goes-here",
        });

    }

    my $report = PatronImportReporter->new($institution, $response, \@importFailedUsers)->buildReport()->sendEmail();

}

# test_getImportResponseTotals();
sub test_getImportResponseTotals
{

    # 'institution_id' => $institution->{id},
    #     'job_id'         => $main::jobID,
    #     'message'        => $responseHash->{message},
    #     'created'        => $responseHash->{createdRecords},
    #     'updated'        => $responseHash->{updatedRecords},
    #     'failed'         => $responseHash->{failedRecords},
    #     'total'          => $responseHash->{totalRecords},


    my @importResponse = ();
    for (0 .. 10)
    {
        push(@importResponse, {
            'job_id'  => 1,
            'message' => "this is a test message",
            'created' => 10,
            'updated' => 5,
            'failed'  => 3,
            'total'   => 18
        });
    }

    print Dumper($folio->_getImportUserImportResponseTotals(\@importResponse));

}

# while ($main::dao->getPatronImportPendingSize($institution->{id}) > 0)
sub test_getPatronImportPendingSize
{
    # $self->query("select count(p.id) from patron_import.patron p where p.institution_id=$institution_id and p.ready and not p.error;")->[0]->[0];
}

# test_escapeIllegalChars();
sub test_escapeIllegalChars
{

    my $illegals = "";
    for my $illegalChar (0 .. 31)
    {$illegals .= chr($illegalChar);}

    my $string = "this is some illegal characters.
we have some return carriages and some new lines.
 [$illegals]
";

    print "$string";
    print "\n\n";

    $string = $folio->_escapeIllegalChars($string);

    print "$string";
    print "\n\n";

}

# test_getPatronByUsername();
sub test_getPatronByUsername
{

    my $patron = $dao->getPatronByUsername("351234WW");
    print Dumper($patron);

}

# test_folio_api();
sub test_folio_api
{

    # brooks user account
    # my $endPoint = "/users/2e6628b9-3788-4473-8a6c-8cafc3defc64";
    # my $endPoint = "/users/6bd7eb43-d2f7-4ef1-9283-40baa45c7f95";

    # Jefferson College	cs00000001_0061


    # my $endPoint = "/groups";
    # my $endPoint = "/groups/b8b71b6f-e165-42f5-a8c8-03f14ad1ac05";

    # my $query = "(username==\"4268755EWL\")";
    # my $query = "(externalSystemId==\"856238\")";
    my $query = "(barcode==\"uV00082663JC\")";
    my $endPoint = "/users?query=$query";

    # my $endPoint = "/departments";

    my $tenant = "cs00000001_0061";

    $folio->login($tenant);
    my $response = $folio->HTTPRequest("GET", $endPoint);
    print Dumper($response);

    # usergroups
    # my $jsonResponse = $response->{_content};
    # my $json = decode_json($jsonResponse);
    # print "group: [$_->{group}] : $_->{desc}\n" for (@{$json->{usergroups}});

}

# test_folio_api2();
sub test_folio_api2
{

    # my $query = "(externalSystemId===\"\")";
    # my $query = "cql.allRecords=1 NOT externalSystemId=\"\" type=patron &limit=2";
    my $query = "cql.allRecords=1 NOT externalSystemId=\"\" AND type=patron &limit=2000";
    my $endPoint = "/users?query=$query";

    my $tenant = "cs00000001_0042";

    $folio->login($tenant);
    my $response = $folio->HTTPRequest("GET", $endPoint);
    # print Dumper($response->{_content});

    # save $response->{_content} to a file called ./tmp.json
    open(my $fh, '>', './tmp.json');
    print $fh $response->{_content};
    close $fh;

}

# test_getFolioPatronGroupsByInstitutionId();
sub test_getFolioPatronGroupsByInstitutionId
{
    print $folio->getFolioPatronGroupsByInstitutionId(5);
}

# test_lookingforfiles();
sub test_lookingforfiles
{

    my @files = (

        "/mnt/dropbox/archway/home/archway/incoming/eccpat.txt",
        "/mnt/dropbox/archway/home/archway/incoming/jcpat.txt",
        "/mnt/dropbox/archway/home/archway/incoming/SCCstaff",
        "/mnt/dropbox/archway/home/archway/incoming/SCCstudent",
        "/mnt/dropbox/archway/home/archway/incoming/SLCCStaff",
        "/mnt/dropbox/archway/home/archway/incoming/SLCCStudent",
        "/mnt/dropbox/archway/home/archway/incoming/stlcoppat.txt",
        "/mnt/dropbox/archway/home/archway/incoming/ub_patron.txt",
        "/mnt/dropbox/arthur/home/arthur/incoming/WWUpatronsNEW.txt",
        "/mnt/dropbox/avalon/home/avalon/incoming/patron-import/ATSU/import/ATSU_06252024.txt",
        "/mnt/dropbox/avalon/home/avalon/incoming/patron-import/ATSU/import/ATSU_06282024.txt",
        "/mnt/dropbox/avalon/home/avalon/incoming/tpbstupat",
        "/mnt/dropbox/bridges/home/bridges/incoming/cslpatrons.txt",
        "/mnt/dropbox/bridges/home/bridges/incoming/covfac.txt",
        "/mnt/dropbox/bridges/home/bridges/incoming/covstu.txt",
        "/mnt/dropbox/bridges/home/bridges/incoming/FCfacPAT.DAT",
        "/mnt/dropbox/bridges/home/bridges/incoming/FCstuPAT.DAT",
        "/mnt/dropbox/bridges/home/bridges/incoming/LUFACPAT.txt",
        "/mnt/dropbox/bridges/home/bridges/incoming/LUSTUPAT.txt",
        "/mnt/dropbox/bridges/home/bridges/incoming/loganstu.txt",
        "/mnt/dropbox/bridges/home/bridges/incoming/EWLPat.txt",
        "/mnt/dropbox/kc-towers/home/kc-towers/incoming/KCKCC_LIB_EMP.txt",
        "/mnt/dropbox/kc-towers/home/kc-towers/incoming/KCKCC_LIB_STU.txt",
        "/mnt/dropbox/kc-towers/home/kc-towers/incoming/nwmsuempl.txt",
        "/mnt/dropbox/kc-towers/home/kc-towers/incoming/nwmsustu.txt",
        "/mnt/dropbox/swan/home/swan/incoming/ccstupat.txt",
        "/mnt/dropbox/swan/home/swan/incoming/EUPatronCamsExport_Jun_17_24.txt",
        "/mnt/dropbox/swan/home/swan/incoming/MSSCALL",
        "/mnt/dropbox/swan/home/swan/incoming/MobiusUpload2024FA_MAIN.txt",
        "/mnt/dropbox/swan/home/swan/incoming/MobiusUpload2024FA_INET.txt",
        "/mnt/dropbox/swan/home/swan/incoming/otcpat.txt",
        "/mnt/dropbox/swan/home/swan/incoming/SBUPATRONS",
        "/mnt/dropbox/swbts/home/swbts/incoming/patronLoad.txt"

    );

    for my $file (@files)
    {

        # check if $file exists
        if (-e $file)
        {
            print "file exists: [$file]\n";
        }
        else
        {
            print "file does not exist: [$file]\n";
        }


    }

}

# test_importPatrons();
sub test_importPatrons
{

    my $institution = {
        id =>

    };

    print Dumper(
        $main::dao->getPatronImportPendingSize($institution->{id})
    );

}

# test_PatronJSONRemoveEmptyFieldsFromPatronHash();
sub test_PatronJSONRemoveEmptyFieldsFromPatronHash
{

    # for my $institution_id (3, 4, 5, 7, 8, 9, 14, 15, 16, 17, 18, 21, 23, 24, 25, 26, 29, 30, 31, 32, 33, 43)
    for my $institution_id (3)
    {

        my $patronsX = $dao->getPatronBatch2Import($institution_id);

        # grab the first record from $patrons
        my $patrons->[0] = $patronsX->[0];

        # print $patrons size
        print "patrons size: [" . scalar(@{$patrons}) . "]\n";

        my $json = "";
        for my $patron (@{$patrons})
        {
            $json .= $folio->_buildPatronJSON($patron);
        }
        chop($json);
        chop($json);

        my $patronSize = scalar(@{$patrons});

        $json = $folio->_buildFinalJSON($json, $patronSize);

        my $untouchedJson = $json;

        $json = decode_json($json);
        $json = remove_empty_fields($json);
        $json = encode_json($json);

        # $json = clean_json($json);

        # $json = decode_json($json);
        # $json = clean_hash($json);
        # $json = encode_json($json);

        # $json = $folio->_removeEmptyFields($json);


        # save $json to a file called tmp.json
        open(my $fh, '>', './tmp.json');
        print $fh $json;
        close $fh;

        # save $untouchedJson to a file called untouched.json
        open(my $fh2, '>', './untouched.json');
        print $fh2 $untouchedJson;
        close $fh2;

        print $json . "\n";

    }

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

sub clean_json
{
    my $json = shift;

    $json =~ s/\"\w+\":\s\"\",//g;
    $json =~ s/\"\w+\":\"\",//g;
    $json =~ s/^\n$//g;
    $json =~ s/^\s+$//g;

    $json =~ s/\s+(?=\})//g; # Remove spaces before closing brace
    $json =~ s/\s+(?=\])//g; # Remove spaces before closing bracket
    $json =~ s/\s+(\{)/$1/g; # Remove spaces before opening brace
    $json =~ s/\s+(\[)/$1/g; # Remove spaces before opening bracket
    $json =~ s/,\s+/,/g;     # Remove spaces after comma
    $json =~ s/\:\s+/:/g;    # Remove spaces after colon
    $json =~ s/^\s+//g;

    return $json;

}

sub clean_hash
{
    # my $self = shift;
    my $hash = shift;

    foreach my $key (keys %$hash)
    {
        if (ref $hash->{$key} eq 'HASH')
        {
            clean_hash($hash->{$key});
            delete $hash->{$key} if !%{$hash->{$key}};
        }
        elsif (!defined $hash->{$key} || $hash->{$key} eq '')
        {
            delete $hash->{$key};
        }
    }

    return $hash;

}

# test_endPoint();
sub test_endPoint
{
    my $institution_id = 3;

    my $json = $folio->getFolioUserJSONByESID("ahoudei\@stchas.edu");
    print $json . "\n";

    my $folioUserByESID = decode_json($json);
    print Dumper($folioUserByESID);

}

sub test_buildPatronJSON
{

    my $test_patron = {
        username               => 'testuser',
        externalsystemid       => '12345',
        barcode                => '987654321',
        patrongroup            => 'standard',
        lastname               => 'Doe',
        firstname              => 'John',
        middlename             => 'A',
        preferredfirstname     => 'Johnny',
        phone                  => '123-456-7890',
        mobilephone            => '098-765-4321',
        dateofbirth            => '1990-01-01',
        email                  => 'john.doe@example.com',
        preferredcontacttypeid => 'email',
        enrollmentdate         => '2023-01-01',
        expirationdate         => '2024-01-01'
    };

    my $json = $folio->_buildPatronJSON($test_patron);

    print $json . "\n";

    my $hash = decode_json($json);

    print Dumper($hash);

}

# test_generateFailedPatronsCSVReport();
sub test_generateFailedPatronsCSVReport
{

    my $institution_id = 43;
    my $job_id = 137;

    $folio->generateFailedPatronsCSVReports($institution_id, $job_id);

}

# testQuery();
sub testQuery
{

    print Dumper($dao->queryAsHash("select * from patron_import.institution;"));
    print "=" x 80 . "\n";
    print Dumper($dao->query("select * from patron_import.institution;"));

}

extractFileContentsFromFileTrackerAndWriteThemToDisk();
sub extractFileContentsFromFileTrackerAndWriteThemToDisk
{

    buildDropboxDirectories();

    my $query = "SELECT ft.institution_id, ft.path, ft.size, ft.contents
        FROM patron_import.file_tracker ft
            WHERE ft.lastModified >= EXTRACT(EPOCH FROM TIMESTAMP '2024-07-28 00:00:00')
    ORDER BY ft.institution_id, ft.lastModified;";

    for my $row (@{$dao->query($query)})
    {

        # save $row->[3] to a file
        my $path = $row->[1];
        my $contents = $row->[3];

        print "saving file to disk: [$path]\n";

        # use $parallel to save the file
        open(my $fh, '>', $path);
        print $fh $contents;
        close $fh;

    }

}

# buildDropboxDirectories();
sub buildDropboxDirectories
{

    for my $row (@{$dao->query("select path from patron_import.folder")})
    {
        my $path = $row->[0];
        print "mkdir -p $path\n";
        my $mkdir = `mkdir -p $path`;
    }

}