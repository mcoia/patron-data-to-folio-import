package Parsers::GenericParser;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use MOBIUS::Utils;

use parent 'Parser';

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

=head1 _parsePatronRecord(@patronrecord)

The initial field: Always 24 char long
example: 0101c-003clb  --01/31/24

Field:Char Length
------------
Field Code: 1
Patron Type: 3 (000 to 255)
PCODE1: 1
PCODE2: 1
PCODE3: 3 (000 to 255)
Home Library: 5 char, padded with blanks if needed (e.g. "shb  ")
Patron Message Code: 1
Patron Block Code: 1
Patron Expiration Date: 8 (mm-dd-yy)

Patron Parser Info:
n = Name
a = Address
t = Telephone
h = Address2
p = Telephone2
d = Department
u = Unique ID
b = Barcode
z = Email Address
x = Note

e = esid / External System ID

The way this works...
We start with a list of file paths of known discovered files
We read each file, line by line chunking each patron into an array of arrays.
We then loop this "patron" array and parse.

=cut
sub parse
{

    my $self = shift;
    my $institution = shift;

    my @parsedPatrons = ();

    for my $file (@{$institution->{'folder'}->{files}})
    {

        my $patronCounter = 0;
        for my $path (@{$file->{'paths'}})
        {

            my @patronRecords = ();
            my @patronRecord = ();
            my $patronRecordSize = 0;

            # Read our patron file into an array.
            my $data = $main::files->readFileToArray($path);

            for my $line (@{$data})
            {
                # $line =~ s/\s*$//g; # some libraries don't respect the 24 char limit. Whitespace.
                # if ($line =~ /^0/ && length($line) == 24)
                if ($line =~ /^0/)
                {
                    $patronRecordSize = @patronRecord;
                    my @patronRecordCopy = @patronRecord;
                    push(@patronRecords, \@patronRecordCopy) if ($patronRecordSize > 0);
                    @patronRecord = ();
                }

                push(@patronRecord, $line);

            }

            # Push our last record
            $patronRecordSize = @patronRecord;
            push(@patronRecords, \@patronRecord) if ($patronRecordSize > 0);

            # Now we do the actual parsing of this data.
            for my $record (@patronRecords)
            {

                my $patron = $self->_parsePatronRecord($record);

                $patron->{esid} = Parsers::ESID::getESID($patron, $institution)
                    if ($institution->{'esid'} ne '' && !defined($patron->{'esid'}));

                # Note, everything in the patron hash gets 'fingerprinted'.
                # id's are basically irrelevant after and may change on subsequent loads. So we don't want
                # to finger print id's.
                $patron->{fingerprint} = $self->getPatronFingerPrint($patron);

                # set some id's, I decided I needed these for tracking down trash
                $patron->{institution_id} = $institution->{id};
                $patron->{file_id} = $file->{id};
                $patron->{job_id} = $main::jobID;

                push(@parsedPatrons, $patron);
                $patronCounter++;
            }

        }

        print "Total Patrons in $file->{name}: [$patronCounter]\n";
        $main::log->addLine("Total Patrons in $file->{name}: [$patronCounter]\n");

    }

    return \@parsedPatrons;

}

=head1 _parsePatronRecord(@patronrecord)

The initial field: Always 24 char long
example: 0101c-003clb  --01/31/24

Field:Char Length
------------
Field Code: 1
Patron Type: 3 (000 to 255)
PCODE1: 1
PCODE2: 1
PCODE3: 3 (000 to 255)
Home Library: 5 char, padded with blanks if needed (e.g. "shb  ")
Patron Message Code: 1
Patron Block Code: 1
Patron Expiration Date: 8 (mm-dd-yy)

Patron Parser Info:
n = Name
a = Address
t = Telephone
h = Address2
p = Telephone2
d = Department
u = Unique ID
b = Barcode
z = Email Address
x = Note


=cut
sub _parsePatronRecord
{
    my $self = shift;
    my $patronRecord = shift;

    # my $patron = $self->_initPatronHash();
    my $patron = {
        '0'                      => "",
        'patron_type'            => "",
        'pcode1'                 => "",
        'pcode2'                 => "",
        'pcode3'                 => "",
        'home_library'           => "",
        'patron_message_code'    => "",
        'patron_block_code'      => "",
        'patron_expiration_date' => "",
        'name'                   => "",
        'address'                => "",
        'telephone'              => "",
        'address2'               => "",
        'telephone2'             => "",
        'department'             => "",
        'unique_id'              => "",
        'barcode'                => "",
        'email_address'          => "",
        'note'                   => "",
        'esid'                   => "",
    };

    # loop thru our patron record
    for my $data (@{$patronRecord})
    {

        # zero field
        $patron->{'field_code'} = '0' if ($data =~ /^0/);
        $patron->{'patron_type'} = ($data =~ /^0(\d{3}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'pcode1'} = ($data =~ /^0\d{3}(.{1}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'pcode2'} = ($data =~ /^0\d{3}.{1}(.{1}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'pcode3'} = ($data =~ /^0\d{3}.{2}(\d{3}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'home_library'} = ($data =~ /^0\d{3}.{2}\d{3}(.{5}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'patron_message_code'} = ($data =~ /^0\d{3}.{2}\d{3}.{5}(.{1}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'patron_block_code'} = ($data =~ /^0\d{3}.{2}\d{3}.{6}(.{1}).*/gm)[0] if ($data =~ /^0/);

        # $patron->{'patron_expiration_date'} = ($data =~ /^0\d{3}.{2}\d{3}.{7}(.{8}).*/gm)[0] if ($data =~ /^0/);

        $patron->{'patron_expiration_date'} = ($data =~ /--(.*)/gm)[0] if ($data =~ /^0/);


        # variable length fields
        $patron->{'name'} = ($data =~ /^n(.*)$/gm)[0] if ($data =~ /^n/);
        $patron->{'address'} = ($data =~ /^a(.*)$/gm)[0] if ($data =~ /^a/);
        $patron->{'telephone'} = ($data =~ /^t(.*)$/gm)[0] if ($data =~ /^t/);
        $patron->{'address2'} = ($data =~ /^h(.*)$/gm)[0] if ($data =~ /^h/);
        $patron->{'telephone2'} = ($data =~ /^p(.*)$/gm)[0] if ($data =~ /^p/);
        $patron->{'department'} = ($data =~ /^d(.*)$/gm)[0] if ($data =~ /^d/);
        $patron->{'unique_id'} = ($data =~ /^u(.*)$/gm)[0] if ($data =~ /^u/);
        $patron->{'barcode'} = ($data =~ /^b(.*)$/gm)[0] if ($data =~ /^b/);
        $patron->{'email_address'} = ($data =~ /^z(.*)$/gm)[0] if ($data =~ /^z/);
        $patron->{'note'} = ($data =~ /^x(.*)$/gm)[0] if ($data =~ /^x/);
        $patron->{'esid'} = ($data =~ /^e(.*)$/gm)[0] if ($data =~ /^e/);

    }

    return $patron;
}

# Individual parsers are responsible for saving their data.
sub saveStagedPatronRecordsOLD
{
    my $self = shift;
    my $patronRecords = shift;

    for my $patron (@{$patronRecords})
    {
        $main::dao->_insertHashIntoTable("stage_patron", $patron);
    }

}

sub _parseName
{
    my $self = shift;
    my $patron = shift;

    my $name = $patron->{name};

    # Altis, Daniel M.
    my $last = ($name =~ /^(.*),/gm)[0];
    my $first = ($name =~ /^.*,\s(.*)/gm)[0];

    my $middle = "";
    $middle = ($first =~ /\s(.*)$/gm)[0] if ($first =~ /\s/);

    $first = ($first =~ /(.*)\s/gm)[0] if ($first =~ /\s/);

    $patron->{firstName} = $first;
    $patron->{middleName} = $middle;
    $patron->{lastName} = $last;

    # print "[$name]=[$first][$middle][$last]\n";

    # Sometimes we don't get a first or last name so we just set the first and last name to name.
    # Let them figure it out later. It's like .05%
    # $patron->{firstName} = $name if ($first eq '' && $last eq '');
    # $patron->{lastName} = $name if ($first eq '' && $last eq '');

    return $patron;

}

sub _parseAddress
{

    my $self = shift;
    my $patron = shift;

    my $address = $patron->{address};

    $patron->{street} = ($address =~ /^(.*)\$/gm)[0];
    $patron->{city} = ($address =~ /^.*\$(.*),/gm)[0];
    $patron->{state} = ($address =~ /,\s(\w{2})/gm)[0];
    $patron->{zip} = ($address =~ /,\s\w{2}\s\s(.*)$/gm)[0];

    return $patron;

}

sub _getUsername
{
    my $self = shift;
    my $patron = shift;

    # what field do we use for a username?
    # return $patron->{barcode};
    return $patron->{email_address};

}

1;