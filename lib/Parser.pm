package Parser;

use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';
use Time::HiRes qw(time);

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

    # average function call time: 60.3ms 1000 times ran
    my $institutions = $main::dao->getInstitutionsFoldersAndFilesHash();

    # loop over our discovered files.
    for my $institution (@{$institutions})
    {

        # Gives us the ability to skip certain institutions if needed.
        next if (!$institution->{enabled});

        # Get our Parser Module that's stored in the database column 'module' in the institution table
        my $module = "GenericParser"; # default to generic
        $module = $institution->{module} if ($institution->{module} ne '' || $institution->{module} ne undef);

        # Build the parser module.
        my $parser;
        my $createParser = '$parser = Parsers::' . $institution->{module} . '->new();';
        eval $createParser;

        # Parser Not working? Don't forget to load it! use Parsers::ParserNameHere;

        print "Searching for files...\n";
        $main::log->addLine("Searching for files...\n");
        print "$institution->{name}: $institution->{folder}->{path}\n";
        $main::log->addLine("$institution->{name}: $institution->{folder}->{path}\n");

        # We need the files associated with this institution.
        $main::files->patronFileDiscovery($institution);

        # The $institution now contains the files needed for parsing. Thanks patronFileDiscovery!
        # Parse the file records
        my $patronRecords = $parser->parse($institution);

        # TODO: UNCOMMENT THIS!!! DEV TESTING File Discovery
        # $parser->saveStagedPatronRecords($patronRecords);

        my $totalPatrons = scalar(@{$patronRecords});

        print "Total Patrons: [$totalPatrons]\n";
        $main::log->addLine("Total Patrons: [$totalPatrons]\n");
        print "================================================================================\n\n";
        $main::log->addLine("================================================================================\n\n");

    }

}

sub saveStagedPatronRecords
{
    # this function is a mess. I hate it. I hate it so much that I don't even want to rework it.

    my $self = shift;
    my $patronRecordsHashArray = shift;
    my $chunkSize = shift || 500;

    # $patronRecords is a hash of arrays. We need to convert the hash into an ordered array.
    my @columns = @{$main::dao->{'cache'}->{'columns'}->{'stage_patron'}};
    shift @columns if ($columns[0] eq 'id');

    my $col = $main::dao->_convertColumnArrayToCSVString(\@columns);
    my $totalColumns = @columns;

    # this is a map! 1 liner I know it! If not, it should be a function
    my @patronRecords = ();
    for my $patronHash (@{$patronRecordsHashArray})
    {
        my @patron = ();
        for my $column (@columns)
        {
            push(@patron, $patronHash->{$column});
        }
        push(@patronRecords, \@patron);
    }

    my $totalRecords = scalar(@patronRecords);
    my @chunkedRecords = ();
    while (@patronRecords)
    {
        my @chunkyPatrons = ($totalRecords >= $chunkSize) ? @patronRecords[0 .. $chunkSize - 1] : @patronRecords[0 .. $totalRecords - 1];
        push(@chunkedRecords, \@chunkyPatrons);
        shift @patronRecords for (0 .. $chunkSize - 1); # <== does this get a - 1 too?
        $totalRecords = @patronRecords;
    }

    for my $chunkedRecord (@chunkedRecords)
    {

        $totalRecords = @{$chunkedRecord};
        my $sqlValues = $self->_buildParameters($totalColumns, $totalRecords);
        my $query = "INSERT INTO patron_import.stage_patron ($col) values $sqlValues";

        # This data has to be in 1 array a mile long.
        my @combinedChunkedRecords = ();
        for my $recordItem (@{$chunkedRecord})
        {
            push(@combinedChunkedRecords, $_) for (@{$recordItem});
        }

        $main::dao->{db}->updateWithParameters($query, \@combinedChunkedRecords);

    }

}

sub _buildParameters
{

    my $self = shift;
    my $totalColumns = shift;
    my $arraySize = shift;

    my $p = "";
    my $index = 1;
    for (1 .. $arraySize)
    {

        $p .= "(";
        for (1 .. $totalColumns)
        {
            $p .= "\$$index,";
            $index++;
        }
        chop($p);
        $p .= "),";
    }

    chop($p);
    return $p;
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