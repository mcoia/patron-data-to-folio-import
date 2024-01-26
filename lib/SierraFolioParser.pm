package SierraFolioParser;

use strict;
use warnings FATAL => 'all';
use Data::Dumper;

=pod


=head1 new(log)

=cut
sub new
{
    my $class = shift;
    my $self = {
        'conf'  => shift,
        'log'   => shift,
        'db'    => shift,
        'files' => shift,
    };
    bless $self, $class;
    return $self;
}

=head1 parse()

This is kind of a wrapper method. 
    
It takes our file @data, loops thru and isolates each patron record to be 
handed off to our patron parser. and returns an array of json data. 

=cut
sub parse
{

    my $self = shift;
    my ($file, $cluster, $institution, $data) = shift;

    my @patronRecords = ();
    my @patronRecord = ();
    my $patronRecordSize = 0;

    for my $line (@{$data})
    {

        # start a new patron record  
        if ($line =~ /^0/ && length($line) == 24)
        {
            $patronRecordSize = @patronRecord;

            $self->{log}->addLine("parsing record: [@patronRecord]");

            my $patron = $self->_parsePatronRecord(\@patronRecord);
            $patron->{cluster} = $cluster;
            $patron->{institution} = $institution;
            $patron->{file} = $file;
            $patron->{patronGroup} = $self->_mapPatronTypeToPatronGroup($patron) if ($patronRecordSize > 0);
            $patron->{externalID} = $self->_getExternalID($patron) if ($patronRecordSize > 0);
            $patron->{username} = $self->_getUsername($patron) if ($patronRecordSize > 0);

            push(@patronRecords, $patron) if ($patronRecordSize > 0);

            @patronRecord = (); # clear our patron record
        }

        push(@patronRecord, $line);

    }

    return \@patronRecords;

}

sub savePatronRecords
{
    my $self = shift;
    my $patronRecords = shift;

    for my $patron (@{$patronRecords})
    {

        # TODO: insert $patron into the db
        my $query = "

";

        $self->{db}->update($query);
    }

}

sub _getExternalID
{
    my $self = shift;
    my $patron = shift;

    # Until I get some more info we're counting to 10 and tacking on an epoch
    my $epoch = time();

    return "1234567890_$epoch";

}

sub _getUsername
{
    my $self = shift;
    my $patron = shift;

    # what field do we use for a username?
    # return $patron->{barcode};
    return $patron->{email_address};

}

sub _initPatronHash
{
    my $self = shift;

    my $patron;

    # NON patron file specific fields
    $patron->{'externalID'} = "";
    $patron->{'active'} = "true";
    $patron->{'patronGroup'} = "";
    $patron->{'addressTypeId'} = "";
    $patron->{'cluster'} = "";
    $patron->{'institution'} = "";

    # patron file specific fields
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

    my $patron = $self->_initPatronHash();

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
        $patron->{'patron_expiration_date'} = ($data =~ /^0\d{3}.{2}\d{3}.{7}(.{8}).*/gm)[0] if ($data =~ /^0/);

        # replace spaces with hyphens.
        $data = $data =~ s/\s/-/gr if ($data =~ /^0/ && $self->{conf}->{patronHashReplaceSpaceWithHyphen});

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

    # $self->{log}->addLine(Dumper($patron));

    return $patron;
}

sub _jsonTemplate
{
    my $self = shift;
    my $patron = shift;

    print Dumper($patron);

    my $jsonTemplate = "
{
  \"username\": \"$patron->{username}\",
  \"externalSystemId\": \"$patron->{externalID}\",
  \"barcode\": \"$patron->{barcode}\",
  \"active\": $patron->{active},
  \"patronGroup\": \"$patron->{patronGroup}\",
  \"personal\": {
    \"lastName\": \"$patron->{name}\",
    \"firstName\": \"$patron->{name}\",
    \"phone\": \"$patron->{telephone}\",
    \"addresses\": [
      {
        \"countryId\": \"US\",
        \"addressLine1\": \"$patron->{address}\",
        \"addressTypeId\": \"$patron->{addressTypeId}\",
        \"primaryAddress\": true
      }
    ],
  },
  \"departments\": [
    \"$patron->{department}\",
  ]
}

";

    return $jsonTemplate;

}

sub _mapPatronTypeToPatronGroup
{
    my $self = shift;
    my $patron = shift;

    my $ptypeMappingSheet = $self->{files}->getPTYPEMappingSheet($patron->{cluster});
    my $pType = "NO-DATA-FOUND"; # Should this default to Staff or be blank?

    for my $row (@{$ptypeMappingSheet})
    {

        my $patron_type = $patron->{patron_type} + 0;

        return $row->[3] if ($patron_type == $row->[0]);

    }

    return $pType;

}

1;