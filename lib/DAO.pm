package DAO;
use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';
use MOBIUS::DBhandler;
use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {
        'db' => 0,
    };
    $self = init($self);
    bless $self, $class;
    return $self;
}

sub init
{
    my $self = shift;

    $self = initDatabaseConnection($self);
    initDatabaseSchema($self);

    return $self;

}

sub initDatabaseConnection
{
    my $self = shift;
    eval {$self->{db} = DBhandler->new($main::conf->{db}, $main::conf->{dbhost}, $main::conf->{dbuser}, $main::conf->{dbpass}, $main::conf->{port} || 5432, "postgres", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n";
        exit 1;
    }

    return $self;
}

sub initDatabaseSchema
{
    my $self = shift;

    my $filePath = $main::conf->{sqlFilePath};

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";

    my $query = "";
    while (my $line = <$fileHandle>)
    {$query = $query . $line;}
    close $fileHandle;
    $self->{db}->update($query);

}

sub checkDatabaseStatus
{
    my $self = shift;
=head1 checkDatabaseStatus()

Here is where we can populate the db with mapping tables and such that we might need.
It started with the institution_map table but I see other csv's needing to be loaded.

Note: program exists if it can't establish a database connection. We have to have a connection
to even reach this point.

=cut

    # Check our institution map
    my $tableSize = $self->getInstitutionMapTableSize();
    $self->buildInstitutionMapTableData() if ($tableSize == 0);

}

sub getStagedPatrons
{
    my $self = shift;

    my @tableColumns = @{_getTableColumns("stage_patron")};
    my $totalColumns = @tableColumns;
    my $columns = "@tableColumns";
    $columns =~ s/\s/,/g;

    my $query = "select id,$columns from public.stage_patron";
    my $patrons = $self->{dao}->{db}->query($query);

    my @patronArray = ();

    # I want this as an array of hashes, not arrays
    for my $stagedPatron (@{$patrons})
    {

        my $patron = {};
        for my $i (0 .. $totalColumns)
        {
            $patron->{$tableColumns[$i]} = $stagedPatron->[$i];
        }


        # my $patron = {
        #     'id'                     => $stagedPatron->[0],
        #     'job_id'                 => $stagedPatron->[1],
        #     'cluster'                => $stagedPatron->[2],
        #     'institution'            => $stagedPatron->[3],
        #     'file'                   => $stagedPatron->[4],
        #     'field_code'             => $stagedPatron->[5],
        #     'patron_type'            => $stagedPatron->[6],
        #     'pcode1'                 => $stagedPatron->[7],
        #     'pcode2'                 => $stagedPatron->[8],
        #     'pcode3'                 => $stagedPatron->[9],
        #     'home_library'           => $stagedPatron->[10],
        #     'patron_message_code'    => $stagedPatron->[11],
        #     'patron_block_code'      => $stagedPatron->[12],
        #     'patron_expiration_date' => $stagedPatron->[13],
        #     'name'                   => $stagedPatron->[14],
        #     'address'                => $stagedPatron->[15],
        #     'telephone'              => $stagedPatron->[16],
        #     'address2'               => $stagedPatron->[17],
        #     'telephone2'             => $stagedPatron->[18],
        #     'department'             => $stagedPatron->[19],
        #     'unique_id'              => $stagedPatron->[20],
        #     'barcode'                => $stagedPatron->[21],
        #     'email_address'          => $stagedPatron->[22],
        #     'note'                   => $stagedPatron->[23]
        # };

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

        my $debugger;

        # This is the way I order the hash. It has to match the order of the stage_patron table.
        my @data = (
            $patron->{job_id},
            $patron->{institution_id},
            $patron->{file_id},
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
        $self->_insertIntoTable("stage_patron", \@data);
    }
}

sub savePatronRecords
{
    my $self = shift;
    my $patronRecords = shift;
    my $tableName = "stage_patron";

    for my $patron (@{$patronRecords})
    {

        # This is to enforce the order. I know there's a better way. Get the column names, loop thru the hash and generate a new array of values.
        # Then I could put that in a function so I could save a hash too! _insertIntoTableByHash() which is a wrapper converts the hash to array then calls _insertIntoTable()
        my @data = (
            $main::conf->{jobID},
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

        $self->_insertIntoTable($tableName, \@data);

    }

}

sub _insertIntoTable
{
    my $self = shift;
    my $tableName = shift;
    my $data = shift;

    # get our column names as a string of comma seperated values
    my @columnNames = @{$self->_getTableColumnsWithoutId($tableName)};
    my $columns = "@columnNames";
    $columns =~ s/\s/,/g;

    # build our $1,$2 ect... string
    my $dataString = "";
    my $totalColumns = @columnNames;

    for my $index (1 .. $totalColumns)
    {$dataString = $dataString . "\$$index,";}
    chop($dataString);

    # taking advantage of perls natural templating
    my $query = "INSERT INTO $tableName($columns) VALUES($dataString);";
    $main::log->addLine($query);

    eval {$self->{'db'}->updateWithParameters($query, $data);};

}

sub _getTableColumnsWithoutId
{
    my $self = shift;
    my $tableName = shift;

    my $query = "
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = '$tableName'
          AND column_name != 'id'
        order by ordinal_position asc
                ";

    return $self->_getQueryAsSingleStringArray($query);
}

sub _getTableColumns
{
    my $self = shift;
    my $tableName = shift;

    # Blakes right, this should be cached.
    # Some if statements checking for the existence of the array stored in $self

    my $query = "
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = '$tableName'
        order by ordinal_position asc
                ";

    return $self->_getQueryAsSingleStringArray($query);

}

sub _getQueryAsSingleStringArray
{
    my $self = shift;
    my $query = shift;

    my $results = $self->{db}->query($query);

    my @names = ();
    push(@names, $_->[0]) for (@{$results});

    return \@names;

}

sub _getDatabaseTableNames
{
    my $self = shift;
    my $query = "select table_name from information_schema.tables where table_schema = 'public'";
    return $self->_getQueryAsSingleStringArray($query);
}

sub _selectAllFromTable
{
    my $self = shift;
    my $tableName = shift;

    my $columns = $self->_convertArrayToCSVString($self->_getTableColumns($tableName));

    my $query = "select $columns from $tableName;";
    return $self->{db}->query($query);

}

sub _getCurrentTimestamp
{

    my $self = shift;

    # I straight up stole this from stack overflow. Made some edits. It's mines now.
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    return sprintf("%04d%02d%02d %02d:%02d:%02d",
        $year + 1900, $mon + 1, $mday, $hour, $min, $sec);

}

sub _getInstitutionMapFromDatabaseAsHashArray
{
    my $self = shift;

    my $tableName = "institution_map";
    return $self->_convertQueryResultsToHash($tableName, $self->_selectAllFromTable($tableName));

}

sub _convertQueryResultsToHash
{
    my $self = shift;
    my $tableName = shift;
    my $data = shift;

    my @columns = @{$self->_getTableColumns($tableName)};
    my @hashArray = ();

    for my $row (@{$data})
    {

        my $hash = {};
        my $index = 0;
        for my $cell (@{$row})
        {
            $hash->{$columns[$index]} = $cell;
            $index++;
        }

        push(@hashArray, $hash);

    }

    return \@hashArray;

}

sub _convertArrayToCSVString
{
    my $self = shift;
    my $data = shift;

    my @array = @{$data};
    my $csv = "@array";
    $csv =~ s/\s/,/g;

    return $csv;
}

sub getInstitutionMapHashById
{
    my $self = shift;
    my $id = shift;

    my $tableName = "institution_map";
    my $columns = $self->_convertArrayToCSVString($self->_getTableColumns($tableName));
    my $query = "select $columns from $tableName t where t.id=$id;";
    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query))->[0];

}

sub getInstitutionMapHashByName
{
    my $self = shift;
    my $name = shift;
    my $tableName = "institution_map";

    my $columns = $self->_convertArrayToCSVString($self->_getTableColumns($tableName));
    my $query = "select $columns from $tableName t where t.institution='$name';";

    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query))->[0];

}

sub getLastFileTrackerEntryByFilename
{
    my $self = shift;
    my $fileName = shift;

    my $tableName = "file_tracker";
    my $columns = $self->_convertArrayToCSVString($self->_getTableColumns($tableName));

    my $query = "select $columns from file_tracker where filename = '$fileName' order by id desc limit 1";
    print "\n" . $query . "\n";
    my $results = $self->{db}->query($query);
    return $results;

}

sub getLastFileTrackerEntry
{
    my $self = shift;

    my $tableName = "file_tracker";
    my $columns = $self->_convertArrayToCSVString($self->_getTableColumns($tableName));

    my $query = "select $columns from file_tracker order by id desc limit 1";
    my $results = $self->{db}->query($query);
    return $results;

}

sub getLastJobID
{
    my $self = shift;

    # Get the ID of the last job
    my $query = "select id from job order by ID desc limit 1;";
    return $self->{db}->query($query)->[0]->[0];

}

sub getInstitutionMapTableSize
{
    my $self = shift;

    my $query = "select count(id) from institution_map;";
    return $self->{db}->query($query)->[0]->[0] + 0;

}

sub buildInstitutionMapTableData
{
    my $self = shift;


    # id
    # cluster
    # institution
    # folder_path
    # file
    # file_pattern
    # module

    # 'cluster' => 'archway',
    # 'institution' => 'East Central College',
    # 'file' => 'eccpat.txt',
    # 'pattern' => 'eccpat'

    my $institutions = $main::files->_loadMOBIUSPatronLoadsCSV();
    $institutions = $main::files->_buildFilePatterns($institutions);
    $institutions = $main::files->_buildFolderPaths($institutions);

    for my $institution (@{$institutions})
    {

        my @data = (
            "$institution->{cluster}",
            "$institution->{institution}",
            "$institution->{folder_path}",
            "$institution->{file}",
            "$institution->{pattern}",
            "GenericParser"
        );

        $self->_insertIntoTable("institution_map", \@data);

    }

}

1;