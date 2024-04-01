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

        # Save these records to the database
        $parser->saveStagedPatronRecords($patronRecords);

        # some debug metrics
        my $totalPatrons = scalar(@{$patronRecords});
        print "Total Patrons: [$totalPatrons]\n";
        print "================================================================================\n\n";
        $main::log->addLine("Total Patrons: [$totalPatrons]\n");
        $main::log->addLine("================================================================================\n\n");

        # New plan, we migrate records here, truncating the table after each loop
        $parser->migrate();

    }

}

sub checkFileReady
{
    my $self = shift;
    my $file = shift;
    my @stat = stat $file;
    my $baseline = $stat[7];
    $baseline += 0;
    my $now = -1;
    while ($now != $baseline)
    {
        @stat = stat $file;
        $now = $stat[7];
        sleep 1;
        @stat = stat $file;
        $baseline = $stat[7];
        $baseline += 0;
        $now += 0;
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
        {push(@combinedChunkedRecords, $_) for (@{$recordItem});}

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

sub getPatronFingerPrint
{
    # On the off chance this getHash() function doesn't work as expected we
    # can just update this method to point to something else.

    my $self = shift;
    my $patron = shift;

    my $utils = MOBIUS::Utils->new();
    return $utils->getHash($patron);

}

sub notifyDuplicateUniqueID
{
    my $self = shift;
    my $duplicateUniqueIDPatrons = shift;

    # Not sure what we'll do if we ever hit this.
    $main::log->addLine("\n\n################################################################################\n");
    $main::log->addLine("duplicate unique_id found");
    $main::log->addLine(Dumper($duplicateUniqueIDPatrons));
    $main::log->addLine("\n################################################################################\n\n");

}

1;