package Parsers::ParserInterface;
use strict;
use warnings FATAL => 'all';

use Unicode::Normalize;
use Data::Dumper;

sub new
{
    my ($class, @args) = @_;
    my ($self, $args) = _init($class, \@args);
    @args = @{$args};
    bless $self, $class;
    return ($self, \@args);
}

sub _init
{
    my $self = shift;
    my $args = shift;
    my @args = @{$args};
    my @trace = ();
    $self =
        {
            institution => shift @args,
            dao         => shift @args,
            log         => shift @args,
            jobID       => shift @args,
            conf        => shift @args,
            debug       => shift @args,
            error       => undef,
            trace       => \@trace,
            base_stage_columns => {
                'institution_id'             => 'bigint',
                'file_id'                    => 'bigint',
                'job_id'                     => 'bigint',
                'fingerprint'                => 'text',
                'load'                       => 'boolean not null default true',
                'esid'                       => 'text',
                'unique_id'                  => 'text',
                'patron_type'                => 'text',
                'raw_data'                   => 'text',
            },
            stage_table_name => 'stage_patron'
        };
# Defaulting to the "Standard" stage_patron table
# Child modules should override this

    $self->{fingerprint_order} = [
        'field_code',
        'pcode1',
        'pcode2',
        'pcode3',
        'home_library',
        'patron_message_code',
        'patron_block_code',
        'patron_expiration_date',
        'name',
        'address',
        'address2',
        'telephone',
        'telephone2',
        'department',
        'barcode',
        'email_address',
        'note',
        'preferred_name',
        'custom_fields',
    ];
    return ($self, \@args);
}

sub onInit
{
    my $self = shift;
    print ref $self . " Parser initialized\n" if ($self->{debug});
    $self->{stage_columns} = {};
    $self->{stage_columns}->{$_} = 'text' foreach(@{$self->{fingerprint_order}});
    $self->{stage_columns}->{'department'} = 'text[]';
    $self->_createStageTable();
    $self->{dao}->_cacheTableColumns();
    return $self;
}

sub parse
{
    die "Subclass must implement parse()";
}

sub afterParse
{
    die "Subclass must implement afterParse()";
}

sub updateFinalTable
{
    # Generic (old) staging -> patron table update/insert
    # Function needs to be overridden by child classes if the staging table takes a differen form
    my $self = shift;

    my $query = <<'query_line';

INSERT INTO patron_import.patron
(
institution_id,
file_id,
job_id,
raw_data,
address1_one_liner,
address2_one_liner,
fingerprint,
username,
externalsystemid,
barcode,
email,
patrongroup,
lastname,
middlename,
firstname,
preferredfirstname,
phone,
mobilephone,
preferredcontacttypeid,
departments,
custom_fields,
note,
expirationdate
)
SELECT sp.institution_id,
       sp.file_id,
       sp.job_id,
       sp.raw_data,
       sp.address,
       sp.address2,
       sp.fingerprint,
       BTRIM(sp.unique_id),
       BTRIM(sp.esid),
       BTRIM(sp.barcode),
       BTRIM(sp.email_address),
       pt.foliogroup,
       BTRIM(REGEXP_REPLACE(sp.name, ',.*', '')) AS "lastname",
       CASE
           WHEN ARRAY_LENGTH(STRING_TO_ARRAY(BTRIM(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', '')), ' '), 1) > 2
               THEN REGEXP_REPLACE(BTRIM(REGEXP_REPLACE(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', ''), '^(\S+)\s+(.*?)\s*(?:,.*)?$', '\2')), ',', '', 'g')
           WHEN ARRAY_LENGTH(STRING_TO_ARRAY(BTRIM(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', '')), ' '), 1) = 2 THEN REGEXP_REPLACE(BTRIM(REGEXP_REPLACE(sp.name, '^[^,]+,\s*(\S+)\s+(\S+).*$', '\2')), ',', '', 'g')
           ELSE ''
           END                                   AS "middlename",
       REGEXP_REPLACE(BTRIM(SPLIT_PART(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', ''), ' ', 1)), ',', '', 'g'
       )                                         AS "firstname",
       CASE
           WHEN sp.preferred_name IS NULL OR sp.preferred_name = '' THEN NULL
           WHEN sp.preferred_name LIKE '%, %' THEN BTRIM(SUBSTRING(sp.preferred_name FROM ',(.*) '))
           ELSE BTRIM(sp.preferred_name)
           END,
       BTRIM(sp.telephone),
       BTRIM(sp.telephone2),
       'email',
       sp.department,
       sp.custom_fields,
       sp.note,
       CASE
           WHEN sp.patron_expiration_date ~ '\d{1,2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}' THEN sp.patron_expiration_date::DATE::TEXT
           ELSE NULL
           END
FROM patron_import.!stagetable! sp
         JOIN patron_import.institution i ON (sp.institution_id = i.id)
         LEFT JOIN patron_import.ptype_mapping pt ON ( pt.ptype = sp.patron_type AND pt.institution_id = i.id )
         LEFT JOIN patron_import.patron p2 ON ( sp.esid = p2.externalsystemid AND sp.institution_id = p2.institution_id )
         LEFT JOIN patron_import.patron p3 ON ( LOWER(p3.username) = LOWER(sp.unique_id) )

WHERE p2.id IS NULL
  AND sp.unique_id IS NOT NULL
  AND sp.unique_id != ''
  AND p3.id IS NULL

  AND sp.esid IS NOT NULL
  AND sp.esid != ''
  AND sp.load
  AND sp.name !~ '0';
query_line
    $self->_runUpdateQuery($query);

    $query = <<'query_line';

UPDATE patron_import.patron p
SET file_id                = sp.file_id,
    job_id                 = sp.job_id,
    fingerprint            = sp.fingerprint,
    username               = BTRIM(sp.unique_id),
    externalsystemid       = BTRIM(sp.esid),
    barcode                = BTRIM(sp.barcode),
    patrongroup            = pt.foliogroup,
    email                  = BTRIM(sp.email_address),
    lastname               = BTRIM(REGEXP_REPLACE(sp.name, ',.*', '')),
    middlename             = CASE
                                 WHEN ARRAY_LENGTH(STRING_TO_ARRAY(BTRIM(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', '')), ' '), 1) > 2
                                     THEN REGEXP_REPLACE(
                                         BTRIM(REGEXP_REPLACE(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', ''), '^(\S+)\s+(.*?)\s*(?:,.*)?$', '\2')), ',', '', 'g')
                                 WHEN ARRAY_LENGTH(STRING_TO_ARRAY(BTRIM(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', '')), ' '), 1) = 2
                                     THEN REGEXP_REPLACE(BTRIM(REGEXP_REPLACE(sp.name, '^[^,]+,\s*(\S+)\s+(\S+).*$', '\2')), ',', '', 'g')
                                 ELSE ''
        END,
    firstname = REGEXP_REPLACE(BTRIM(SPLIT_PART(REGEXP_REPLACE(sp.name, '^[^,]+,\s*', ''), ' ', 1)), ',', '', 'g'
                             ),
    preferredfirstname     = CASE
                                 WHEN
                                  length(btrim(sp.preferred_name)) > 2
                                  THEN
                                  (
                                    CASE WHEN sp.preferred_name ~ '.+?,\s*.+' THEN btrim(regexp_replace(sp.preferred_name, '.+?,\s*(.*)','\1','g'))
                                    ELSE btrim(regexp_replace(sp.preferred_name,',','','g'))
                                    END
                                  )
                                 ELSE NULL
                            END,
    phone                  = BTRIM(sp.telephone),
    mobilephone            = BTRIM(sp.telephone2),
    preferredcontacttypeid = 'email',
    ready                  = TRUE,
    update_date            = NOW(),
    raw_data               = sp.raw_data,
    address1_one_liner     = sp.address,
    address2_one_liner     = sp.address2,
    departments            = sp.department,
    custom_fields          = sp.custom_fields,
    note                   = sp.note,
    expirationdate         = CASE
                                 WHEN sp.patron_expiration_date ~ '\d{1,2}[\-\/\.]\d{2}[\-\/\.]\d{2,4}'
                                     THEN sp.patron_expiration_date::DATE::TEXT
                                 ELSE NULL
        END
FROM patron_import.!stagetable! sp
         JOIN patron_import.institution i ON (sp.institution_id = i.id)
         LEFT JOIN patron_import.ptype_mapping pt ON (pt.ptype = sp.patron_type AND pt.institution_id = i.id)
WHERE sp.fingerprint != p.fingerprint
  AND sp.esid = p.externalsystemid -- <== We have to MATCH our ESID
  AND sp.institution_id = p.institution_id
  AND sp.unique_id != ''
  AND sp.unique_id is NOT NULL
  AND sp.load
  AND sp.name !~ '0';

query_line
    $self->_runUpdateQuery($query);

    $query = "SELECT count(*) from
    patron_import.!stagetable! stagetable
    JOIN patron_import.patron finaltable on
    (
    finaltable.institution_id=stagetable.institution_id AND
    finaltable.username=stagetable.unique_id AND
    finaltable.ready AND
    stagetable.load
    )";
    return $self->_runQuery($query)->[0]->[0];
}

sub _cleanAndPrepStageTable
{
    my $self = shift;

    my $query = <<'query_line';
    UPDATE patron_import.!stagetable!
    SET
    unique_id = BTRIM(unique_id),
    esid = BTRIM(esid)
    ;
query_line
    $self->_runUpdateQuery($query);

    $query = <<'query_line';
    DELETE
    FROM patron_import.!stagetable! sp
    WHERE BTRIM(sp.esid) = ''
       OR sp.esid IS NULL;
query_line
    $self->_runUpdateQuery($query);

    $query = <<'query_line';
    DELETE
    FROM patron_import.!stagetable! sp
    WHERE sp.unique_id = ''
       OR sp.unique_id IS NULL;
query_line
    $self->_runUpdateQuery($query);

    $query = <<'query_line';
DELETE
FROM patron_import.!stagetable!
WHERE id IN
      (SELECT sp2.id
       FROM patron_import.!stagetable! sp
                JOIN patron_import.!stagetable! sp2
                     ON (sp.unique_id = sp2.unique_id AND sp.id != sp2.id AND sp.patron_type != sp2.patron_type AND sp.institution_id = sp2.institution_id)
                JOIN patron_import.ptype_mapping pt
                     ON (pt.institution_id = sp.institution_id AND pt.ptype = sp.patron_type)
                JOIN patron_import.ptype_mapping pt2
                     ON (pt2.institution_id = sp2.institution_id AND pt2.ptype = sp2.patron_type)
       WHERE pt.priority < pt2.priority);
query_line
    $self->_runUpdateQuery($query);

# dedupe !stagetable!
    $query = <<'query_line';
UPDATE patron_import.!stagetable! sp
SET load = TRUE
FROM (SELECT MIN(id) as id
      FROM patron_import.!stagetable!
      WHERE NOT load
      GROUP BY unique_id
      HAVING COUNT(*) = 1) b
WHERE sp.id = b.id
  AND BTRIM(sp.unique_id) != ''
  AND BTRIM(sp.esid) != ''
  AND sp.unique_id IS NOT NULL
  AND sp.esid IS NOT NULL
  AND NOT sp.load;
query_line
    $self->_runUpdateQuery($query);

# Removing duplicate entries from the patron stage
    $query = <<'query_line';
DELETE
FROM patron_import.!stagetable! p3
WHERE p3.id IN (SELECT p.id
                FROM patron_import.!stagetable! p
                WHERE p.unique_id IN (SELECT p1.unique_id
                                      FROM patron_import.!stagetable! p1
                                      GROUP BY p1.unique_id
                                      HAVING COUNT(*) > 1)
                  AND p.id NOT IN (SELECT MAX(p2.id)
                                   FROM patron_import.!stagetable! p2
                                   GROUP BY p2.unique_id
                                   HAVING COUNT(*) > 1)
                ORDER BY p.unique_id);
query_line
    $self->_runUpdateQuery($query);

# delete all patrons whose fingerprint matches what's in the patron table.
    $query = <<'query_line';
DELETE
FROM patron_import.!stagetable!
WHERE id IN (SELECT sp.id
             FROM patron_import.!stagetable! sp
                      JOIN patron_import.patron p ON p.fingerprint = sp.fingerprint);
query_line
    $self->_runUpdateQuery($query);

# Instead of removing the patron, we simply reset the date if it is in an invalid format
    $query = <<'query_line';
UPDATE patron_import.!stagetable! sp
SET patron_expiration_date = NULL
WHERE SUBSTRING(sp.patron_expiration_date FROM '^(\d+)')::INT > 12;
query_line
    $self->_runUpdateQuery($query);

# folio is subtracting a day from the expiration date. 12/10/2024 shows in folio as 12/09/2024, and it's confusing the staff
    $query = <<'query_line';
UPDATE patron_import.!stagetable!
SET patron_expiration_date = (
    CASE
        WHEN patron_expiration_date IS NULL OR patron_expiration_date = '' THEN NULL
        ELSE (patron_expiration_date::DATE + INTERVAL '1 day')::DATE
        END
    );
query_line
    $self->_runUpdateQuery($query);

}

sub insertPatronsIntoStageTable
{
    my $self = shift;
    return 0 if !$self->{parsedPatrons};
    my $queryHeader = "INSERT INTO patron_import." . $self->{stage_table_name} . " (";
    my @order = ();
    
    while ( (my $key, my $value) = each(%{$self->{base_stage_columns}}) )
    {
        push @order, $key;
        $queryHeader .= " $key,";
    }

    while ( (my $key, my $value) = each(%{$self->{stage_columns}}) )
    {
        push @order, $key;
        $queryHeader .= " $key,";
    }
    chop($queryHeader);
    $queryHeader .= ")\nVALUES\n";
    my $query = $queryHeader;
    my $chunksize = 100;
    my $count = 0;
    my $index = 1;
    my @values = ();
    foreach(@{$self->{parsedPatrons}})
    {
        my $thisPatron = $_;
        my $thisRow = "(";
        foreach(@order)
        {
            push @values, ($thisPatron->{$_} || '');
            $thisRow .= " \$$index,";
            $index++;
        }
        chop $thisRow;
        $thisRow .= ")";
        $query .= "$thisRow,\n";
        if($count % $chunksize == 0)
        {
            $query = substr($query, 0, -2);
            $self->{log}->addLogLine($query . Dumper(\@values)) if $self->{debug};
            $self->{dao}->update($query, \@values);
            $query = $queryHeader;
            @values = ();
            $index = 1;
        }
        undef $thisRow;
        $count++;
    }
    if(@values)
    {
        $query = substr($query, 0, -2);
        $self->{log}->addLogLine($query . Dumper(\@values)) if $self->{debug};
        $self->{dao}->update($query, \@values);
    }

    print "Parser staged $count patron(s)\n";
    undef $index;
    undef $count;
    undef $chunksize;
    undef $queryHeader;
    undef $query;
    undef @values;

    $self->_cleanAndPrepStageTable();
}

sub _runQuery
{
    my $self = shift;
    my $query = shift;
    $query =~ s/!stagetable!/$self->{stage_table_name}/g;
    $self->{log}->addLogLine($query) if $self->{debug};
    return $self->{dao}->query($query);
}

sub _runUpdateQuery
{
    my $self = shift;
    my $query = shift;
    my $vals = shift;
    my @values = ();
    @values = @{$vals} if ref $vals eq 'ARRAY';
    $query =~ s/!stagetable!/$self->{stage_table_name}/g;
    $self->{log}->addLogLine($query) if $self->{debug};
    $self->{dao}->update($query, \@values);
}

sub addTrace
{
    my $self = shift;
    my $func = shift;
    my $add = shift || '';
    $add = flattenArray($self, $add, 'string');
    my @t = @{$self->{trace}};
    push(@t, $func . ' / ' . $add);
    $self->{trace} = \@t;
}

sub getTrace
{
    my $self = shift;
    return $self->{trace};
}

sub flattenArray
{
    my $self = shift;
    my $array = shift;
    my $desiredResult = shift;
    my $retString = "";
    my @retArray = ();
    if (ref $array eq 'ARRAY')
    {
        my @a = @{$array};
        foreach (@a)
        {
            $retString .= "$_ / ";
            push(@retArray, $_);
        }
        $retString = substr($retString, 0, -3); # lop off the last trailing ' / '
    }
    elsif (ref $array eq 'HASH')
    {
        my %a = %{$array};
        while ((my $key, my $value) = each(%a))
        {
            $retString .= "$key = $value / ";
            push(@retArray, ($key, $value));
        }
        $retString = substr($retString, 0, -3); # lop off the last trailing ' / '
    }
    else # must be a string
    {
        $retString = $array;
        @retArray = ($array);
    }
    return \@retArray if (lc($desiredResult) eq 'array');
    return $retString;
}

sub setError
{
    my $self = shift;
    my $error = shift;
    $self->{error} = $error;
}

sub getError
{
    my $self = shift;
    return $self->{error};
}

sub getPatronFingerPrint
{
    my $self = shift;
    my $patron = shift;
    my $data = "";
    $data .= $self->normalizeText($patron->{$_}) foreach(@{$self->{fingerprint_order}});
    return MOBIUS::Utils->new()->calcSHA1($data);
}

sub _createStageTable
{
    my $self = shift;
    my $query = <<'query_line';
    DROP TABLE patron_import.!stagetable!;
query_line
    $self->_runUpdateQuery($query);
    my $indexQueryTemplate = "CREATE INDEX IF NOT EXISTS idx_!stagetable!_!col!_idx ON patron_import.!stagetable! USING btree(!col!);\n";
    my $indexQuery = "";

    $query = 'CREATE TABLE patron_import.!stagetable!(id serial primary key,';
    while ((my $internal, my $mvalue ) = each(%{$self->{base_stage_columns}}))
    {
        $query .= "$internal $mvalue,";
        if( $mvalue =~ /text/ || $mvalue =~ /int/)
        {
            $indexQuery .= $indexQueryTemplate;
            $indexQuery =~ s/!col!/$internal/g;
            $indexQuery .= "CREATE INDEX IF NOT EXISTS idx_!stagetable!_lower_uniqueid_idx ON patron_import.!stagetable! USING btree(LOWER(unique_id));\n"
                if ($internal =~ /unique_id/);
        }
    }
    while ((my $internal, my $mvalue ) = each(%{$self->{stage_columns}}))
    {
        $query .= "$internal $mvalue,";
    }

    # remove the trailing comma
    $query = substr($query, 0, -1) . ');';

    $self->_runUpdateQuery($query);
    $self->_runUpdateQuery($indexQuery);
}

sub normalizeText
{
    my $self = shift;
    my $data = shift;
    return '' unless $data;
    $data = NFD($data);
    $data =~ s/[\x{80}-\x{ffff}]//go;
    $data = lc($data);
    $data =~ s/\W+$//go;
    $data =~ s/\s//go;
    $data =~ s/\t//go;
    return $data;
}

sub readFileToArray
{
    my $self = shift;
    my $filePath = shift;


    $self->{log}->addLogLine("reading file: [$filePath]");

    # Check if file exists and is readable
    unless (-e $filePath && -r $filePath) {
        die "File does not exist or is not readable: $filePath";
    }

    my @data = ();
    my $lineCount = 0;
    my @encodings = ('UTF-8', 'cp1252', 'MacRoman');
    my $lastError = "";
    my $success = 0;

    # Try different encodings
    foreach my $encoding (@encodings)
    {
        eval {
            @data = (); # Clear the array
            $lineCount = 0;

            # Set up the file handle with proper encoding and binmode
            open(my $fh, '<', $filePath) or die "Could not open file '$filePath': $!";
            binmode($fh, ":encoding($encoding)");

            # Enable all platform line endings
            local $/ = undef; # Slurp mode
            my $content = <$fh>;
            close($fh);

            # Skip if content is empty
            die "Empty file" unless defined $content && length($content) > 0;

            # Split on any type of line ending
            my @lines = split(/\r\n|\r|\n/, $content);

            foreach my $line (@lines)
            {
                $line = $self->cleanLine($line);
                if ($line =~ /\S/) { # Only keep non-empty lines
                    push(@data, $line);
                    $lineCount++;
                }
            }

            # Check if we got any valid data
            die "No valid data found with $encoding" unless @data;

            $success = 1; # Mark as successful if we got here
            1;
        } or do {
            $lastError = $@ || "Unknown error";
            $self->{log}->addLogLine("Attempt with $encoding failed: $lastError");
            next; # Try next encoding
        };

        # If successful, exit the loop
        last if $success;
    }

    # If all encodings failed
    unless ($success) {
        $self->{log}->addLogLine("Failed to read file with any encoding. Last error: $lastError");
        die "Failed to read file with any encoding. Last error: $lastError";
    }

    my $arraySize = @data;
    $self->{log}->addLogLine("Total lines read: [$lineCount] : Total array size: [$arraySize]");

    return \@data;
}

sub cleanLine
{
    my $self = shift;
    my $line = shift;

    $line =~ s/[\x{201c}\x{201d}]//g; # Remove smart quotes
    $line =~ s/[\x{2018}\x{2019}]//g; # Remove smart apostrophes
    $line =~ s/\\//g;                 # Remove backslashes
    $line =~ s/\"//g;                 # Remove regular quotes
    $line =~ s/[\x00-\x1F\x7F]//g;    # Remove control characters

    return $line;
}


1;