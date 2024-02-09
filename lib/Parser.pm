package Parser;

use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';

# https://www.perlmonks.org/?node_id=313810
# we may have to manually import each and every nParser. I couldn't get this to auto require.

use Parsers::GenericParser;

use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {
        'conf'  => shift,
        'log'   => shift,
        'dao'   => shift,
        'files' => shift,
    };
    bless $self, $class;
    return $self;
}

sub stagePatronRecords
{
    my $self = shift;

    my $patronFiles = $self->{files}->getPatronFilePaths();

    # loop over our discovered files.
    for my $patronFile (@{$patronFiles})
    {

        # Read patron file into an array. This needs to go into the parser
        my $data = $self->{files}->readFileToArray($patronFile->{filename});

        # Load our institution to get our parser type
        my $institution = $self->{dao}->getInstitutionMapHashById($patronFile->{institution_id});

        # Get our Parser Modules
        my $module = "GenericParser"; # default to generic
        $module = $institution->{module} if ($institution->{module} ne '' || $institution->{module} ne undef);

        # Build the parser module
        my $parser;
        my $createParser = '$parser = Parsers::' . $institution->{module} . '->new();';
        eval $createParser;

        # $parser->{institution} = $institution;
        # $parser->{file} = $patronFile;

        # Parse these records
        my $patronRecords = $parser->parse($data);


        # We have some patron Records, now what?!? Should probably save them...

    }

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
    my $cluster = shift;
    my $patronType = shift;

    my $ptypeMappingSheet = $self->{files}->getPTYPEMappingSheet($cluster);
    my $pType = "NO-DATA"; # Should this default to Staff or be blank?

    for my $row (@{$ptypeMappingSheet})
    {

        return $pType if ($patronType eq ''); # TODO: What should the default return value be? 'Patron'? currently 'NO-DATA'

        my $patron_type = $patronType + 0;
        return $row->[3] if ($patron_type == $row->[0]);

    }

    return $pType;

}

1;