package DAO;
use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';
use MOBIUS::DBhandler;
use Data::Dumper;

# todo: DAO todo list
=pod

[]: write test for every method in this class. This is kind of done in testDatabase.
[]: finish writing cache methods

=cut

my $schema;

sub new
{
    my $class = shift;
    my $self = {
        'db'    => 0,
        'cache' => {},
    };
    $self = init($self);
    bless $self, $class;
    return $self;
}

sub init
{
    my $self = shift;
    $schema = $main::conf->{schema};
    print "using schema: [$schema]\n";

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

This is where we populate the db with mapping tables and such that we might need.
It started with the institution_map table but I see other csv's needing to be loaded.

Note: program exists if it can't establish a database connection. We have to have a connection
to even reach this point.

=cut

    # I may just dump the key components of the db to an import file.
    # I don't want to manually code this sql stuff. It's taking too long.

    # init our cache
    $self->_initDatabaseCache();


    # Check our institution map
    my $institutionMapTableSize = $self->getTableSize("institution_map");
    $self->buildInstitutionMapTableData() if ($institutionMapTableSize == 0);

    my $ptypeMappingTableSize = $self->getTableSize("ptype_mapping");
    $self->buildPTypeMappingTableData() if ($ptypeMappingTableSize == 0);

}

sub _initDatabaseCache
{
    my $self = shift;

    # A kind of registry for all database cache objects
    $self->_initDatabaseCacheTableColumns();

    # This is some idea's for future caching
    # $self->_initDatabaseCacheInstitution_map();
    # $self->_initDatabaseCachePtype_mapping();

}

sub _initDatabaseCacheTableColumns
{
    my $self = shift;
    # I'm not sure how far this rabbit hole can go. I may start caching other data too.
    # I'm putting this in $self->{cache}->{table}->{columns} = () array

    my $query = "select t.table_name, c.column_name,c.ordinal_position from information_schema.tables t
                join information_schema.columns c on(t.table_name = c.table_name)
                where t.table_schema='patron_import'
                group by t.table_name, c.ordinal_position, c.column_name;";

    my $results = $self->query($query);
    my $tableName = "";
    my @columns = ();

    for my $row (@{$results})
    {

        if ($tableName ne $row->[0])
        {

            # Set the cache
            if (@columns)
            {
                my @columnCopy = @columns;
                $self->{'cache'}->{$tableName}->{'columns'} = \@columnCopy;
            }

            # Reset
            $tableName = $row->[0];
            @columns = ();
        }

        push(@columns, $row->[1]);

    }

    # Set it again for the last set of columns
    if (@columns)
    {
        my @columnCopy = @columns;
        $self->{'cache'}->{$tableName}->{'columns'} = \@columnCopy;
    }

}

sub resetStagePatronTable
{
    my $self = shift;

    my $query = "\"drop table if exists patron_import.stage_patron_old;\"";
    $self->query($query);

    print "stage_patron table dropped!\n";

    # We need to recreate this table!!!
}

sub getMaxStagePatronID
{
    my $self = shift;

    my $query = "select max(id) from patron_import.stage_patron p;";

    return $self->query($query)->[0]->[0] + 0;

}

sub getStagedPatrons
{
    my $self = shift;
    my $start = shift;
    my $stop = shift;

    # select * from patron_import.stage_patron p where p.id > 1 and p.id < 1000;
    my $tableName = "stage_patron";

    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.stage_patron p where p.id > $start and p.id < $stop;";
    print "query: [$query]\n";

    # my $patrons = $self->query($query);
    my $patrons = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    return $patrons;

}

sub saveStagedPatronRecords
{
    my $self = shift;
    my $patronRecords = shift;

    for my $patron (@{$patronRecords})
    {

        # This is the way I order the hash. It has to match the order of the stage_patron table.
        # I'm going to write a function that takes the hash, the table name and orders it in the _insertIntoTable function.
        # I hate this. Fix it.
        my @data = (
            $patron->{job_id},
            $patron->{institution_id},
            $patron->{file_id},
            $patron->{esid},
            $patron->{fingerprint},
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

sub insertPatron
{
    my $self = shift;
    my $patron = shift;
    my $tableName = "patron";


    my @data = (
        $patron->{id},
        $patron->{institution_id},
        $patron->{esid},
        $patron->{fingerprint},
        $patron->{loadfolio},
        $patron->{username},
        $patron->{barcode},
        $patron->{active},
        $patron->{patrongroup},
        $patron->{lastname},
        $patron->{firstname},
        $patron->{middlename},
        $patron->{preferredfirstname},
        $patron->{phone},
        $patron->{mobilephone},
        $patron->{dateofbirth},
        $patron->{preferredcontacttypeid},
        $patron->{enrollmentdate},
        $patron->{expirationdate},
    );

    $self->_insertIntoTable($tableName, \@data);

}

sub updatePatron
{

   my $query = "update patron p2
set
column1 = staging.column1
....
updated = true
from
staging_patron staging
join patron p on(p.institution=staging.institution and p.externalid=staging.externalid and p.fingerprint!=staging.fingerprint)
where
p.id=p2.id";




}

sub _insertIntoTable
{
    my $self = shift;
    my $tableName = shift;
    my $data = shift;

    my @columns = @{$self->{'cache'}->{$tableName}->{'columns'}};
    shift(@columns) if ($columns[0] eq 'id');

    my $columns = $self->_convertArrayToCSVString(\@columns);

    # build our $1,$2 ect... string
    my $dataString = "";
    my $totalColumns = @columns;

    for my $index (1 .. $totalColumns)
    {$dataString = $dataString . "\$$index,";}
    chop($dataString);

    # taking advantage of perls natural templating
    my $query = "INSERT INTO $schema.$tableName($columns) VALUES($dataString);";
    $main::log->addLine($query);

    eval {$self->{'db'}->updateWithParameters($query, $data);};

}

sub _selectAllFromTable
{
    my $self = shift;
    my $tableName = shift;

    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName;";
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

    my @columns = @{$self->{'cache'}->{$tableName}->{'columns'}};

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

sub getInstitutionMap
{
    my $self = shift;

    my $tableName = "institution_map";
    my $columns = $self->_getTableColumns($tableName);

    # my $query = "select $columns from $schema.$tableName order by id asc;";
    my $query = "select $columns from $schema.$tableName order by id asc limit 3;"; # todo: THIS IS DEBUG!!!

    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query));

}

sub _getTableColumns
{
    my $self = shift;
    my $tableName = shift;

    return $self->_convertArrayToCSVString(\@{$self->{'cache'}->{$tableName}->{'columns'}});

}

sub getInstitutionMapHashById
{
    my $self = shift;
    my $id = shift;

    my $tableName = "institution_map";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName t where t.id=$id;";
    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query))->[0];

}

sub getInstitutionMapHashByName
{
    my $self = shift;
    my $name = shift;
    my $tableName = "institution_map";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName t where t.institution='$name';";

    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query))->[0];

}

sub getLastFileTrackerEntryByFilename
{
    my $self = shift;
    my $fileName = shift;

    my $tableName = "file_tracker";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName where filename = '$fileName' order by id desc limit 1";
    return $self->{db}->query($query);

}

sub getLastFileTrackerEntry
{
    my $self = shift;
    my $tableName = "file_tracker";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName order by id desc limit 1";
    my $results = $self->{db}->query($query);
    return $results;

}

sub getLastJobID
{
    my $self = shift;
    my $tableName = "job";

    # Get the ID of the last job
    my $query = "select id from $schema.$tableName order by id desc limit 1;";
    return $self->{db}->query($query)->[0]->[0];

}

sub getTableSize
{
    my $self = shift;
    my $tableName = shift;

    my $query = "select count(id) from $schema.$tableName;";
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
            "GenericParser",
            ""
        );

        $self->_insertIntoTable("institution_map", \@data);

    }

}

sub buildPTypeMappingTableData
{
    my $self = shift;
    my $sqlInsert = $main::files->readFileToArray($main::conf->{patronTypeMappingSQLPath});

    my $query = "";
    for my $line (@{$sqlInsert})
    {
        $query .= $line . "\n";
    }

    $main::dao->{db}->query($query);

}

sub getPTYPEMappingSheet
{
    my $self = shift;
    my $institution = shift;
    my $ptype = shift;

    my $tableName = "ptype_mapping";
    my $columns = $self->_getTableColumns($tableName);
    my $query = "";

    # perl doesn't support method overloading. so I'm just going to code for it.
    # If we don't pass in an institution we return ALL ptypes.
    $query = "select ($columns) from $schema.$tableName where name='$institution' and ptype = '$ptype';" if ($institution ne "");
    $query = "select ($columns) from $schema.$tableName;" if ($institution eq "");

    return $self->query($query);

}

sub query
{
    my $self = shift;
    my $query = shift;

    # This is a wrapper for ->{db}->query
    # Instead of calling dao->{db}->query()
    # You can just call  dao->query()
    # saving a little typing over the course of the project.
    return $self->{db}->query($query);

}

sub getStagedPatronByUsername
{
    my $self = shift;
    my $username = shift;

    my $columns = $self->_getTableColumns("stage_patron");

    # Ok, so we're going to use the unique_id as the username
    # This comment is for grepping to find this spot in the code. You're welcome if it worked! lol
    # [unique_id username][unique id username][external_id username][external id username]
    my $query = "select $columns from patron_import.stage_patron p
                 where p.unique_id = '$username'";

    return $self->query($query);

}

sub getPatronByUsername
{
    my $self = shift;
    my $username = shift;

    my $columns = $self->_getTableColumns("patron");

    my $query = "select $columns from patron_import.patron p where p.username = '$username'";

    return $self->query($query);

}

1;