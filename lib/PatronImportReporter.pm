package PatronImportReporter;
use strict;
use warnings FATAL => 'all';
use MOBIUS::Email;
use POSIX qw/strftime/;
use Try::Tiny;
use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {
        'institution' => shift,
        'response'    => shift,
        'failed'      => shift,
        'message'     => '',
    };
    bless $self, $class;
    return $self;
}

sub buildReport
{
    my $self = shift;

    $self->{reportTime} = strftime('%m-%d-%Y', localtime);
    $self->{message} = $self->_buildMessage();

    my $template = "";
    $self->{failedHTML} = "";
    $self->{failedHTML} = $self->_buildFailedUsersTextTemplate() if ($main::conf->{emailType} eq 'text' && $main::conf->{includeFailedPatrons} eq 'true');
    $self->{failedHTML} = $self->_buildFailedUsersHTMLTemplate() if ($main::conf->{emailType} eq 'html' && $main::conf->{includeFailedPatrons} eq 'true');

    $template = $main::files->readFileAsString($main::conf->{projectPath} . "/resources/reports/report.txt") if ($main::conf->{emailType} eq 'text');
    $template = $main::files->readFileAsString($main::conf->{projectPath} . "/resources/reports/report-with-failures.html") if ($main::conf->{emailType} eq 'html' && $main::conf->{includeFailedPatrons} eq 'true');
    $template = $main::files->readFileAsString($main::conf->{projectPath} . "/resources/reports/report.html") if ($main::conf->{emailType} eq 'html' && $main::conf->{includeFailedPatrons} eq 'false');

    $template =~ s/"/\\"/g;
    $template =~ s/\@/\\@/g;
    $template =~ s/\%/\\%/g;

    $template = '$template = "' . $template . '";';

    eval $template;

    $self->{template} = $template;

    return $self;
}

sub buildFailedPatronCSVReport
{
    my $self = shift;

    # We need to save a copy of the failed csv report to the dropbox path.

    my $institution = $self->{institution};

    # app.get('/api/patron-import/institution/:id/job/:job_id/failed-patrons/download', patronImport.getFailedUsersByInstitutionIdAndJobIdDownloadCSV);

    # we need to make an api call to get the failed users csv report

    # now save the csv to the dropbox path

    return $self;

}


sub sendEmail
{
    my $self = shift;

    return $self if($main::conf->{sendEmail} eq 'false');

    my $emailAddresses = $self->{institution}->{emailsuccess};

    # We don't have any email address to send too!
    print "no email address to send to\n" if (!defined($emailAddresses) && $main::conf->{print2Console});
    $main::log->add("no email address to send to") if (!defined($emailAddresses));
    return $self if (!defined($emailAddresses));

    print "Sending emails to these addresses: [$emailAddresses]\n" if ($main::conf->{print2Console} eq 'true');
    $main::log->add("Sending emails to these addresses: [$emailAddresses]");

    my @emailAddresses = split(',', $emailAddresses);


    try
    {
        # send a single email to each address, we have people responding to everyone in the email instead of creating a ticket.
        for my $emailAddress (@emailAddresses)
        {

            $emailAddress =~ s/\s+//g;
            my @emailAddressSingleEmailArray = ($emailAddress);

            my $email = MOBIUS::Email->new($main::conf->{fromAddress}, \@emailAddressSingleEmailArray, 0, 0);
            $email->sendHTML($main::conf->{subject}, "MOBIUS", $self->{template});

        }

    }
    catch
    {
        print "Email bombed!!!\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->add("******************* Email BOMBED *******************");
        $main::log->add("=================== EMAIL START ===================");
        $main::log->add($self->{template});
        $main::log->add("=================== EMAIL END ===================");
    };

    return $self;

}

sub _buildFailedUsersTextTemplate
{
    my $self = shift;

    my $text = "";
    for my $failed (@{$self->{failed}})
    {

        my $failedText = <<"TEXT";
                $failed->{username}
                $failed->{errorMessage}
TEXT

        $text .= $failedText;
    }

    return $text;

}

sub _buildFailedUsersHTMLTemplate
{
    my $self = shift;

    my $html = "";
    for my $failed (@{$self->{failed}})
    {

        my $failedHTML = <<"HTML";
            <tr>
                <td>$failed->{username}</td>
                <td>$failed->{errorMessage}</td>
            </tr>

HTML

        $html .= $failedHTML;
    }

    return $html;

}

sub _buildMessage
{
    my $self = shift;

    $self->{message} = "No Records Added or Updated" if ($self->{response}->{total} == 0);

}

1;