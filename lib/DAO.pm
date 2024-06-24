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
    # initDatabaseSchema($self); # <== this jacks up the output for command line api calls.

    return $self;

}

sub initDatabaseConnection
{
    my $self = shift;

    eval {$self->{db} = DBhandler->new($main::conf->{db}, $main::conf->{dbhost}, $main::conf->{dbuser}, $main::conf->{dbpass}, $main::conf->{port} || $main::conf->{port}, "postgres", 1);};
    if ($@)
    {
        print "Could not establish a connection to the database\n" if($main::conf->{print2Console});
        exit 1;
    }

    return $self;
}

sub initDatabaseSchema
{
    my $self = shift;
    my $filePath = $main::conf->{projectPath} . "/resources/sql/db.sql";

    print "building schema using $filePath\n" if($main::conf->{print2Console});
    $main::log->addLine("building schema using $filePath");

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

    # init our cache
    $self->_cacheTableColumns();

    my $institutionTableSize = $self->getTableSize("institution");
    if ($institutionTableSize == 0)
    {
        print "building database tables\n" if($main::conf->{print2Console});
        $main::log->addLine("building database tables");

        # Insert the MOBIUS Primary tenant. This should be in the db.sql yea?
        print "Insert the MOBIUS Primary tenant.\n" if($main::conf->{print2Console});
        $main::log->addLine("Insert the MOBIUS Primary tenant.");
        $self->query("INSERT INTO patron_import.institution (enabled, name, tenant, module, esid)
        VALUES (false, 'MOBIUS Office', 'cs00000001', 'GenericParser', '')");

        # Check our institution map
        print "Building the institution tables.\n" if($main::conf->{print2Console});
        $main::log->addLine("Building the institution tables.");
        $main::files->buildInstitutionTableData();

        # build out our ptype mapping table
        print "Building the ptype mapping tables.\n" if($main::conf->{print2Console});
        $main::log->addLine("Building the ptype mapping.");
        $main::files->buildPtypeMappingFromCSV();

        # insert our folio logins
        print "Populating login tables.\n" if($main::conf->{print2Console});
        $main::log->addLine("Populating login tables.");
        $self->populateFolioLoginTable();

        # re-cache our columns due to db update.
        print "Caching tables.\n" if($main::conf->{print2Console});
        $main::log->addLine("Caching tables.");
        $self->_cacheTableColumns();

    }

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
    {$main::log->addLine("queryHash failed! $query");};

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

    return $self;

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

sub getPatronByUsername
{
    my $self = shift;
    my $username = shift;

    my $tableName = "patron";
    my $columns = $self->_getTableColumns($tableName);

    my $results = [];
    my $query = "select $columns from $schema.$tableName where username='$username';";
    print "$query\n" if($main::conf->{print2Console});

    try
    {$results = $self->_convertQueryResultsToHash($tableName, $self->query($query));}
    catch
    {
        print "queryHash failed! $query\n" if($main::conf->{print2Console});
        $main::log->addLine("queryHash failed! $query");
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

sub getStagePatronCount
{
    my $self = shift;
    my $query = "SELECT count(*) as count FROM patron_import.stage_patron";
    return $main::dao->query($query)->[0]->[0];
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

    for my $institution (@{$self->_convertQueryResultsToHash("institution", $self->query("select $columns from patron_import.institution i order by i.id asc"))})
    {

        # get the folders
        for my $folder (@{$self->_convertQueryResultsToHash("folder", $self->query("select f.id,f.path from patron_import.folder f
                                        join patron_import.institution_folder_map fm on(fm.folder_id=f.id)
                                        where fm.institution_id = $institution->{'id'}"))})
        {

            # grab the files associated with this folder & institution
            my @files = @{$self->_convertQueryResultsToHash("file", $self->query("select * from patron_import.file f where f.institution_id = $institution->{'id'} order by f.id desc"))};
            my $institutionHash = {
                'id'      => $institution->{'id'},
                'enabled' => $institution->{'enabled'},
                'name'    => $institution->{'name'},
                'tenant'  => $institution->{tenant},
                'module'  => $institution->{'module'},
                'esid'    => $institution->{'esid'},
                'folder'  => {
                    'id'    => $folder->{'id'},
                    'path'  => $folder->{'path'},
                    'files' => \@files
                }
            };

            push(@institutions, $institutionHash);

        }

    }

    $self->{'cache'}->{'institutions'} = \@institutions;

    return $self->{'cache'}->{'institutions'};

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
    print "$query\n" if($main::conf->{print2Console});
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

    print "inserted [$count] records into $tableName\n" if($main::conf->{print2Console});

    return $csv;

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
    p.username is not null and
    p.institution_id=$institution_id;")->[0]->[0];

}

sub getPatronBatch2Import
{
    my $self = shift;
    my $institutionID = shift;

    my $chunkSize = $main::conf->{patronImportChunkSize};

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

        # Can I not do this? I should be grabbing the specified columns.
        # This _convertQueryResultsToHash is the freaking problem here. It want's all the column names.
        # I really need to fix that. DBD::pg

        # remove unwanted columns. todo: does this matter? We don't populate these fields in the json data.
        delete($patron->{id});
        delete($patron->{institution_id});
        delete($patron->{file_id});
        delete($patron->{job_id});
        delete($patron->{fingerprint});
        delete($patron->{ready});
        delete($patron->{error});
        delete($patron->{errormessage});

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

sub enablePatrons
{
    my $self = shift;
    my $patrons = shift;
    $self->setPatronsReadyStatus("true", $patrons);

    return $self;
}

sub disablePatrons
{
    my $self = shift;
    my $patrons = shift;
    $self->setPatronsReadyStatus("false", $patrons);

    return $self;
}

sub setPatronsReadyStatus
{
    my $self = shift;
    my $status = shift;
    my $patrons = shift;

    my @usernames = map {$_->{username}} @{$patrons};
    for my $username (@usernames)
    {
        $username =~ s/'/''/g; # escape ' tick marks in the esid.
        $username = "'$username',";
    }

    my $usernames = "@usernames";
    $usernames =~ s/,$//g; # <== removes the last comma?
    $usernames =~ s/\s//g; # <== remove spaces

    # I don't like this load_date=now(). I don't think it should be setting that in this function
    my $query = "update patron_import.patron set ready=$status, load_date=now()
    where username = ANY(ARRAY[$usernames])";
    $self->{db}->update($query);

}

sub getLastImportResponseID
{
    my $self = shift;

    return $self->query("select id from patron_import.import_response r order by r.id desc;")->[0]->[0];

}

sub populateFolioLoginTable
{
    my $self = shift;

    my $csv = $main::dao->createTableFromCSV("mobius_api_user", $main::conf->{projectPath} . "/resources/mapping/mobius_api_user.csv");

    my $update = "
    insert into patron_import.login (institution_id, username)
                    (select i.id, api.c2
                     from patron_import.institution i
                              join patron_import.mobius_api_user api on api.c1 = i.name);";

    $self->query($update);

    return $self;

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

1;
