#!/usr/bin/perl
# ---------------------------------------------------------------
# Copyright  2013-2022 MOBIUS
# Blake Graham-Henderson blake@mobiusconsortium.org 2013-2022
# Scott Angel scottangel@mobiusconsoritum.org 2022
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------
package MOBIUS::Email;

use Email::MIME;
use Data::Dumper;
use POSIX qw(floor);

sub new
{
    my ($class, $from, $emailRecipientArrayRef, $errorFlag, $successFlag, $confArrayRef, $debug) = @_;

    my $self = {
        fromEmailAddress    => $from,
        emailRecipientArray => $emailRecipientArrayRef,
        notifyError         => $errorFlag,   #true/false
        notifySuccess       => $successFlag, #true/false
        confArray           => $confArrayRef,
        debug               => $debug
    };

    _setupFinalToList($self);

    bless $self, $class;
    return $self;
}

#subject, body
sub send
{
    my $self = shift;
    my $subject = shift;
    my $body = shift;

    my $message = Email::MIME->create(
        header_str => [
            From    => $self->{fromEmailAddress},
            To      => [ @{$self->{finalToEmailList}} ],
            Subject => $subject
        ],
        attributes => {
            encoding => 'quoted-printable',
            charset  => 'ISO-8859-1',
        },
        body_str   => "$body\n"
    );

    use Email::Sender::Simple qw(sendmail);

    _reportSummary($self, $subject, $body);

    sendmail($message);

    print "Sent\n" if $self->{debug};
}

sub sendHTML
{
    my $self = shift;
    my $subject = shift;
    my $bodyText = shift;
    my $bodyHTML = shift;
    my $boundaryLength = 32;
    my $boundary = _generateRandomString($boundaryLength);

    # what is the point of this?!?!?!
    while (index($bodyHTML, $boundary) != -1)
    {$boundary = _generateRandomString($boundaryLength);}

    my @bodyLines = (
        '--' . $boundary,
        'Content-Type: text/plain; charset="UTF-8"',
        "\n" . $bodyText . "\n",
        '--' . $boundary,
        'Content-Type: text/html; charset="UTF-8"',
        'Content-Transfer-Encoding: quoted-printable',
        "\n" . $bodyHTML . "\n",
        '--' . $boundary . '--',
    );
    my $body_str = '';
    $body_str .= "$_\n" foreach (@bodyLines);

    # print $body_str . "\n";

    # construct our email
    my $message = Email::MIME->create(
        header_str => [
            From    => $self->{fromEmailAddress},
            To      => [ @{$self->{finalToEmailList}} ],
            Subject => $subject,
        ],
        attributes => {
            encoding     => 'quoted-printable',
            charset      => 'ISO-8859-1',
            content_type => 'multipart/alternative',
            boundary     => $boundary,
        },
        body_str   => $body_str
    );

    use Email::Sender::Simple qw(sendmail);

    _reportSummary($self, $subject, $body);

    sendmail($message);

    print "Sent\n" if $self->{debug};
}

sub sendWithAttachments #subject, body, @attachments
{
    use Email::Stuffer;
    my $self = shift;
    my $subject = shift;
    my $body = shift;
    my $attachmentRef = shift;
    my @attachments = @{$attachmentRef};

    foreach (@{$self->{finalToEmailList}})
    {
        my $message = new Email::Stuffer;

        $message->to($_)->from($self->{fromEmailAddress})->text_body($body)->subject($subject);

        if ($self->{debug})
        {
            print "Attaching: '$_'\n" foreach (@attachments);
        }

        # attach the files
        $message->attach_file($_) foreach (@attachments);

        print "Sending with attachments\n" if $self->{debug};
        _reportSummary($self, $subject, $body, \@attachments);
        print "\n";
        $message->send;
        print "Sent\n" if $self->{debug};
    }
}

sub _setupFinalToList
{
    my $self = shift;
    my @ret = ();

    my @varMap = ("successemaillist", "erroremaillist");

    my %conf = %{$self->{confArray}};

    foreach (@varMap)
    {
        my @emailList = split(/,/, $conf{$_});
        for my $y (0 .. $#emailList)
        {
            @emailList[$y] = _trim(@emailList[$y]);
        }
        $self->{$_} = \@emailList;
        print "$_:\n" . Dumper(\@emailList) if $self->{debug};
    }

    undef @varMap;

    push(@ret, @{$self->{emailRecipientArray}})
        if ($self->{emailRecipientArray}->[0]);

    push(@ret, @{$self->{successemaillist}})
        if ($self->{'notifySuccess'});

    push(@ret, @{$self->{erroremaillist}}) if ($self->{'notifyError'});

    print "pre dedupe:\n" . Dumper(\@ret) if $self->{debug};

    # Dedupe
    @ret = @{_deDupeEmailArray($self, \@ret)};

    print "post dedupe:\n" . Dumper(\@ret) if $self->{debug};

    $self->{finalToEmailList} = \@ret;
}

sub _deDupeEmailArray
{
    my $self = shift;
    my $emailArrayRef = shift;
    my @emailArray = @{$emailArrayRef};
    my %posTracker = ();
    my %bareEmails = ();
    my $pos = 0;
    my @ret = ();

    foreach (@emailArray)
    {
        my $thisEmail = $_;

        print "processing: '$thisEmail'\n" if $self->{debug};

        # if the email address is expressed with a display name,
        # strip it to just the email address
        $thisEmail =~ s/^[^<]*<([^>]*)>$/$1/g if ($thisEmail =~ m/</);

        # lowercase it
        $thisEmail = lc $thisEmail;

        # Trim the spaces
        $thisEmail = _trim($thisEmail);

        print "normalized: '$thisEmail'\n" if $self->{debug};

        $bareEmails{$thisEmail} = 1;
        if (!$posTracker{$thisEmail})
        {
            my @a = ();
            $posTracker{$thisEmail} = \@a;
            print "adding: '$thisEmail'\n" if $self->{debug};
        }
        else
        {
            print "deduped: '$thisEmail'\n" if $self->{debug};
        }
        push(@{$posTracker{$thisEmail}}, $pos);
        $pos++;
    }
    while ((my $email, my $value) = each(%bareEmails))
    {
        my @a = @{$posTracker{$email}};

        # just take the first occurance of the duplicate email
        push(@ret, @emailArray[ @a[0] ]);
    }

    return \@ret;
}

sub _reportSummary
{
    my $self = shift;
    my $subject = shift;
    my $body = shift;
    my $attachmentRef = shift;
    my @attachments = ();
    @attachments = @{$attachmentRef} if (ref($attachmentRef) eq 'ARRAY');

    my $characters = length($body);
    my @lines = split(/\n/, $body);
    my $bodySize = $characters / 1024 / 1024;

    print "\n";
    print "From: " . $self->{fromEmailAddress} . "\n";
    print "To: ";
    print "$_, " foreach (@{$self->{finalToEmailList}});
    print "\n";
    print "Subject: $subject\n";
    print "== BODY ==\n";
    print "$characters characters\n";
    print scalar(@lines) . " lines\n";
    print $bodySize . "MB\n";
    print "== BODY ==\n";

    my $fileSizeTotal = 0;
    if ($#attachments > -1)
    {
        print "== ATTACHMENT SUMMARY == \n";

        foreach (@attachments)
        {
            $fileSizeTotal += -s $_;
            my $thisFileSize = (-s $_) / 1024 / 1024;
            print "$_: ";
            printf("%.3f", $thisFileSize);
            print "MB\n";

        }
        $fileSizeTotal = $fileSizeTotal / 1024 / 1024;

        print "Total Attachment size: ";
        printf("%.3f", $fileSizeTotal);
        print "MB\n";
        print "== ATTACHMENT SUMMARY == \n";
    }

    $fileSizeTotal += $bodySize;
    print "!!!WARNING!!! Email (w/attachments) Exceeds Standard 25MB\n"
        if ($fileSizeTotal > 25);
    print "\n";

}

sub _trim
{
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

sub _generateRandomString
{
    my $length = shift;

    my @chars = split('', "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789");
    my $charLength = @chars;
    my $randomString = "";
    $randomString .= @chars[floor(rand($charLength))] for (1 .. $length);

    return $randomString;
}

1;
