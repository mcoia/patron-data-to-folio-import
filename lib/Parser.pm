package Parser;

use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';

use Data::Dumper;

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

sub stagePatronRecords
{
    my $self = shift;

    my $patronFiles = $self->{files}->getPatronFilePaths();

    # loop over our discovered files.
    for my $patronFile (@$patronFiles)
    {

        # Note: $patronFile is a hash vvvvvv not an array. I keep thinking this is a nested array at first glance. It's not.
        for my $file (@{$patronFile->{files}})
        {

            # Read patron file into an array
            my $data = $self->{files}->readFileToArray($file);

            # Parse our data into patron records
            # my $patronRecords = $self->parse($file, $patronFile->{cluster}, $patronFile->{institution}, $data);
            my $patronRecords = $self->parse($patronFile->{institution}, $data);
            $self->saveStagedPatronRecords($patronRecords);

        }

    }

}

sub parse
{

    my $self = shift;
    my $institution = shift;
    my $data = shift;

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

            push(@patronRecords, $patron) if ($patronRecordSize > 0);

            @patronRecord = (); # clear our patron record
        }

        push(@patronRecord, $line);

    }

    return \@patronRecords;

}

sub getParserObject
{
    my $self = shift;
    my $institution = shift;
    my $patronRecord = shift;

    # I don't want to edit this portion in the future.
    # db table parser_modules
    my $query = "select module from parser_modules where institution = '$institution';";

    my $module = @{$self->{db}->query($query)}[0];

    print "module: [$module]\n";




    # We return the generic one if we don't find anything.
    return Parsers::GenericParser::parse($patronRecord);

}

sub stagePatronRecords_old
{
    my $self = shift;

    my $patronFiles = $self->{files}->getPatronFilePaths();

    # loop over our discovered files.
    for my $patronFile (@$patronFiles)
    {

        # Note: $patronFile is a hash vvvvvv not an array. I keep thinking this is a nested array at first glance. It's not.
        for my $file (@{$patronFile->{files}})
        {

            # Read patron file into an array
            my $data = $self->{files}->readFileToArray($file);

            # Parse our data into patron records
            my $patronRecords = $self->parse($file, $patronFile->{cluster}, $patronFile->{institution}, $data);
            $self->saveStagedPatronRecords($patronRecords);

        }

    }

}

sub getStagedPatrons
{
    my $self = shift;

    my $query = "select id,job_id,cluster,institution,file,field_code,patron_type,pcode1,pcode2,pcode3,home_library,patron_message_code,patron_block_code,patron_expiration_date,name,address,telephone,address2,telephone2,department,unique_id,barcode,email_address,note from public.stage_patron";
    my $patrons = $self->{db}->query($query);

    my @patronArray = ();

    # I want this an array of hashes, not arrays  
    for my $stagedPatron (@{$patrons})
    {

        my $patron = {
            'id'                     => $stagedPatron->[0],
            'job_id'                 => $stagedPatron->[1],
            'cluster'                => $stagedPatron->[2],
            'institution'            => $stagedPatron->[3],
            'file'                   => $stagedPatron->[4],
            'field_code'             => $stagedPatron->[5],
            'patron_type'            => $stagedPatron->[6],
            'pcode1'                 => $stagedPatron->[7],
            'pcode2'                 => $stagedPatron->[8],
            'pcode3'                 => $stagedPatron->[9],
            'home_library'           => $stagedPatron->[10],
            'patron_message_code'    => $stagedPatron->[11],
            'patron_block_code'      => $stagedPatron->[12],
            'patron_expiration_date' => $stagedPatron->[13],
            'name'                   => $stagedPatron->[14],
            'address'                => $stagedPatron->[15],
            'telephone'              => $stagedPatron->[16],
            'address2'               => $stagedPatron->[17],
            'telephone2'             => $stagedPatron->[18],
            'department'             => $stagedPatron->[19],
            'unique_id'              => $stagedPatron->[20],
            'barcode'                => $stagedPatron->[21],
            'email_address'          => $stagedPatron->[22],
            'note'                   => $stagedPatron->[23]
        };

        push(@patronArray, $patron);

    }

    return \@patronArray;

}

sub saveStagedPatronRecords
{
    my $self = shift;
    my $patronRecords = shift;

    for my $patron (@{$patronRecords})
    {

        my $query = '
            insert into
            stage_patron(
            job_id,
            cluster,
            institution,
            file,
            field_code,
            patron_type,
            pcode1,
            pcode2,
            pcode3,
            home_library,
            patron_message_code,
            patron_block_code,
            patron_expiration_date,
            name,
            address,
            telephone,
            address2,
            telephone2,
            department,
            unique_id,
            barcode,
            email_address,
            note
            )
            values(
            $1,
            $2,
            $3,
            $4,
            $5,
            $6,
            $7,
            $8,
            $9,
            $10,
            $11,
            $12,
            $13,
            $14,
            $15,
            $16,
            $17,
            $18,
            $19,
            $20,
            $21,
            $22,
            $23)
        ';

        my @data = (
            $self->{conf}->{jobID},
            $patron->{cluster},
            $patron->{institution},
            $patron->{file},
            $patron->{field_code},
            $patron->{patron_type},
            $patron->{pcode1},
            $patron->{pcode2},
            $patron->{pcode3},
            $patron->{home_library},
            $patron->{patron_message_code},
            $patron->{patron_block_code},
            $patron->{patron_expiration_date},
            $patron->{name},
            $patron->{address},
            $patron->{telephone},
            $patron->{address2},
            $patron->{telephone2},
            $patron->{department},
            $patron->{unique_id},
            $patron->{barcode},
            $patron->{email_address},
            $patron->{note}
        );

        $self->{db}->updateWithParameters($query, \@data);

    }
}

sub savePatronRecords
{
    my $self = shift;
    my $patronRecords = shift;

    for my $patron (@{$patronRecords})
    {

        my $query = '
            insert into
            patron(
            job_id,
            externalID,
            active,
            username,
            patronGroup,
            cluster,
            institution,
            field_code,
            patron_type,
            pcode1,
            pcode2,
            pcode3,
            home_library,
            patron_message_code,
            patron_block_code,
            patron_expiration_date,
            name,
            address,
            telephone,
            address2,
            telephone2,
            department,
            unique_id,
            barcode,
            email_address,
            note,
            _firstname,
            _middlename,
            _lastname,
            _street,
            _city,
            _state,
            _zip,
            file)
            values(
            $1,
            $2,
            $3,
            $4,
            $5,
            $6,
            $7,
            $8,
            $9,
            $10,
            $11,
            $12,
            $13,
            $14,
            $15,
            $16,
            $17,
            $18,
            $19,
            $20,
            $21,
            $22,
            $23,
            $24,
            $25,
            $26,
            $27,
            $28,
            $29,
            $30,
            $31,
            $32,
            $33,
            $34)
';

        my @data = (
            $self->{conf}->{jobID},
            $patron->{externalID},
            $patron->{active},
            $patron->{username},
            $patron->{patronGroup},
            $patron->{cluster},
            $patron->{institution},
            $patron->{field_code},
            $patron->{patron_type},
            $patron->{pcode1},
            $patron->{pcode2},
            $patron->{pcode3},
            $patron->{home_library},
            $patron->{patron_message_code},
            $patron->{patron_block_code},
            $patron->{patron_expiration_date},
            $patron->{name},
            $patron->{address},
            $patron->{telephone},
            $patron->{address2},
            $patron->{telephone2},
            $patron->{department},
            $patron->{unique_id},
            $patron->{barcode},
            $patron->{email_address},
            $patron->{note},
            $patron->{firstName},
            $patron->{middleName},
            $patron->{lastName},
            $patron->{street},
            $patron->{city},
            $patron->{state},
            $patron->{zip},
            $patron->{file}
        );

        $self->{db}->updateWithParameters($query, \@data);

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
    $patron->{'firstName'} = "";
    $patron->{'middleName'} = "";
    $patron->{'lastName'} = "";
    $patron->{'street'} = "";
    $patron->{'city'} = "";
    $patron->{'state'} = "";
    $patron->{'zip'} = "";

    $patron->{'file'} = "";

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
    my $pType = "NO-DATA"; # Should this default to Staff or be blank?

    for my $row (@{$ptypeMappingSheet})
    {

        return $pType if ($patron->{patron_type} eq ''); # TODO: What should the default return value be? 'Patron'? currently 'NO-DATA'

        my $patron_type = $patron->{patron_type} + 0;
        return $row->[3] if ($patron_type == $row->[0]);

    }

    return $pType;

}

1;