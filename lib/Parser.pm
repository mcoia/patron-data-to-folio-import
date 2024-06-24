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

        print "Searching for files...\n" if($main::conf->{print2Console});
        $main::log->addLine("Searching for files...\n");
        print "$institution->{name}: $institution->{folder}->{path}\n" if($main::conf->{print2Console});
        $main::log->addLine("$institution->{name}: $institution->{folder}->{path}\n");

        # We need the files associated with this institution. I feel this should return $institution.
        $main::files->patronFileDiscovery($institution);

        # The $institution now contains the files needed for parsing. Thanks patronFileDiscovery!
        # Parse the file records
        my $patronRecords = $parser->parse($institution);

        # Save these records to the database
        $parser->saveStagedPatronRecords($patronRecords);

        # some debug metrics
        my $totalPatrons = scalar(@{$patronRecords});
        print "Total Patrons: [$totalPatrons]\n" if($main::conf->{print2Console});
        print "Migrating records to final table...\n" if($main::conf->{print2Console});
        print "================================================================================\n\n" if($main::conf->{print2Console});
        $main::log->addLine("Total Patrons: [$totalPatrons]\n");
        $main::log->addLine("================================================================================\n\n");

        # We migrate records here, truncating the table after each loop
        $parser->migrate();

    }

    return $self;
}

sub saveStagedPatronRecords
{
    # this function is a mess. I hate it. I hate it so much. It works so I don't even want to rework it. Gross.

    my $self = shift;
    my $patronRecordsHashArray = shift;
    my $chunkSize = shift || 500;

    # $patronRecords is a hash of arrays. We need to convert the hash into an ordered array.
    my @columns = @{$main::dao->{'cache'}->{'columns'}->{'stage_patron'}};
    shift @columns if ($columns[0] eq 'id');

    my $col = $main::dao->_convertColumnArrayToCSVString(\@columns);
    my $totalColumns = @columns;

    # my @patronRecords = map { [ map { $_->{$_} } @columns ] } @{$patronRecordsHashArray};
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
        shift @patronRecords for (0 .. $chunkSize - 1);
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

sub getPatronFingerPrint
{
    # On the off chance this getHash() function doesn't work as expected we
    # can just update this method to point to something else.

    my $self = shift;
    my $patron = shift;
    return MOBIUS::Utils->new()->getHash($patron);

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

sub migrate
{
    my $self = shift;

    # Inserts vs Updates
    # We'll use the username as our key. That's what needs to be 100% unique across the consortium.
    # The esid is unique to the tenant so this is redundant to key off it as well.

    # query each stage_patron, look up their info in the final patron table using the username.
    # If that username doesn't exists we're an insert.
    # If that username exists we're an update.

    # we're using the unique_id as the username as SSO uses the esid for login.
    # The users will never use the username to login anyways.

    # we're not finding the filename!
    my $query = $main::files->readFileAsString($main::conf->{projectPath} . "/resources/sql/migrate.sql");
    $main::dao->query($query);

    # check the size of stage_patron
    if ($main::dao->getStagePatronCount() > 0){
        $main::log->addLine("Something went wrong! We did not truncate the stage_patron table.");
    }


}


1;