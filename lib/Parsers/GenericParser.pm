package Parsers::GenericParser;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use MOBIUS::Utils;
use JSON;
use Try::Tiny;

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
            $self->{debug}->{path} = $path;

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

                my $esidBuilder = Parsers::ESID->new($institution, $patron);

                # Set the External System ID
                $patron->{esid} = $esidBuilder->getESID();

                # skip if we didn't get an esid
                next if (!defined($patron->{esid}));
                next if ($patron->{esid} eq '');

                # Note, everything in the patron hash gets 'fingerprinted'.
                # id's are basically irrelevant after and may change on subsequent loads. So we don't want
                # to finger print id's. job_id being one that WILL change.
                $patron->{fingerprint} = $self->getPatronFingerPrint($patron);

                # set some id's, I decided I needed these for tracking down trash
                $patron->{load} = 'true';
                $patron->{institution_id} = $institution->{id};
                $patron->{file_id} = $file->{id};
                $patron->{job_id} = $main::jobID;

                # We need to check this list for double entries.
                # Some patron files have double entries.
                push(@parsedPatrons, $patron);
                    # unless (grep /$patron->{unique_id}/, map {$_->{unique_id}} @parsedPatrons);
                $patronCounter++;
            }

        }

        print "Total Patrons in $file->{name}: [$patronCounter]\n" if($main::conf->{print2Console});
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
e = External System ID === NEW

=cut
sub _parsePatronRecord
{
    my $self = shift;
    my $patronRecord = shift;

    my $patron = {
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

        # sanitize the garbage. I should probably expand on this a little.
        $data =~ s/^\s*//g if ($data =~ /^0/);
        $data =~ s/\s*$//g if ($data =~ /^0/);
        $data =~ s/\n//g if ($data =~ /^0/);
        $data =~ s/\r//g if ($data =~ /^0/);

        # zero field
        $patron->{'field_code'} = '0' if ($data =~ /^0/);

        # Each library defines a specific set of values for locally needed patron types. This value determines the borrowers’
        # privileges, renewals, loan periods, notices, and fine amounts if any.
        # I'm adding + 0 to have perl convert this to a number.
        try
        {$patron->{'patron_type'} = substr($data, 1, 3) + 0 if ($data =~ /^0/);}
        catch
        {$patron->{'patron_type'} = ($data =~ /^0(\d{3}).*/gm)[0] + 0 if ($data =~ /^0/);};

        # pcode1 (1 character)
        # This one-character code can be used for a variety of statistical subdivisions. Libraries in a system (cluster)
        # determine the codes used. If no code is assigned, the field should contain a hyphen (“-“).
        try
        {$patron->{'pcode1'} = substr($data, 4, 1) if ($data =~ /^0/);}
        catch
        {$patron->{'pcode1'} = ($data =~ /^0\d{3}(.{1}).*/gm)[0] if ($data =~ /^0/);};

        # PCODE2 (1 character)
        # This one-character code can be used for a variety of statistical subdivisions. Libraries in a system (cluster)
        # determine the codes used. If no code is assigned, the field should contain a hyphen (“-“)
        try
        {$patron->{'pcode2'} = substr($data, 5, 1) if ($data =~ /^0/);}
        catch
        {$patron->{'pcode2'} = ($data =~ /^0\d{3}.{1}(.{1}).*/gm)[0] if ($data =~ /^0/);};

        # PCODE3 (000 to 255)
        # This three-digit numeric code can be used for a variety of statistical subdivisions. Libraries in a system (cluster)
        # determine the codes used. (If your cluster does not have a PCODE3 value for N/A, enter “ “ three blanks if
        # PCODE3 is not defined on your system.)
        try
        {$patron->{'pcode3'} = substr($data, 6, 3) if ($data =~ /^0/);}
        catch
        {$patron->{'pcode3'} = ($data =~ /^0\d{3}.{2}(.{3}).*/gm)[0] if ($data =~ /^0/);};

        # Home Library (5 characters)
        # This field uses a location code defined in the location tables. For all MOBIUS libraries this code should be one of
        # the three-character bibliographic locations entered in lower case letters and padded with two blanks. For example:
        # “wdb “
        try
        {$patron->{'home_library'} = substr($data, 9, 5) if ($data =~ /^0/);}
        catch
        {$patron->{'home_library'} = ($data =~ /^0\d{3}.{2}.{3}(.{5}).*/gm)[0] if ($data =~ /^0/);};

        # Patron Message Code (1 character)
        # A value in this field triggers the display of the associated message each time a user selects and displays the patron
        # record. Libraries in a system (cluster) determine the codes used and the messages associated with them. (Hyphen
        # unless defined)
        try
        {$patron->{'patron_message_code'} = substr($data, 14, 1) if ($data =~ /^0/);}
        catch
        {$patron->{'patron_message_code'} = ($data =~ /^0\d{3}.{2}.{3}.{5}(.{1}).*/gm)[0] if ($data =~ /^0/);};

        # Patron Block Code (1 character)
        # This code allows libraries to manually block a patron from checking-out or renewing items even if the patron has not
        # exceeded any of the library-specified thresholds on the system. It allows blocks from elsewhere on campus to be
        # reflected in the library system. The institution can set a code in the file of patron records to be loaded to either
        # create a new record on the system already blocked to update an existing borrower to block. Libraries in a system
        # (cluster) determine the codes used and the meaning associated with each. Codes must be entered in a system table.
        # (Hyphen unless defined)
        try
        {$patron->{'patron_block_code'} = substr($data, 15, 1) if ($data =~ /^0/);}
        catch
        {$patron->{'patron_block_code'} = ($data =~ /^0\d{3}.{2}.{3}.{6}(.{1}).*/gm)[0] if ($data =~ /^0/);};

        # Patron Expiration Date (8 characters, mm-dd-yy)
        # Patron records loaded into the system overlay on a key-match (see UNIQUEID). The incoming record expiration
        # date replaces the one in the database record. Libraries determine the expiration date needed to prevent loan periods
        # longer than the expiration date in the patron’s record.
        try
        {$patron->{'patron_expiration_date'} = substr($data, 16, 8) if ($data =~ /^0/);}
        catch
        {$patron->{'patron_expiration_date'} = ($data =~ /--(\d+.*$)/gm)[0] if ($data =~ /^0/);};

        # ========== Variable Length Fields

        # Name
        # The name is entered as indexed: last name, first middle. It will display online and print on notices as entered. If you
        # want mixed case or if you want all capitals for mailing, enter the name in that format.
        $patron->{'name'} = ($data =~ /^n(.*)$/gm)[0] if ($data =~ /^n/);

        # Address
        # This is the primary or local address field. Enter a dollar sign (“$”) to indicate a line break as shown in the example
        # record. Notice production does not upcase name and address information. If your library will be sending notices
        # through the mail, you may want to enter all this information in capital letters
        $patron->{'address'} = ($data =~ /^a(.*)$/gm)[0] if ($data =~ /^a/);

        # Address2
        # This is a secondary or permanent address. For students this may be the home address.
        $patron->{'address2'} = ($data =~ /^h(.*)$/gm)[0] if ($data =~ /^h/);

        # Telephone
        # This is the primary or local telephone number. There is no automatic formatting of this data. If you want “( )”
        # around the area code and “-“ after the exchange, those characters need to be in the record.
        $patron->{'telephone'} = ($data =~ /^t(.*)$/gm)[0] if ($data =~ /^t/);

        # Telephone2
        # Secondary telephone number.
        $patron->{'telephone2'} = ($data =~ /^p(.*)$/gm)[0] if ($data =~ /^p/);

        # Department
        # MOBIUS systems use this field to provide a library return address for INN-Reach (Direct Patron) Request notices.
        # This is a local adaptation and is not documented in the User Manual. Enter the same three-character bibliographic
        # location code used in the Home Library fixed field in lower case letters. Do not follow it with blank spaces.
        $patron->{'department'} = ($data =~ /^d(.*)$/gm)[0] if ($data =~ /^d/);

        # Unique ID
        # This is an extremely important field for patron records in a MOBIUS system. Whether a record is loaded or keyed
        # in at a circulation desk, it should have a properly constructed Unique ID. The patron keys this number to see
        # information about his account and to place requests, and the patron load program uses this field as the key for
        # updating existing patron records in the database.
        # The MOBIUS implementation of Unique ID is a combination of a patron identification number and an alpha suffix
        # identifying the institution. The identification number can be any number unique within your institution and easily
        # known by the patron, for example, a student number. The alpha suffix follows the number in all capital letters with
        # no spaces.
        # Example:
        # Using Sequential Campus Number
        # 12345678CC (Columbia College)
        $patron->{'unique_id'} = ($data =~ /^u(.*)$/gm)[0] if ($data =~ /^u/);

        # Barcode
        # The patron barcode field is an indexed variable length field. It is usually the quickest and most precise patron search
        # at the circulation desk. Circulation staff does not have to use the patron barcode to check out a book to a patron. If
        # your institution uses a campus identification card, you can load the number encoded on the card into this field. If
        # your institution uses a separate barcode (i.e., issued by the library, not the campus), the barcodes must be added
        # manually. This can be done when keying a new record or later if patron records are loaded from a registration database.
        $patron->{'barcode'} = ($data =~ /^b(.*)$/gm)[0] if ($data =~ /^b/);

        # Email Address
        # Enter a complete email address if you want a patron to receive all borrower notices via email.
        $patron->{'email_address'} = ($data =~ /^z(.*)$/gm)[0] if ($data =~ /^z/);

        # Note
        # This is free text note field. A Patron record can contain multiple note fields. The patron note fields only display to
        # staff, not to patrons in the VIEW your circulation record function.
        $patron->{'note'} = ($data =~ /^x(.*)$/gm)[0] if ($data =~ /^x/);

        # External System ID === NEW
        # This is a new field introduced after this project has started. No official description.
        $patron->{'esid'} = ($data =~ /^e(.*)$/gm)[0] if ($data =~ /^e/);

    }


    # set the raw_data for this patron. This raw data gets fingerprinted!
    my $raw_data = "";
    for my $data (@{$patronRecord})
    {$raw_data .= $data . "\n";}
    $patron->{raw_data} = $raw_data;

    return $patron;
}

1;