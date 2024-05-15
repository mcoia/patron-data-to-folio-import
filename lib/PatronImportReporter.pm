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

    $self->{failedHTML} = $self->_buildFailedUsersTemplate();
    $self->{reportTime} = strftime('%m-%d-%Y', localtime);
    $self->{message} = $self->_buildMessage();

    my $template = $main::files->readFileAsString($main::conf->{projectPath} . "/resources/html/report.html");

    $template =~ s/"/\\"/g;
    $template =~ s/\@/\\@/g;
    $template =~ s/\%/\\%/g;

    $template = '$template = "' . $template . '";';

    eval $template;

    $self->{template} = $template;

    return $self;
}

sub sendEmail
{
    my $self = shift;

    my $emailAddresses = $self->{institution}->{emailsuccess};

    # We don't have any email address to send too!
    print "no email address to send to\n" if (!defined($emailAddresses));
    $main::log->add("no email address to send to") if (!defined($emailAddresses));
    return $self if (!defined($emailAddresses));

    print "Sending emails to these addresses: [$emailAddresses]\n";
    $main::log->add("Sending emails to these addresses: [$emailAddresses]");

    my @emailAddresses = split(',', $emailAddresses);

    try
    {

        my $email = MOBIUS::Email->new($main::conf->{fromAddress}, \@emailAddresses, 0, 0);
        $email->sendHTML($main::conf->{subject}, "MOBIUS", $self->{template});

    }
    catch
    {
        print "Email bombed!!!\n";
        $main::log->add("******************* Email BOMBED *******************");
        $main::log->add("=================== EMAIL START ===================");
        $main::log->add($self->{template});
        $main::log->add("=================== EMAIL END ===================");
    };

    return $self;

}

sub _buildFailedUsersTemplate
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