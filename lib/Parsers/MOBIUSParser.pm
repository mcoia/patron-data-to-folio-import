package Parsers::MOBIUSParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;

# MOBIUS CSV parser
use parent 'Parsers::ParserInterface';

sub new
{
    my ($class, @args) = @_;
    my ($self, $args) = $class->SUPER::new(@args);

    $self = _init($self, $args);
    return $self;
}

sub _init
{
    my $self = shift;

    if ($self->{institution} && $self->{dao} && $self->{log})
    {
        if ($self->getError())
        {
            $self->addTrace("Error loading MOBIUSParser");
        }
    }
    else
    {
        $self->setError("Couldn't initialize MOBIUSParser object");
    }
    $self->{stage_table_name} = 'stage_patron_mobiuscsv';
    $self->{fingerprint_order} = [
        'custom_fields',
        'email',
        'lastname',
        'firstname',
        'middlename',
        'preferredfirstname',
        'pronouns',
        'address1_line1',
        'address1_line2',
        'address1_city',
        'address1_state',
        'address1_zip',
        'address2_line1',
        'address2_line2',
        'address2_city',
        'address2_state',
        'address2_zip',
        'phone',
        'mobilephone',
        'enrollmentdate',
        'dateofbirth',
        'preferredcontacttypeid',
        'expirationdate',
        'department',
    ];
    return $self;
}

sub parse
{
    my $self = shift;
    my $institution = $self->{institution};
    my @parsedPatrons = ();

    print "Starting parse for institution: $institution->{id}\n" if ($self->{debug});

    for my $folder (@{$institution->{folders}})
    {
        for my $file (@{$folder->{files}})
        {
            print "Processing file: $file->{name}\n" if ($self->{debug});

            my $patronCounter = 0;
            for my $file_paths (@{$file->{'paths'}})
            {
                print "Reading file: [$file_paths->{'path'}]\n" if ($self->{debug});
                my $delimeter = $self->figureDelimiter($file_paths->{'path'});

                my $csv = Text::CSV->new({ binary => 1, auto_diag => 1, sep_char => $delimeter });
                open my $fh, "<:encoding(utf8)", $file_paths->{'path'} or die "Cannot open $file_paths->{'path'}: $!";

                # Read header row to get column indexes
                my $headers = $csv->getline($fh);

                # Strip UTF-8 BOM from first column name if present
                $headers->[0] =~ s/^\x{FEFF}// if ($headers && @$headers && $headers->[0]);

                $csv->column_names($headers);

                # Process each line in the CSV
                while (my $row = $csv->getline_hr($fh))
                {
                    print "Processing row: " . Dumper($row) if ($self->{debug});

                    my $patron = $self->_parseRow($row);

                    # skip if we didn't get a patron
                    next if (!defined($patron));

                    $patron->{fingerprint} = $self->getPatronFingerPrint($patron);
                    $patron->{load} = 'true';
                    $patron->{institution_id} = $institution->{id};
                    $patron->{job_id} = $self->{jobID};
                    $patron->{file_id} = $file_paths->{'id'};

                    push(@parsedPatrons, $patron);
                    $patronCounter++;
                }

                close $fh;
            }

            print "Total Patrons in $file->{name}: [$patronCounter]\n" if ($self->{debug});
            $self->{log}->addLine("Total Patrons in $file->{name}: [$patronCounter]\n");
        }
    }

    print "Finished parsing institution: $institution->{id}\n" if ($self->{debug});

    $self->{parsedPatrons} = \@parsedPatrons;
    return \@parsedPatrons;
}

sub figureDelimiter
{
    my $self = shift;
    my $file = shift;
    my $fileContents = "";
    my $lineCount = 0;
    open(my $fh,"<",$file) || die "error $!\n";
    while(<$fh>)
    {
        my $line = $_;
        $line =~ s/\n//g;
        $line =~ s/\r//g;
        $fileContents .= "$line\n";
        $lineCount++;
        # we just need a sample
        last if($lineCount > 1);
    }
    close $fh;
    my @lines = split(/\n/, $fileContents);
    my $commas = 0;
    my $tabs = 0;
    my $loops = 0;
    foreach(@lines)
    {
        my @split = split(/,/,$_);
        $commas+=$#split;
        @split = split(/\t/,$_);
        $tabs+=$#split;
        last if ($loops > 100);
        $loops++;
    }
    my $delimiter = $commas > $tabs ? "," : "\t";
    return $delimiter;
}


sub _parseRow
{
    my $self = shift;
    my $row = shift;
    my $patron = {};

    # make sure that the required fields exist and are non-blank
    my @required = ('unique_id', 'esid');
    foreach(@required)
    {
        if($row->{$_} && length($row->{$_}) > 0)
        {
            $patron->{$_} = $row->{$_};
        }
        else
        {
            return undef;
        }
    }

    undef @required;

    while ( (my $key, my $value) = each(%{$self->{stage_columns}}) )
    {
        if($key eq 'department')
        {
            #dollar sign delimited field
            if($row->{$key} && length($row->{$key}) > 0)
            {
                my @departments = split(/$/,$row->{$key});
                $patron->{$key} = \@departments;
            }
        }
        else
        {
            $patron->{$key} = $row->{$key} if($row->{$key});
        }
    }

    my $raw_data = "";
    foreach my $key (sort keys %{$self->{stage_columns}})
    {
        $raw_data .= "$key: " . ($row->{$key} || "") . "\n";
    }
    $patron->{raw_data} = $raw_data;

    # save some memory, come get it garbage collector!
    undef $raw_data;

    return $patron;
}

sub afterParse
{
    my $self = shift;
    return 1;
}

sub updateFinalTable
{
    my $self = shift;

    my $query = <<'query_line';

INSERT INTO patron_import.patron
(
institution_id,
file_id,
job_id,
fingerprint,
raw_data,
username,
externalsystemid,
barcode,
email,
patrongroup,
enrollmentdate,
expirationdate,
dateofbirth,
lastname,
middlename,
firstname,
pronouns,
preferredfirstname,
phone,
mobilephone,
address1_one_liner,
address2_one_liner,
preferredcontacttypeid,
department,
custom_fields
)
SELECT sp.institution_id,
       sp.file_id,
       sp.job_id,
       sp.fingerprint,
       sp.raw_data,
       BTRIM(sp.unique_id),
       BTRIM(sp.esid),
       NULLIF(BTRIM(COALESCE(sp.barcode, $$$$)), $$$$),
       NULLIF(BTRIM(COALESCE(sp.email, $$$$)), $$$$),
       pt.foliogroup,
       (
            CASE
                WHEN sp.enrollmentdate ~ '\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{4}' THEN sp.enrollmentdate::DATE::TEXT
                ELSE NULL
            END
       ),
       (
            CASE
                WHEN sp.expirationdate ~ '\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{4}' THEN sp.expirationdate::DATE::TEXT
                ELSE NULL
            END
       ),
       (
            CASE
                WHEN sp.dateofbirth ~ '\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{4}' THEN sp.dateofbirth::DATE::TEXT
                ELSE NULL
            END
        ),
       BTRIM(sp.lastname),
       BTRIM(sp.middlename),
       BTRIM(sp.firstname),
       NULLIF(BTRIM(COALESCE(sp.pronouns, $$$$)), $$$$),
       NULLIF(BTRIM(COALESCE(sp.preferredfirstname, $$$$)), $$$$),
       NULLIF(BTRIM(COALESCE(sp.phone, $$$$)), $$$$),
       NULLIF(BTRIM(COALESCE(sp.mobilephone, $$$$)), $$$$),
-- Address smasher "line1$line2$city, state zip"
(CASE WHEN sp.address1_line1 IS NOT NULL AND LENGTH(sp.address1_line1) > 1 THEN
    regexp_replace(sp.address1_line1, $a$$$a$, $$$$, $$g$$) || $a$$$a$ ||
    COALESCE(regexp_replace(sp.address1_line2, $a$$$a$, $$$$, $$g$$), $$$$) || $a$$$a$ ||
    COALESCE(regexp_replace(sp.address1_city, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$, $a$ ||
    COALESCE(regexp_replace(sp.address1_state, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$ $a$ ||
    COALESCE(regexp_replace(sp.address1_zip, $a$[\$,]$a$, $$$$, $$g$$), $$$$)
ELSE
    $$$$
END
),
-- Address smasher "line1$line2$city, state zip"
(CASE WHEN sp.address2_line1 IS NOT NULL AND LENGTH(sp.address2_line1) > 1 THEN
    regexp_replace(sp.address2_line1, $a$$$a$, $$$$, $$g$$) || $a$$$a$ ||
    COALESCE(regexp_replace(sp.address2_line2, $a$$$a$, $$$$, $$g$$), $$$$) || $a$$$a$ ||
    COALESCE(regexp_replace(sp.address2_city, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$, $a$ ||
    COALESCE(regexp_replace(sp.address2_state, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$ $a$ ||
    COALESCE(regexp_replace(sp.address2_zip, $a$[\$,]$a$, $$$$, $$g$$), $$$$)
ELSE
    $$$$
END
),
       $$email$$,
       sp.department,
       sp.custom_fields
FROM patron_import.!stagetable! sp
         JOIN patron_import.institution i ON (sp.institution_id = i.id)
         LEFT JOIN patron_import.ptype_mapping pt ON (pt.ptype = sp.patron_type AND pt.institution_id = i.id)
         LEFT JOIN patron_import.patron p2 ON BTRIM(sp.esid) = BTRIM(p2.externalsystemid) AND sp.institution_id = p2.institution_id

WHERE p2.id IS NULL
  AND sp.unique_id IS NOT NULL
  AND sp.unique_id != ''
  AND LOWER(sp.unique_id) NOT IN (SELECT BTRIM(LOWER(username)) FROM patron_import.patron where LOWER(username) = LOWER(sp.unique_id))

  AND sp.esid IS NOT NULL
  AND sp.esid != ''
  AND sp.load;
query_line
    $self->_runUpdateQuery($query);

    $query = <<'query_line';

UPDATE patron_import.patron p
SET
    file_id                = sp.file_id,
    job_id                 = sp.job_id,
    fingerprint            = sp.fingerprint,
    raw_data               = sp.raw_data,
    username               = BTRIM(sp.unique_id),
    externalsystemid       = BTRIM(sp.esid),
    barcode                = NULLIF(BTRIM(COALESCE(sp.barcode, $$$$)), $$$$),
    patrongroup            = pt.foliogroup,
    enrollmentdate         = (
                                CASE
                                    WHEN sp.enrollmentdate ~ '\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{4}' THEN sp.enrollmentdate::DATE::TEXT
                                    ELSE NULL
                                END
                            ),
    expirationdate         = (
                                CASE
                                    WHEN sp.expirationdate ~ '\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{4}' THEN sp.expirationdate::DATE::TEXT
                                    ELSE NULL
                                END
                            ),
    dateofbirth            = (
                                CASE
                                    WHEN sp.dateofbirth ~ '\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{4}' THEN sp.dateofbirth::DATE::TEXT
                                    ELSE NULL
                                END
                            ),
    email                  = BTRIM(sp.email_address),
    lastname               = BTRIM(sp.lastname),
    middlename             = BTRIM(sp.middlename),
    firstname              = BTRIM(sp.firstname),
    pronouns               = BTRIM(sp.pronouns),
    preferredfirstname     = NULLIF(BTRIM(COALESCE(sp.preferredfirstname, $$$$)), $$$$),
    phone                  = BTRIM(sp.telephone),
    mobilephone            = BTRIM(sp.telephone2),
    address1_one_liner     =
                            -- Address smasher "line1$line2$city, state zip"
                            (CASE WHEN sp.address1_line1 IS NOT NULL AND LENGTH(sp.address1_line1) > 1 THEN
                                regexp_replace(sp.address1_line1, $a$$$a$, $$$$, $$g$$) || $a$$$a$ ||
                                COALESCE(regexp_replace(sp.address1_line2, $a$$$a$, $$$$, $$g$$), $$$$) || $a$$$a$ ||
                                COALESCE(regexp_replace(sp.address1_city, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$, $a$ ||
                                COALESCE(regexp_replace(sp.address1_state, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$ $a$ ||
                                COALESCE(regexp_replace(sp.address1_zip, $a$[\$,]$a$, $$$$, $$g$$), $$$$)
                            ELSE
                                $$$$
                            END
                            ),
    address2_one_liner     =
                            -- Address smasher "line1$line2$city, state zip"
                            (CASE WHEN sp.address2_line1 IS NOT NULL AND LENGTH(sp.address2_line1) > 1 THEN
                                regexp_replace(sp.address2_line1, $a$$$a$, $$$$, $$g$$) || $a$$$a$ ||
                                COALESCE(regexp_replace(sp.address2_line2, $a$$$a$, $$$$, $$g$$), $$$$) || $a$$$a$ ||
                                COALESCE(regexp_replace(sp.address2_city, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$, $a$ ||
                                COALESCE(regexp_replace(sp.address2_state, $a$[\$,]$a$, $$$$, $$g$$), $$$$) || $a$ $a$ ||
                                COALESCE(regexp_replace(sp.address2_zip, $a$[\$,]$a$, $$$$, $$g$$), $$$$)
                            ELSE
                                $$$$
                            END
                            ),
    preferredcontacttypeid = $$email$$,
    departments            = sp.department,
    custom_fields          = sp.custom_fields,
    ready                  = TRUE,
    update_date            = NOW(),
FROM patron_import.!stagetable! sp
         JOIN patron_import.institution i ON (sp.institution_id = i.id)
         LEFT JOIN patron_import.ptype_mapping pt ON (pt.ptype = sp.patron_type AND pt.institution_id = i.id)
WHERE sp.fingerprint != p.fingerprint
  AND BTRIM(sp.esid) = BTRIM(p.externalsystemid)
  AND sp.institution_id = p.institution_id
  AND sp.unique_id != ''
  AND sp.unique_id is NOT NULL
  AND sp.load;

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

1;
