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
    my $self = {};
    bless $self, $class;
    return $self;
}

sub stagePatronRecords
{
    my $self = shift;

    my $patronFiles = $main::files->getPatronFilePaths();

    my $totalPatronFiles = @{$patronFiles};
    my $patronFileIndex = 0;
    my $totalPatronRecords = 0;
    print "Total Files Found: [$totalPatronFiles]\n";

    # loop over our discovered files.
    for my $patronFile (@{$patronFiles})
    {

        # Load our institution to get our parser type
        my $institution = $main::dao->getInstitutionMapHashById($patronFile->{institution_id});

        # Get our Parser Modules
        my $module = "GenericParser"; # default to generic
        $module = $institution->{module} if ($institution->{module} ne '' || $institution->{module} ne undef);

        # Build the parser module
        my $parser;
        my $createParser = '$parser = Parsers::' . $institution->{module} . '->new();';
        eval $createParser;

        # Parse these records
        my $patronRecords = $parser->parse($patronFile);

        $patronFileIndex++;
        my $totalFileRecords = @{$patronRecords};
        $totalPatronRecords = $totalPatronRecords + $totalFileRecords;
        print "[$patronFileIndex] saving records... total:$totalFileRecords [$institution->{institution}]:[$institution->{module}]:[$patronFile->{filename}]\n";

        # Now save these patrons to the staging table
        $main::dao->saveStagedPatronRecords($patronRecords);

    }


    print "done staging patrons... Total patron records:[$totalPatronRecords]\n";



}

sub _initPatronHash
{
    my $self = shift;

    my $patron;

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
    my $institution = shift;
    my $patronType = shift;

    # this is wrong now. We put this in the db.
    my $ptypeMappingSheet = $main::files->getPTYPEMappingSheet();

    my $pType = "NO-DATA"; # Should this default to Staff or be blank?

    for my $row (@{$ptypeMappingSheet})
    {

        return $pType if ($patronType eq ''); # TODO: What should the default return value be? 'Patron'? currently 'NO-DATA'

        my $patron_type = $patronType + 0;
        return $row->[3] if ($patron_type == $row->[0]);

    }

    return $pType;

}

sub migrate
{
    my $self = shift;
=pod


Ah gezz... where do we start?
Our staging table
id
job_id
institution_id
file_id
field_code
patron_type
pcode1
pcode2
pcode3
home_library
patron_message_code
patron_block_code
patron_expiration_date
name
address
telephone
address2
telephone2
department
unique_id
barcode
email_address
note

The main idea is that we take the stage_patron and move those fields into the final patron table


select $cols from stage_patron limit 1000;



=cut


}

1;