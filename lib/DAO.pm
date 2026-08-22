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

my $schema = "patron_import";

sub new
{
    my $class = shift;
    my $self = {
        'conf'    => shift,
        'log'     => shift,
        'debug'   => shift,
        'initDB'  => shift,
        'db'      => 0,
        'cache'   => {},
        'dbh'     => 0,
    };
    bless $self, $class;
    $self = init($self);
    return $self;
}

sub init
{
    my $self = shift;
    $schema = $self->{conf}->{schema};

    $self->initDatabaseConnection();
    initDatabaseSchema() if($self->{initDB});
    $self->_cacheTableColumns();

    return $self;

}

sub initDatabaseConnection
{
    my $self = shift;

    eval {$self->{db} = DBhandler->new($self->{conf}->{db}, $self->{conf}->{dbhost}, $self->{conf}->{dbuser}, $self->{conf}->{dbpass}, $self->{conf}->{port} || $self->{conf}->{port}, "postgres", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n" if ($self->{debug});
        exit 1;
    }

    return $self;
}

sub initDatabaseSchema
{
    my $self = shift;
    my $filePath = $self->{conf}->{projectPath} . "/resources/sql/migrate/000-initial-schema.sql";

    print "building schema using $filePath\n" if ($self->{debug});
    $self->{log}->addLine("building schema using $filePath");

    open my $fileHandle, '<', $filePath or die "Could not open file '$filePath' $!";

    my $query = "";
    while (my $line = <$fileHandle>)
    {$query = $query . $line;}
    close $fileHandle;

    $self->{db}->update($query);

}

sub query
{
    my $self = shift;
    my $query = shift;

    return $self->{db}->query($query);
}

sub queryHash
{
    my $self = shift;
    my $tableName = shift;
    my $query = shift;

    my $columns = $self->_getTableColumns($tableName);

    my $results = [];

    try
    {$self->_convertQueryResultsToHash($tableName, $self->query($query));}
    catch
    {$self->{log}->addLine("queryHash failed! $query");};

    return $results;

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

    my $query = "select t.table_name, c.column_name,c.ordinal_position from information_schema.tables t
                join information_schema.columns c on(t.table_name = c.table_name)
                where t.table_schema='patron_import'
                group by t.table_name, c.ordinal_position, c.column_name
                order by t.table_name, c.ordinal_position, c.column_name;";

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

sub getStagedPatrons
{
    # this is only called in a test?!?
    my $self = shift;
    my $start = shift;
    my $stop = shift;

    my $tableName = "stage_patron";

    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns
                 from patron_import.stage_patron sp
                          left join patron_import.patron p on (sp.fingerprint = p.fingerprint and sp.institution_id = p.institution_id)
                 where p.id is null;";

    my $patrons = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    return $patrons;

}

sub insertHashIntoTable
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
    my $maxBefore = 0;
    my $maxAfter = 0;
    $maxBefore = $self->getMaxIDFromTable($tableName) + 0;

    $self->{'db'}->updateWithParameters($query, \@data);

    $maxAfter = $self->getMaxIDFromTable($tableName) + 0;
    return $maxAfter if($maxAfter > $maxBefore);
    return 0;
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

sub getPatronByUsername
{
    my $self = shift;
    my $username = shift;

    my $tableName = "patron";
    my $columns = $self->_getTableColumns($tableName);

    my $results = [];
    my $query = "select $columns from $schema.$tableName where username='$username';";
    print "$query\n" if ($self->{debug});

    try
    {$results = $self->_convertQueryResultsToHash($tableName, $self->query($query));}
    catch
    {
        print "queryHash failed! $query\n" if ($self->{debug});
            $self->{log}->addLine("queryHash failed! $query");
    };

    return $results->[0];

}

sub getTenantByUsername
{
    my $self = shift;
    my $username = shift;

    my $tableName = "institution";

    my $columns = $self->_getTableColumns($tableName);

    my $results = [];

    my $query = "select i.id,enabled,name,tenant,module,esid,emailsuccess,emailfail from patron_import.institution i
         join patron_import.patron p on p.institution_id = i.id
            where p.username = '$username';";

    $results = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    return $results->[0]->{tenant};

}

sub getPatronByESID
{
    my $self = shift;
    my $esid = shift;

    my $tableName = "patron";
    my $columns = $self->_getTableColumns($tableName);

    my $results = [];
    my $query = "select $columns from $schema.$tableName where externalsystemid='$esid';";
    print "$query\n" if ($self->{debug});

    try
    {$results = $self->_convertQueryResultsToHash($tableName, $self->query($query));}
    catch
    {
        print "queryHash failed! $query\n" if ($self->{debug});
        $self->{log}->addLine("queryHash failed! $query");
    };

    return $results->[0];

}

sub getPatronHashByID
{
    my $self = shift;
    my $id = shift;

    my $tableName = "patron";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName where id='$id';";
    my $results = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    return $results->[0];

}

sub getTenantByESID
{
    my $self = shift;
    my $esid = shift;

    my $tableName = "institution";

    my $columns = $self->_getTableColumns($tableName);

    my $results = [];

    my $query = "select i.id,enabled,name,tenant,module,esid,emailsuccess,emailfail from patron_import.institution i
         join patron_import.patron p on p.institution_id = i.id
            where p.externalsystemid = '$esid';";

    $results = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    return $results->[0]->{tenant};

}

sub getTenantByInstitutionId
{
    my $self = shift;
    my $institution_id = shift;

    my $tableName = "institution";

    my $columns = $self->_getTableColumns($tableName);

    my $results = [];

    my $query = "select $columns from patron_import.institution i where i.id=$institution_id;";
    $results = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    return $results->[0]->{tenant};

}

sub _convertQueryResultsToHash
{

    # there's a bug in this code. If you don't select ALL columns from the table you won't get the correct hash back.
    # You have to select all columns for this to work. DBI::pg has a function for this!!!
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

    return join(',', @{$data});
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

sub getInstitutionHashById
{
    my $self = shift;
    my $institution_id = shift;

    my $tableName = "institution";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName t where t.id=$institution_id;";

    return $self->_convertQueryResultsToHash($tableName, $self->{db}->query($query))->[0];

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
    my $institution_id = shift; # Optional parameter

    # Return cached result if available and no specific institution_id is requested
    return $self->{'cache'}->{'institutions'} if (!$institution_id && defined($self->{'cache'}->{'institutions'}));

    my @institutions = ();
    my $columns = $self->_getTableColumns("institution");

    my $institution_query = "select $columns from patron_import.institution i";
    $institution_query .= " WHERE i.id = $institution_id" if $institution_id;
    $institution_query .= " order by i.id asc";

    for my $institution (@{$self->_convertQueryResultsToHash("institution", $self->query($institution_query))})
    {
        my @folders = ();
        for my $folder (@{$self->_convertQueryResultsToHash("folder", $self->query("
            SELECT f.id, f.path
            FROM patron_import.folder f
            JOIN patron_import.institution_folder_map fm ON fm.folder_id = f.id
            WHERE fm.institution_id = $institution->{'id'}
        "))})
        {
            my @files = @{$self->_convertQueryResultsToHash("file", $self->query("
                SELECT *
                FROM patron_import.file f
                WHERE f.institution_id = $institution->{'id'}
                ORDER BY f.id DESC
            "))};

            push @folders, {
                'folder_id' => $folder->{'id'},
                'path'      => $folder->{'path'},
                'files'     => \@files
            };
        }

        my $institutionHash = {
            'id'      => $institution->{'id'},
            'enabled' => $institution->{'enabled'},
            'name'    => $institution->{'name'},
            'tenant'  => $institution->{'tenant'},
            'module'  => $institution->{'module'},
            'esid'    => $institution->{'esid'},
            'folders' => \@folders
        };

        push(@institutions, $institutionHash);
    }

    # Only cache if we're getting all institutions
    $self->{'cache'}->{'institutions'} = \@institutions unless $institution_id;

    return \@institutions;
}

sub getFullPathByInstitutionId
{
    my $self = shift;
    my $institution_id = shift;

    my $query = "SELECT f.path || '/patron-import/' || i.abbreviation
            FROM patron_import.institution i
                     JOIN patron_import.institution_folder_map ifm ON i.id = ifm.institution_id
                     JOIN patron_import.folder f ON ifm.folder_id = f.id
            WHERE i.id = $institution_id";

    return $self->{db}->query($query)->[0]->[0];

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

sub getFileTrackersByJobId
{

    my $self = shift;
    my $jobID = shift;

    my $tableName = "file_tracker";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select path from $schema.$tableName t where t.job_id=$jobID";
    my $results = $self->{db}->query($query);

    my @paths = map {$_->[0]} @{$results};

    return \@paths;

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
    print "$query\n" if ($self->{debug});
    $self->query($query);

}

# todo: test this! createTableFromHash()
sub createTableFromHash
{

    my $self = shift;
    my $tableName = shift;
    my $hash = shift;

    return $self if ($self->isTableExists($tableName));

    # build out the database columns. default to text
    my $columns = "\nid  SERIAL primary key,\n";
    for my $key (keys %{$hash})
    # {$columns = $columns . "$key text,\n";}
    {$columns = $columns . "'$key' text,\n";} # I'm pretty sure $key needs to be '$key'
    chop($columns);                           # \n
    chop($columns);                           # ,

    my $query = "create table if not exists $schema.$tableName ($columns);";

    $self->query($query);

    return $self;
}

sub getESIDFromMappingTable
{
    my $self = shift;
    my $institution = shift;

    my $tableName = "sso_esid_mapping";

    my $query = "select t.c3 from $schema.$tableName t where t.c1 = '$institution->{name}'";

    my $results = $self->query($query)->[0]->[0];

    return "email" if ($results =~ /email/);
    return "barcode" if ($results =~ /barcode/);
    return "unique_id" if ($results =~ /unique/);
    return "note" if ($results =~ /note/);
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

sub getALLPatronImportPendingSize
{
    my $self = shift;

    # select count(p.id) from patron_import.patron p
    # where p.ready and
    # p.patrongroup is not null and
    # p.externalsystemid is not null and
    # p.username is not null and
    # p.institution_id=9;

    return $self->query("select count(p.id) from patron_import.patron p where
    p.ready and
    p.patrongroup is not null and
    p.externalsystemid is not null and
    p.username is not null;")->[0]->[0];

}

# get the total number of patrons left to load
sub getPatronImportPendingSize
{
    my $self = shift;
    my $institution_id = shift;

    return $self->query("select count(p.id) from patron_import.patron p where
    p.ready and
    p.patrongroup is not null and
    p.externalsystemid is not null and
    p.username is not null and
    p.institution_id=$institution_id;")->[0]->[0];

}

sub getPatronBatch2Import
{
    my $self = shift;
    my $institutionID = shift;

    my $chunkSize = shift || $self->{conf}->{patronImportChunkSize};

    my $tableName = "patron";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select $columns from $schema.$tableName p where
                     p.ready and
                     p.patrongroup is not null and
                     p.externalsystemid is not null and
                     p.username is not null and
                     p.institution_id=$institutionID
                     limit $chunkSize";

    my $patrons = $self->_convertQueryResultsToHash($tableName, $self->query($query));

    # we now need the addresses. Ideally this would be 1 query. this convertQueryResults is busted on joins.
    # DBI::pg has this tho! *i think. Live and learn. I would have totally used that to begin with. todo: <= do that!
    # Turns out the DBI::pg fetchrow_hashref is a thing. But it's basically the same thing I wrote and the joins would be busted
    # on it too! *Yea, I really need to retest this theory because I'm pretty sure I can actually do this. I rework DBHandler.pm soon!
    $tableName = "address";
    $columns = $self->_getTableColumns("address");

    # add our address to the patron hash
    for my $patron (@{$patrons})
    {

        $query = "select $columns from $schema.$tableName a where a.patron_id=$patron->{id}";
        my $address = $self->_convertQueryResultsToHash($tableName, $self->query($query));

        # loop thru $address and check for null or undef values and set to "" if so.
        for my $addressItem (@{$address})
        {for my $key (keys %{$addressItem})
        {$addressItem->{$key} = "" if (!defined($addressItem->{$key}));}}

        $patron->{address} = $address;

        # remove unwanted address fields
        my $addressIndex = 0;
        for ($patron->{address})
        {
            delete($patron->{address}->[$addressIndex]->{id});
            delete($patron->{address}->[$addressIndex]->{patron_id});
            $addressIndex++;
        }

    }

    return $patrons;

}

sub getFOLIOLoginCredentials
{
    my $self = shift;
    my $institution_id = shift;

    my $tableName = "login";
    my $columns = $self->_getTableColumns($tableName);

    return $self->_convertQueryResultsToHash(
        $tableName, $self->query("select $columns from $schema.$tableName l where l.institution_id=$institution_id")
    )->[0];

}

sub getInstitutionsHashByEnabled
{
    my $self = shift;
    my $tableName = "institution";

    my $columns = $self->_getTableColumns($tableName);

    return
        $self->_convertQueryResultsToHash(
            $tableName, $self->query("select $columns from $schema.$tableName t where t.enabled")
        );

}

sub finalizePatron
{
    my $self = shift;
    my $patrons = shift;

    my @patronIds = map {$_->{id}} @{$patrons};
    for my $id (@patronIds)
    {
        $id = "'$id',";
    }

    my $ids = "@patronIds";
    $ids =~ s/,$//g; # <== removes the last comma
    my $jobID = $self->{jobID};

    my $query = "update patron_import.patron set ready=false, job_id=$jobID, load_date=now()
    where id in($ids)";

    $self->{db}->update($query);

}

sub getLastJobIDForInstitution
{
    my $self = shift;
    my $institutionID = shift;
    return $self->query("select max(job_id) from patron_import.import_response WHERE institution_id = $institutionID;")->[0]->[0];
}

sub getImportResponseTotalsForInstitution
{
    my $self = shift;
    my $institutionID = shift;
    my $job_id = shift;
    return 0 if(!(defined($job_id)) && !(defined($institutionID)) );

    my $ob = $self->query("
    select
    sum(created),
    sum(updated),
    sum(failed),
    sum(total)
    from patron_import.import_response
    WHERE
    institution_id = $institutionID
    and job_id = $job_id;")->[0];

    my %ret = (
        created => $ob->[0],
        updated => $ob->[1],
        failed  => $ob->[2],
        total   => $ob->[3]
    );
    return \%ret;

}

sub getLastImportResponseID
{
    my $self = shift;

    return $self->query("select id from patron_import.import_response r order by r.id desc limit 1;")->[0]->[0];

}

sub getFolioCredentials
{
    my $self = shift;
    my $tenant = shift;

    my $tableName = "login";

    my $columns = $self->_getTableColumns($tableName);

    my $query = "select l.username, l.password from patron_import.login l
                    join patron_import.institution i on i.id = l.institution_id
                    where i.tenant='$tenant'";

    my $results = $self->query($query)->[0];
    my $credentials = {
        username => $results->[0],
        password => $results->[1]
    };

    return $credentials;

}

sub convertHashToSQLTable
{
    my $self = shift;
    my $tableName = shift;
    my $hash = shift;

    my @columns;
    push @columns, "id SERIAL PRIMARY KEY";

    foreach my $key (keys %$hash)
    {
        next if $key eq 'id'; # Skip the 'id' key if it exists in the hash

        my $value = $hash->{$key};
        my $type;

        if ($value =~ /^\d+$/)
        {
            $type = "INTEGER";
        }
        elsif ($value =~ /^\d+\.\d+$/)
        {
            $type = "DECIMAL";
        }
        else
        {
            $type = "TEXT";
        }

        push @columns, "$key $type";
    }

    my $columnsString = join ", ", @columns;

    my $sql = qq{
        CREATE TABLE $tableName (
            $columnsString
        );
    };

    return $sql;
}

sub setPatronsJobId
{
    my $self = shift;
    my $patrons = shift;

    my $jobId = $self->{jobID};

    for my $patron (@{$patrons})
    {$self->query("update patron_import.patron set job_id=$jobId where id=$patron->{id}");}

}

sub getArrayOfEnabledInstitutionIDs
{
    my $self = shift;

    my $tableName = "institution";
    my $columns = $self->_getTableColumns($tableName);

    my $query = "select i.id from $schema.$tableName i where i.enabled";

    my $results = $self->query($query);
    my @ids = map {$_->[0]} @{$results};

    return \@ids;

}

sub disableInstitution
{
    my $self = shift;
    my $institutionID = shift;

    my $query = "update patron_import.institution set enabled=false where id=$institutionID";
    $self->query($query);

}

sub enableInstitution
{
    my $self = shift;
    my $institutionID = shift;

    my $query = "update patron_import.institution set enabled=true where id=$institutionID";
    $self->query($query);

}

sub bulkEnableDisable
{
    my $self = shift;
    my $enable = shift;
    my $institutionIDs = shift;

    my $idsAsString = join(",", @{$institutionIDs});

    my $query = "update patron_import.institution set enabled=$enable where id in($idsAsString)";
    $self->query($query);

}

sub startJob
{
    my $self = shift;
    my $stage = shift;
    my $import = shift;

    my $job = {
        'job_type'   => "$import$stage",
        'start_time' => $self->_getCurrentTimestamp,
        'stop_time'  => $self->_getCurrentTimestamp,
    };

    $self->insertHashIntoTable("job", $job);
    $self->{jobID} = $self->getLastJobID();
    return $self->{jobID};
}

sub finishJob
{
    my $self = shift;

    my $timestamp = $self->_getCurrentTimestamp();
    my $jobID = $self->{jobID};
    my $query = "update $schema.job
                 set stop_time='$timestamp' where id=$jobID;";
    print $query . "\n" if ($self->{debug});
    $self->{db}->update($query);
    $self->{log}->addLine("Job $self->{jobID} finished at $timestamp");

}

# getFileTrackerIDByJobIDAndFilePath($self->{jobID}, $path);
sub getFileTrackerIDByJobIDAndFilePath
{
    my $self = shift;
    my $path = shift;

    my $jobID = $self->{jobID};

    my $query = "select id from $schema.file_tracker where job_id=$jobID and path='$path'";
    return $self->query($query)->[0]->[0];

}

sub getMaxIDFromTable
{
    my $self = shift;
    my $table = shift;
    my $ret = $self->query("select max(id) from patron_import.$table");
    return 0 unless $ret;
    return 0 unless $ret->[0];
    return $ret->[0]->[0];
}
1;
