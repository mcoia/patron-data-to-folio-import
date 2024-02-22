package Parser;

use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';

# https://www.perlmonks.org/?node_id=313810
# we may have to manually import each and every nParser. I couldn't get this to auto require.

use Parsers::GenericParser;
use Parsers::ESID;
use MOBIUS::Utils;

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

        # Get our Parser Module that's stored in the database column 'module' in institution_map
        my $module = "GenericParser"; # default to generic
        $module = $institution->{module} if ($institution->{module} ne '' || $institution->{module} ne undef);

        # Build the parser module.
        my $parser;
        my $createParser = '$parser = Parsers::' . $institution->{module} . '->new();';
        eval $createParser;

        # Parse these records
        my $patronRecords = $parser->parse($patronFile);
        $parser->saveStagedPatronRecords($patronRecords);

        ##########################################################################################
        # This section will eventually get moved to the extended parser code i.e. Generic parser #
        ##########################################################################################
        $patronFileIndex++;
        my $totalFileRecords = @{$patronRecords};
        $totalPatronRecords += $totalFileRecords;
        print "[$patronFileIndex] saving records... total:$totalFileRecords [$institution->{institution}]:[$institution->{module}]:[$patronFile->{filename}]\n";

        # Now save these patrons to the staging table
        # $main::dao->saveStagedPatronRecords($patronRecords);
        ##########################################################################################
        # This section will eventually get moved to the extended parser code i.e. Generic parser #
        ##########################################################################################

    }

    print "Total patron records:[$totalPatronRecords] done staging patrons... \n";

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
    # Note: I'm coding to get this done now. 02-22-24.
    # I've been working on this and I still haven't sent any POST request.

    # Inserts vs Updates
    # We'll use the username as our key. That's what needs to be 100% unique across the consortium.
    # The esid is unique to the tenant so this is redundant to key off it as well.

    # query each stage_patron, look up their info in the final patron table using the username.
    # If that username doesn't exists we're an insert.
    # If that username exists we're an update.

    # we're using the unique_id as the username as SSO uses the esid for login.
    # The users will never use the username to login anyways.

    my $maxStagePatronID = $main::dao->getMaxStagePatronID();

    my $chunkSize = $main::conf->{migrateChunkSize};

    my $start = 0;
    my $stop = $chunkSize;

    my $iterationsNeeded = $maxStagePatronID / $chunkSize;

    # We chunk up this query
    for my $index (0 .. $iterationsNeeded)
    {
        # get some records
        my $chunkedStagedPatrons = $main::dao->getStagedPatrons($start, $stop);

        for my $patron (@{$chunkedStagedPatrons})
        {

            # Insert or Update?
            my $stagedPatron = $main::dao->getPatronByUsername($patron->{unique_id});
            my $stagedPatronSize = @{$stagedPatron};

            # Insert
            $main::dao->insertPatron($patron) if ($stagedPatronSize == 0);

            #Update
            $main::dao->updatePatron($patron, $stagedPatron) if ($stagedPatronSize > 0);

        }

        # increment our chunk sizes. Does postgres have built in pagination?
        # It does! This works but it could be a little cleaner. i = i + $chunkSize and then offset $i
        # https://medium.com/@jaumepuigturon4/a-step-by-step-guide-to-implementing-pagination-in-postgresql-aeb8d12cacc#:~:text=The%20LIMIT%20and%20OFFSET%20clauses%20in%20PostgreSQL%20are%20used%20to,starting%20to%20return%20the%20records.
        $start += $chunkSize;
        $stop += $chunkSize;

    }

}

sub getPatronFingerPrint
{
    # On the off chance this getHash() function doesn't work as expected we
    # can just update this method to point to something else.

    my $self = shift;
    my $patron = shift;

    my $utils = MOBIUS::Utils->new();
    return $utils->getHash($patron);

}

1;