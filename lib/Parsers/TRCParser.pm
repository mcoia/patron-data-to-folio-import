package Parsers::TRCParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;

# Three Rivers College CSV parser
use parent 'Parsers::ParserInterface';

sub new
{
    my $class = shift;
    my $self = {
        institution => shift,
    };
    bless $self, $class;
    return $self;
}

sub onInit
{
    my $self = shift;
    print "TRC CSV Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "TRC CSV Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub parse
{
    my $self = shift;
    my $institution = $self->{institution};
    my @parsedPatrons = ();

    print "Starting parse for institution: $institution->{id}\n" if ($main::conf->{print2Console});

    for my $folder (@{$institution->{folders}})
    {
        for my $file (@{$folder->{files}})
        {
            print "Processing file: $file->{name}\n" if ($main::conf->{print2Console});

            my $patronCounter = 0;
            for my $path (@{$file->{'paths'}})
            {
                print "Reading CSV file: [$path]\n" if ($main::conf->{print2Console});

                # Read CSV file
                my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
                open my $fh, "<:encoding(utf8)", $path or die "Cannot open $path: $!";

                # Read header row to get column indexes
                my $headers = $csv->getline($fh);
                $csv->column_names($headers);

                # Process each line in the CSV
                while (my $row = $csv->getline_hr($fh))
                {
                    print "Processing row: " . Dumper($row) if ($main::conf->{print2Console});

                    my $patron = $self->_parseCSVRow($row);

                    # skip if we didn't get a patron
                    next if (!defined($patron));

                    my $esidBuilder = Parsers::ESID->new($institution, $patron);

                    # Set the External System ID
                    $patron->{esid} = $row->{esid} || $esidBuilder->getESID();

                    # skip if we didn't get an esid
                    next if (!defined($patron->{esid}));
                    next if ($patron->{esid} eq '');

                    # Note, everything in the patron hash gets 'fingerprinted'
                    $patron->{fingerprint} = $main::parserManager->getPatronFingerPrint($patron);

                    # set some id's, I decided I needed these for tracking down trash
                    $patron->{load} = 'true';
                    $patron->{institution_id} = $institution->{id};
                    $patron->{job_id} = $main::jobID;
                    $patron->{file_id} = $main::dao->getFileTrackerIDByJobIDAndFilePath($path);

                    # We need to check this list for double entries
                    push(@parsedPatrons, $patron)
                        unless (grep { $_ eq $patron->{fingerprint} } map {$_->{fingerprint}} @parsedPatrons);
                    $patronCounter++;
                }

                close $fh;
            }

            print "Total Patrons in $file->{name}: [$patronCounter]\n" if ($main::conf->{print2Console});
            $main::log->addLine("Total Patrons in $file->{name}: [$patronCounter]\n");
        }
    }

    print "Finished parsing institution: $institution->{id}\n" if ($main::conf->{print2Console});

    $self->{parsedPatrons} = \@parsedPatrons;
    return \@parsedPatrons;
}

sub _parseCSVRow
{
    my $self = shift;
    my $row = shift;

    # Strip leading zeros from patronType - using explicit string manipulation
    my $patronType = $row->{patronType} || "";
    $patronType =~ s/^0+(\d+)$/$1/; # This regex explicitly removes leading zeros

    # Create patron hash with the same structure as in SierraParser
    my $patron = {
        'patron_type'            => $patronType,
        'pcode1'                 => substr($row->{text} || "", 0, 1) || "",
        'pcode2'                 => substr($row->{text} || "", 1, 1) || "",
        'pcode3'                 => substr($row->{text} || "", 2, 3) || "",
        'home_library'           => substr($row->{text} || "", 5, 5) || "",
        'patron_message_code'    => "",
        'patron_block_code'      => "",
        'patron_expiration_date' => $row->{expirationDate} || "",
        'name'                   => join(", ", grep {$_} ($row->{lastName}, $row->{firstName}, $row->{middleName})),
        'preferred_name'         => "",
        'address'                => $row->{address} || "",
        'telephone'              => "",
        'address2'               => $row->{cityStateZip} || "",
        'telephone2'             => "",
        'department'             => "{}",
        'unique_id'              => $row->{username} || "",
        'barcode'                => $row->{barcode} || "",
        'email_address'          => $row->{emailAddress} || "",
        'note'                   => "",
        'esid'                   => $row->{esid} || "",
        'custom_fields'          => "",
    };

    # Build raw_data for fingerprinting
    my $raw_data = "";
    foreach my $key (sort keys %$row)
    {
        # Here we're showing the original, unmodified row data
        $raw_data .= "$key: " . ($row->{$key} || "") . "\n";
    }
    $patron->{raw_data} = $raw_data;

    return $patron;
}

sub afterParse
{
    my $self = shift;
    print "TRC CSV Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "TRC CSV Parser finished\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub getPatronFingerPrint
{
    # On the off chance this getHash() function doesn't work as expected we
    # can just update this method to point to something else.
    my $self = shift;
    my $patron = shift;
    return MOBIUS::Utils->new()->getHash($patron);
}

1;
