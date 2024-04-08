package DAO;
use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';
use MOBIUS::DBhandler;
use Data::Dumper;
use Try::Tiny;

# https://metacpan.org/pod/DBD::Pg#fetchrow_hashref
# https://metacpan.org/dist/ResourcePool/view/lib/ResourcePool.pm
# https://metacpan.org/dist/ResourcePool/view/lib/ResourcePool/BigPicture.pod

my $schema = "";

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
    my $filePath = $main::conf->{sqlFilePath} . "/db.sql";

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";

    my $query = "";
    while (my $line = <$fileHandle>)
    {$query = $query . $line;}
    close $fileHandle;

    # drop the schema if we pass in the --drop-schema
    $query = "drop schema if exists patron_import cascade;" . $query if (defined $main::dropSchema);
    print "drop schema if exists patron_import cascade;" if (defined $main::dropSchema);

    $self->{db}->update($query);

}

sub checkDatabaseStatus
{
    my $self = shift;

    # init our cache
    $self->_cacheTableColumns();

    # Check our institution map
    my $institutionTableSize = $self->getTableSize("institution");
    $main::files->buildInstitutionTableData() if ($institutionTableSize == 0);

    my $ptypeMappingTableSize = $self->getTableSize("ptype_mapping");
    $main::files->buildPtypeMappingFromCSV() if ($ptypeMappingTableSize == 0);

}

sub _initDatabaseCache
{
    my $self = shift;

    # A kind of registry for all database cache objects
    $self->_cacheTableColumns();

    # We can't cache things that haven't been created yet!!!
    # This is some idea's for future caching
    # $self->_initDatabaseCacheInstitutions();
    # $self->_initDatabaseCachePtype_mapping();

}

sub query
{
    my $self = shift;
    my $query = shift;

    return $self->{db}->query($query);

}

sub update
{
    my $self = shift;
    my $query = shift;
    my $data = shift;
    return $self->{db}->updateWithParameters($query, $data);
}

sub _cacheTableColumns
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
                $self->{'cache'}->{'columns'}->{$tableName} = \@columnCopy; # <== new
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
        $self->{'cache'}->{'columns'}->{$tableName} = \@columnCopy;
    }

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

    # my $query = "select $columns from $schema.stage_patron p where p.id > $start and p.id < $stop;";
    my $query = "select $columns
                 from patron_import.stage_patron sp
                          left join patron_import.patron p on (sp.fingerprint = p.fingerprint and sp.institution_id = p.institution_id)
                 where p.id is null;";

    my $patrons = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    return $patrons;

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

    $self->_insertArrayIntoTable($tableName, \@data);

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

sub _insertHashIntoTable
{
    my $self = shift;
    my $tableName = shift;
    my $hash = shift;

    # grab some sort of column order from the hash
    my @sqlColumns = ();
    push(@sqlColumns, $_) for (keys %{$hash});

    # now order the data to the sqlColumns
    my @data = ();
    push(@data, $hash->{$_}) for (@sqlColumns);

    my $columns = $self->_convertColumnArrayToCSVString(\@sqlColumns);

    # build our $1,$2 ect... string
    my $dataString = "";
    my $totalColumns = @sqlColumns;

    for my $index (1 .. $totalColumns)
    {$dataString = $dataString . "\$$index,";}
    chop($dataString);

    # taking advantage of perls natural templating
    my $query = "INSERT INTO $schema.$tableName($columns) VALUES($dataString);";
    # $main::log->addLine($query);

    $self->{'db'}->updateWithParameters($query, \@data);

}

sub _insertArrayIntoTable
{
    my $self = shift;
    my $tableName = shift;
    my $data = shift;

    my @columns = ();

    try
    {
        @columns = @{$self->{'cache'}->{'columns'}->{$tableName}};
    }
    catch
    {
        $self->_cacheTableColumns();
        @columns = @{$self->{'cache'}->{'columns'}->{$tableName}};
    };

    shift(@columns) if ($columns[0] eq 'id'); # <== remove the id before insert

    my $columns = $self->_convertColumnArrayToCSVString(\@columns);

    # build our $1,$2 ect... string
    my $dataString = "";
    my $totalColumns = @columns;

    for my $index (1 .. $totalColumns)
    {$dataString = $dataString . "\$$index,";}
    chop($dataString);

    # taking advantage of perls natural templating
    my $query = "INSERT INTO $schema.$tableName($columns) VALUES($dataString);";
    # $main::log->addLine($query);

    # eval {$self->{'db'}->updateWithParameters($query, $data);};
    $self->{'db'}->updateWithParameters($query, $data);

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

sub _convertQueryResultsToHash
{

    # there's a bug in this code. If you don't select ALL columns from the table you won't get the correct hash back.
    # You have to select all columns for this to work.
    # I'll fix this at some point.

    my $self = shift;
    my $tableName = shift;
    my $data = shift;

    my @columns = @{$self->{'cache'}->{'columns'}->{$tableName}};

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

sub _convertColumnArrayToCSVString
{
    my $self = shift;
    my $data = shift;

    my @array = @{$data};
    my $csv = "@array";
    $csv =~ s/\s/,/g;

    return $csv;
}

# array of hashes
sub _getAllRecordsByTableName
{
    my $self = shift;

    my $tableName = shift;
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName t order by t.id asc;";

    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query));

}

sub _getTableColumns
{
    my $self = shift;
    my $tableName = shift;

    return $self->_convertColumnArrayToCSVString(\@{$self->{'cache'}->{'columns'}->{$tableName}});

}

sub getInstitutionHashByInstitutionID
{
    my $self = shift;
    my $id = shift;

}

sub getInstitutionMapHashByName
{
    my $self = shift;
    my $name = shift;
    my $tableName = "institution";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName t where t.institution='$name';";

    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query))->[0];

}

sub getInstitutionsFoldersAndFilesHash
{
    my $self = shift;

    return $self->{'cache'}->{'institutions'} if (defined($self->{'cache'}->{'institutions'}));

    my @institutions = ();
    my $columns = $self->_getTableColumns("institution");

    for my $i (@{$self->_convertQueryResultsToHash("institution", $self->query("select $columns from patron_import.institution i order by i.id asc"))})
    {

        # get the folders
        for my $folder (@{$self->_convertQueryResultsToHash("folder", $self->query("select f.id,f.path from patron_import.folder f
                                        join patron_import.institution_folder_map fm on(fm.folder_id=f.id)
                                        where fm.institution_id = $i->{'id'}"))})
        {

            # grab the files associated with this folder & institution
            # my @files = @{$self->_convertQueryResultsToHash("file", $self->query("select * from patron_import.file f where f.folder_id = $folder->{'id'}"))};
            my @files = @{$self->_convertQueryResultsToHash("file", $self->query("select * from patron_import.file f where f.institution_id = $i->{'id'}"))};
            my $institution = {
                'id'      => $i->{'id'},
                'enabled' => $i->{'enabled'},
                'name'    => $i->{'name'},
                'module'  => $i->{'module'},
                'esid'    => $i->{'esid'},
                'folder'  => {
                    'id'    => $folder->{'id'},
                    'path'  => $folder->{'path'},
                    'files' => \@files
                }

            };

            push(@institutions, $institution);

        }

    }

    $self->{'cache'}->{'institutions'} = \@institutions;

    return \@institutions;

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

sub isTableExists
{
    my $self = shift;
    my $tableName = shift;

    my $query = "select t.table_name from information_schema.tables t
                where t.table_schema='$schema' and t.table_name='$tableName';";

    my $size = @{$self->query($query)};

    return 1 if ($size > 0);
    return 0 if ($size == 0);

}

sub dropTable
{
    my $self = shift;
    my $tableName = shift;

    my $query = "drop table if exists $schema.$tableName;";
    print "$query\n";
    $self->query($query);

}

sub createTableFromHash
{

    my $self = shift;
    my $tableName = shift;
    my $hash = shift;

    if ($self->isTableExists($tableName))
    { # do something...
    }

    # build out the database columns. default to text
    my $columns = "\nid  SERIAL primary key,\n";
    for my $key (keys %{$hash})
    {$columns = $columns . "$key text,\n";}
    chop($columns); # \n
    chop($columns); # ,

    my $query = "create table if not exists $schema.$tableName ($columns);";

    $self->query($query);

}

sub createTableFromCSV
{

    my $self = shift;
    my $tableName = shift;
    my $filePath = shift;
    my $rowsToSkip = shift | 0;

    my $csv = $main::files->_loadCSVFileAsArray($filePath);
    my $totalColumns = @{$csv->[$rowsToSkip]};

    # create our table
    my $columns = "";
    for my $index (1 .. $totalColumns)
    {
        $columns .= "C$index text,";
    }
    chop($columns); # ,

    my $query = "create table if not exists $schema.$tableName ($columns);";
    $self->query($query);

    # now load the csv into this table
    my $count = 0;
    for my $row (@{$csv})
    {

        # skip n rows
        if ($count < $rowsToSkip)
        {
            $count++;
            next;
        }

        $self->_insertArrayIntoTable($tableName, $row);
        $count++;
    }

    print "inserted [$count] records into $tableName\n";

}

sub getESIDFromMappingTable
{
    my $self = shift;
    my $institution = shift;

    my $tableName = "sso_esid_mapping";

    my $query = "select c3 from $schema.$tableName where c1 = '$institution->{institutionName}'";

    my $results = $self->query($query)->[0]->[0];

    return "email" if ($results =~ /email/);
    return "barcode" if ($results =~ /barcode/);
    return "";

}

sub _getLastIDByTableName
{
    my $self = shift;
    my $table = shift;

    my $query = "select last_value from $schema." . $table . "_id_seq";

    return $self->query($query)->[0]->[0];

}

sub getFiles
{
    my $self = shift;

    my $tableName = "file";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.file f order by f.id asc";
    return $self->query($query);

}

# Parser: 30
# FileService: 323
sub getAllInstitutionIdAndName
{
    my $self = shift;

    # I want an array of hashes, but my convert to hash code doesn't work with joins. I'm sorry Blake. Code hard brah!
    # I'll try and come back to this to clean it up.

    # return $self->{'cache'}->{'institutions'} if (defined($self->{'cache'}->{'institutions'}));

    my $query = "select i.id, i.name
                    from patron_import.institution i
                    order by i.id asc";

    return $self->_convertQueryResultsToHash("institution", $self->query($query));

}

sub truncateStagePatronTable
{
    my $self = shift;
    $self->{db}->query("truncate $schema.stage_patron");

    return $self;
}

# get the total number of patrons left to load
sub getPatronImportPendingSize
{
    my $self = shift;

    return $self->query("select count(p.id) from patron_import.patron p where p.folioready;")->[0]->[0];
}

sub getPatronImportChunk
{
    my $self = shift;
    my $chunkSize = shift;

}

1;