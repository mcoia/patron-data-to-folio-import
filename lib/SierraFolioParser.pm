package SierraFolioParser;

use strict;
use warnings FATAL => 'all';

=pod


=head1 new(log)

=cut
sub new
{
    my $class = shift;
    my $self = {
        'conf' => shift,
        'log'  => shift,
    };
    bless $self, $class;
    return $self;
}

=head1 parse()


=cut
sub parse
{

    my $self = shift;
    my $data = shift; # <== array of lines read from some file

=pod

This is kind of a wrapper method. 
    
It takes our file @data, loops thru and isolates each patron record to be 
handed off to our patron parser. and returns an array of json data. 

=cut


    my @jsonEntries = ();

    my @patronRecord = ();
    my $patronRecordSize = 0;

    for my $line (@{$data})
    {

        # start a new patron record  
        if ($line =~ /^0/ && length($line) == 24)
        {
            $patronRecordSize = @patronRecord;

            push(@jsonEntries,
                $self->processPatronRecord($self->buildPatronHash(\@patronRecord))
            ) if ($patronRecordSize > 0);

            @patronRecord = (); # clear our patron record 
        }

        push(@patronRecord, $line);

    }


    # take our jsonEntries and build out a complete json array. 
    # Basically "[@jsonEntries]"
    return "[@jsonEntries]";

}

sub initPatronHash
{
    my $self = shift;

    my $patron;
    $patron->{'field_code'} = "";
    $patron->{'patron_type'} = "";
    $patron->{'pcode1'} = "";
    $patron->{'pcode2'} = "";
    $patron->{'pcode3'} = "";
    $patron->{'home_library'} = "";
    $patron->{'patron_message_code'} = "";
    $patron->{'patron_block_code'} = "";
    $patron->{'patron_expiration_date'} = "";
    $patron->{'name'} = "";
    $patron->{'address'} = "";
    $patron->{'telephone'} = "";
    $patron->{'address2'} = "";
    $patron->{'telephone2'} = "";
    $patron->{'department'} = "";
    $patron->{'unique_id'} = "";
    $patron->{'barcode'} = "";
    $patron->{'email_address'} = "";
    $patron->{'note'} = "";

    return $patron;
}

=head1 buildPatronHash(@patronrecord)

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
sub buildPatronHash
{
    my $self = shift;
    my $patronRecord = shift;

    my $patron = $self->initPatronHash();

    # loop thru our patron record
    for my $data (@{$patronRecord})
    {

        # TODO: this should be in conf: uncomment to replace spaces with hyphens. 
        # $data = $data =~ s/\s/-/gr if ($data =~ /^0/);

        # zero field
        $patron->{'field_code'} = '0' if ($data =~ /^0/);
        $patron->{'patron_type'} = ($data =~ /^0(\d{3}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'pcode1'} = ($data =~ /^0\d{3}(.{1}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'pcode2'} = ($data =~ /^0\d{3}.{1}(.{1}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'pcode3'} = ($data =~ /^0\d{3}.{2}(\d{3}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'home_library'} = ($data =~ /^0\d{3}.{2}\d{3}(.{5}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'patron_message_code'} = ($data =~ /^0\d{3}.{2}\d{3}.{5}(.{1}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'patron_block_code'} = ($data =~ /^0\d{3}.{2}\d{3}.{6}(.{1}).*/gm)[0] if ($data =~ /^0/);
        $patron->{'patron_expiration_date'} = ($data =~ /^0\d{3}.{2}\d{3}.{7}(.{8}).*/gm)[0] if ($data =~ /^0/);

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

    }

    return $patron;
}

=head1 processPatronRecord($patron) returns a single json record for this patron.


=cut
sub processPatronRecord
{
    my $self = shift;
    my $patron = shift;


















}

sub jsonTemplate
{
    my $self = shift;
    my $patron = shift;

    my $jsonTemplate = "

{
  \"username\": \"$patron->{username}\",
  \"externalSystemId\": \"111_112\",
  \"barcode\": \"1234567\",
  \"active\": true,
  \"patronGroup\": \"staff\",
  \"personal\": {
    \"lastName\": \"Handey\",
    \"firstName\": \"Jack\",
    \"middleName\": \"Michael\",
    \"preferredFirstName\": \"Jackie\",
    \"phone\": \"+36 55 230 348\",
    \"mobilePhone\": \"+36 55 379 130\",
    \"dateOfBirth\": \"1995-10-10\",
    \"addresses\": [
      {
        \"countryId\": \"HU\",
        \"addressLine1\": \"Andrássy Street 1.\",
        \"addressLine2\": \"\",
        \"city\": \"Budapest\",
        \"region\": \"Pest\",
        \"postalCode\": \"1061\",
        \"addressTypeId\": \"Home\",
        \"primaryAddress\": true
      }
    ],
    \"preferredContactTypeId\": \"mail\"
  },
  \"enrollmentDate\": \"2017-01-01\",
  \"expirationDate\": \"2019-01-01\",
  \"customFields\": {
    \"scope\": \"Design\",
    \"specialization\": [
      \"Business\",
      \"Jurisprudence\"
    ]
  },
  \"requestPreference\": {
    \"holdShelf\": true,
    \"delivery\": true,
    \"defaultServicePointId\": \"00000000-0000-1000-a000-000000000000\",
    \"defaultDeliveryAddressTypeId\": \"Home\",
    \"fulfillment\": \"Hold Shelf\"
  },
  \"departments\": [
    \"Accounting\",
    \"Finance\",
    \"Chemistry\"
  ]
}



";

}

1;