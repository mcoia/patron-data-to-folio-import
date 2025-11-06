package Parsers::MBTSParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;

# Midwestern Baptist Theological Seminary CSV parser
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
    print "MBTS CSV Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "MBTS CSV Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
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

                # Read CSV file (with BOM handling)
                my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
                open my $fh, "<:encoding(utf8)", $path or die "Cannot open $path: $!";

                # Read header row to get column indexes
                my $headers = $csv->getline($fh);

                # Strip UTF-8 BOM from first column name if present
                if ($headers && @$headers && $headers->[0]) {
                    $headers->[0] =~ s/^\x{FEFF}//;
                }

                $csv->column_names($headers);

                # Process each line in the CSV
                while (my $row = $csv->getline_hr($fh))
                {
                    print "Processing row: " . Dumper($row) if ($main::conf->{print2Console});

                    my $patron = $self->_parseCSVRow($row);

                    # skip if we didn't get a patron
                    next if (!defined($patron));

                    my $esidBuilder = Parsers::ESID->new($institution, $patron);

                    # Set the External System ID (already set to email in _parseCSVRow for MBTS)
                    # Only use ESID builder if email is empty
                    $patron->{esid} = $esidBuilder->getESID() if (!defined($patron->{esid}) || $patron->{esid} eq '');

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

    # MBTS CSV Format:
    # Line1: Fixed-length field (26 chars) with patron metadata
    # Line2-Line10: Tagged fields (first char is tag, rest is value)

    my $fixedField = $row->{Line1} || "";

    # Parse fixed-length field (Line1)
    # Format: 0067--  btg  --05-15-26 (26 chars)
    my $patronType = "";
    my $pcode1 = "";
    my $pcode2 = "";
    my $pcode3 = "";
    my $homeLibrary = "";
    my $patronMessageCode = "";
    my $patronBlockCode = "";
    my $expirationDate = "";

    try {
        # Patron Type: positions 1-3 (strip leading zeros)
        $patronType = substr($fixedField, 1, 3) + 0;

        # PCODE fields
        $pcode1 = substr($fixedField, 4, 1);
        $pcode2 = substr($fixedField, 5, 1);
        $pcode3 = substr($fixedField, 6, 3);

        # Home Library: positions 9-13 (5 chars)
        $homeLibrary = substr($fixedField, 9, 5);

        # Message and Block codes
        $patronMessageCode = substr($fixedField, 14, 1);
        $patronBlockCode = substr($fixedField, 15, 1);

        # Expiration Date: extract date pattern from end of field
        # Regex finds date in format mm-dd-yy or similar
        ($expirationDate) = $fixedField =~ /(\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4})\s*$/;
        $expirationDate ||= "";
    }
    catch {
        print "Warning: Error parsing fixed field: $fixedField\n" if ($main::conf->{print2Console});
    };

    # Helper function to strip tag and extract value
    my $stripTag = sub {
        my $field = shift || "";
        return "" if length($field) < 2;
        return substr($field, 1); # Strip first character (tag)
    };

    # Parse tagged fields from columns 2-10
    my $name = $stripTag->($row->{Line2});
    my $address = $stripTag->($row->{Line3});
    my $telephone = $stripTag->($row->{Line4});
    my $address2 = $stripTag->($row->{line5});
    my $telephone2 = $stripTag->($row->{line6});
    my $department = $stripTag->($row->{line7});
    my $uniqueId = $stripTag->($row->{line8});
    my $barcode = $stripTag->($row->{line9});
    my $email = $stripTag->($row->{line10});

    # Create patron hash
    my $patron = {
        'patron_type'            => $patronType,
        'pcode1'                 => $pcode1,
        'pcode2'                 => $pcode2,
        'pcode3'                 => $pcode3,
        'home_library'           => $homeLibrary,
        'patron_message_code'    => $patronMessageCode,
        'patron_block_code'      => $patronBlockCode,
        'patron_expiration_date' => $expirationDate,
        'name'                   => $name,
        'preferred_name'         => "",
        'address'                => $address,
        'telephone'              => $telephone,
        'address2'               => $address2,
        'telephone2'             => $telephone2,
        'department'             => "{}",
        'unique_id'              => $uniqueId,
        'barcode'                => $barcode,
        'email_address'          => $email,
        'note'                   => "",
        'esid'                   => $email,  # ESID = email for MBTS
        'custom_fields'          => "",
    };

    # Build raw_data for fingerprinting
    my $raw_data = "";
    foreach my $key (sort keys %$row)
    {
        $raw_data .= "$key: " . ($row->{$key} || "") . "\n";
    }
    $patron->{raw_data} = $raw_data;

    return $patron;
}

sub afterParse
{
    my $self = shift;
    print "MBTS CSV Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "MBTS CSV Parser finished\n" if ($main::conf->{print2Console} eq 'true');
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
