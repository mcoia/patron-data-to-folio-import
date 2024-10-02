package Parser;

use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';
use Time::HiRes qw(time);
use List::Util qw(any);

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

    # this is an array of institutions
    my $institutions = shift;

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

        print "Searching for files...\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("Searching for files...\n");


        # The $institution now contains the files needed for parsing. Thanks patronFileDiscovery!
        # We still need to skip the files in our buildDropboxFolderStructureByInstitutionId
        $main::files->patronFileDiscovery($institution);

        my $dropboxFolder = $main::files->buildDropboxFolderByInstitutionId($institution->{id});

        # We push everything into the institution->folder and then iterate thru removing duplicates.
        push(@{$institution->{folders}}, $dropboxFolder);
        $self->removeDuplicatePaths($institution);

        # Parse the file records
        my $patronRecords = $parser->parse($institution);

        # Save these records to the database
        $parser->saveStagedPatronRecords($patronRecords);

        # some debug metrics
        my $totalPatrons = scalar(@{$patronRecords});
        print "Total Patrons: [$totalPatrons]\n" if ($main::conf->{print2Console} eq 'true');
        print "Migrating records to final table...\n" if ($main::conf->{print2Console} eq 'true');
        print "================================================================================\n\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("Total Patrons: [$totalPatrons]\n");
        $main::log->addLine("================================================================================\n\n");

        # We migrate records here, truncating the table after each loop
        $self->migrate();

        # I've went a few rounds with this. This is where the delete patron file should go.
        # I was going to delete them all at once but what if we crash on a patron file for some reason?
        # Files won't get deleted. If we crash on a file, I want all previous files to have been removed.
        $self->deletePatronFiles($institution) if ($main::conf->{deleteFiles} eq 'true');

    }

    return $self;
}

sub removeDuplicatePaths
{
    my $self = shift;
    my $institution = shift;

    my %allUniquePaths;

    foreach my $folder (@{$institution->{folders}})
    {
        foreach my $file (@{$folder->{files}})
        {
            my @uniqueFilePaths;
            foreach my $path (@{$file->{paths}})
            {
                unless (exists $allUniquePaths{$path})
                {
                    $allUniquePaths{$path} = 1;
                    push @uniqueFilePaths, $path;
                }
            }
            $file->{paths} = \@uniqueFilePaths;
        }
    }
}

sub deletePatronFiles
{
    my $self = shift;
    my $institution = shift;

    for my $folder (@{$institution->{folders}})
    {
        for my $file (@{$folder->{files}})
        {
            for my $filePath (@{$file->{paths}})
            {

                print "deleting file: [$filePath]\n" if ($main::conf->{print2Console} eq 'true');
                $main::log->addLine("deleting file: [$filePath]");

                unlink $filePath;

            }

        }
    }

    return $self;

}

sub saveStagedPatronRecords
{

    my $self = shift;
    my $patronRecordsHashArray = shift;
    my $chunkSize = shift || 100;

    # $patronRecords is a hash of arrays. We need to convert the hash into an ordered array.
    my @columns = @{$main::dao->{'cache'}->{'columns'}->{'stage_patron'}};
    shift @columns if ($columns[0] eq 'id');

    my $col = $main::dao->_convertColumnArrayToCSVString(\@columns);
    my $totalColumns = @columns;

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

    return $self;

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

    my $query = $main::files->readFileAsString($main::conf->{projectPath} . "/resources/sql/migrate.sql");
    $main::dao->query($query);

    # check the size of stage_patron
    if ($main::dao->getStagePatronCount() > 0)
    {

        $main::log->addLine("Something went wrong! We did not truncate the stage_patron table.");

        # Send me an email. Bug... This isn't right
        # my $email = MOBIUS::Email->new($main::conf->{fromAddress}, [ $main::conf->{programFailEmailTo} ], 0, 0);
        # $email->send("patron-load HALT!", "We failed!!!!");
        exit;
    }

}

1;