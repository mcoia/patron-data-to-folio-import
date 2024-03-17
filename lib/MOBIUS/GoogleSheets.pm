package MOBIUS::GoogleSheet;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Cwd qw();

my $cwd = Cwd::cwd();

sub new
{
    my $class = shift;
    my $self = {
        'url'              => shift,
        'zipURL'           => '',
        'sheetID'          => '',
        'gid'              => '',
        'tmpDirectoryPath' => $cwd . '/tmp',
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

    $self->_parseURL();

    # Download the google sheet as a zip file
    # $self->_mkdir("$self->{tmpDirectoryPath}/$self->{sheetID}")->_downloadZip()->_extractZipFile()->_deleteZipFile();

    $self->_loadHTMLFiles($self->_getSheetsHTMLFilePaths())->_parseHTML2CSV();

}

sub _parseURL
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

}

sub _downloadZip
{

    my $self = shift;

    my $url = $self->{'zipURL'};
    print "downloading zip... $url\n";
    my @zip = `wget -q -O $self->{tmpDirectoryPath}/$self->{sheetID}.zip $url`;

    return $self;
}

sub _extractZipFile
{
    my $self = shift;

    my @unzip = `unzip -o $self->{tmpDirectoryPath}/$self->{sheetID}.zip -d $self->{tmpDirectoryPath}/$self->{sheetID}`;

    return $self;
}

sub _setURL
{

    my $self = shift;
    my $url = shift;
    $self->{url} = $url;
    return $self;
}

sub _setTempDirectory
{

    my $self = shift;
    my $filePath = shift;

    $self->{tmpDirectoryPath} = $filePath;

    return $self;

}

sub _mkdir
{
    my $self = shift;
    my $filePath = shift;

    my @command = `mkdir -p $filePath`;

    return $self;
}

sub _deleteZipFile
{
    my $self = shift;
    my @deleteZip = `rm $self->{tmpDirectoryPath}/$self->{sheetID}.zip`;
    return $self;
}

sub _getSheetsHTMLFilePaths
{

    my $self = shift;

    my @htmlFiles = `ls $self->{tmpDirectoryPath}/$self->{sheetID}/*.html`;
    chomp(@htmlFiles);

    return \@htmlFiles;

}

sub _loadHTMLFiles
{

    my $self = shift;
    my $files = shift;

    my $index = 0;
    for my $file (@{$files})
    {
        my ($fileName) = $file =~ /$self->{tmpDirectoryPath}\/$self->{sheetID}\/(.*.html)$/g;
        $self->{sheets}->[$index]->{raw} = $self->_openFile($file);
        $self->{sheets}->[$index]->{name} = $fileName;
        $index++;
    }

    return $self;

}

sub _openFile
{
    my $self = shift;
    my $file = shift;

    # // open the file $file
    open(my $fh, '<', $file) or die "Could not open file '$file' $!";
    my $html = do {
        local $/;
        <$fh>
    };
    close($fh);

    return $html;

}

sub _parseHTML2CSV
{
    my $self = shift;

    for my $sheet (@{$self->{sheets}})
    {

        my $html = $sheet->{raw};
        ($html) = $html =~ /(<table.*table>)/g;

        my $tableColumns = $self->getTableColumns($html);


        # $html =~ s/(\/\w*)>/$1>\n/g;
        # $html =~ s/></>\n</g;
        # my @tags = $html =~ /(.*)\n/g;

        # print "$html\n";
        # print "@th\n";

    }

}

sub getTableColumns
{
    my $self = shift;
    my $html = shift;

    my @th = $html =~ /(<thead.*\/thead>)/g;

    my @data =

    print "@data\n";

}

1;