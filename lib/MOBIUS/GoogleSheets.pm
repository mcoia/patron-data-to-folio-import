package MOBIUS::GoogleSheets;
use strict;
use warnings FATAL => 'all';

sub new
{
    my $class = shift;
    my $self = {
        'url'     => shift,
        'zipURL'  => '',
        'sheetID' => '',
        'gid'     => ''
    };
    bless $self, $class;
    return $self;
}

# Note: this only grabs the 1st google sheet.
sub getSheetCSVByID
{

    my $self = shift;
    my $id = shift;

    my $url = "https://docs.google.com/spreadsheets/u/1/d/$id/export?format=csv&id=$id&gid=0";
    my @wget = `wget -q -O /dev/stdout $url > /dev/null  2>&1`;
    chomp(@wget);

    return \@wget;

}

sub getSheets
{
    my $self = shift;
    my $url = $self->{'url'};

    my $sheetID = ($url =~ /https:\/\/docs\.google\.com\/spreadsheets\/d\/(.*)\//)[0];
    my $gid = ($url =~ /gid=(.*)$/)[0];
    $url =~ s/edit#gid=\d*/export\?format=zip/g;

    # We don't have a parsable url, just stop.
    return if ($sheetID eq '' || !defined($sheetID));

    # Set some local vars
    $self->{'zipURL'} = $url;
    $self->{'sheetID'} = $sheetID;
    $self->{'gid'} = $gid;

    print $self->{url} . "\n";
    print $sheetID . "\n";
    print $gid . "\n";
    print $self->{zipURL} . "\n";

    return $self;
}

sub _downloadZip
{
    my $self = shift;
    my $time = time();
    my $url = $self->{'zipURL'};
    print "downloading zip... $url\n";
    my $fileName = $self->{sheetID};
    my @zip = `wget -q -O $fileName.zip $url`;

    return $self;
}

1;