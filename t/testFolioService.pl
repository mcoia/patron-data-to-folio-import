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

    # my $tenant = $main::conf->{primaryTenant};
    # my $tenant = "cs00000001_0053";
    my $tenant = "cs00000001_0006";

    my $response = $folio->login($tenant);

    print Dumper($response);

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

    my $response = $folio->getImportResponseTotals(\@importResponse);

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

    print Dumper($folio->getImportResponseTotals(\@importResponse));

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

    $string = $folio->escapeIllegalChars($string);

    print "$string";
    print "\n\n";

}