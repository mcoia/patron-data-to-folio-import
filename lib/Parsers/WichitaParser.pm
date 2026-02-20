package Parsers::WichitaParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;

# Wichita State University CSV parser
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
    print "Wichita CSV Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "Wichita CSV Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
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
                my @rows = $self->_readCSVFile($path);

                # Process each row
                foreach my $row (@rows) {
                    # print "Processing row: " . Dumper($row) if ($main::conf->{print2Console});

                    my $patron = $self->_parseCSVRow($row);

                    # skip if we didn't get a patron
                    next if (!defined($patron));

                    # Use ESID directly from CSV (as per user request)
                    $patron->{esid} = $row->{esid} || "";

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

                    # We need to check this list for double entries - FIX: use exact string comparison
                    push(@parsedPatrons, $patron)
                        unless (grep { $_ eq $patron->{fingerprint} } map {$_->{fingerprint}} @parsedPatrons);
                    $patronCounter++;
                }
            }

            print "Total Patrons in $file->{name}: [$patronCounter]\n" if ($main::conf->{print2Console});
            $main::log->addLine("Total Patrons in $file->{name}: [$patronCounter]\n");
        }
    }

    print "Finished parsing institution: $institution->{id}\n" if ($main::conf->{print2Console});

    $self->{parsedPatrons} = \@parsedPatrons;
    return \@parsedPatrons;
}

sub _readCSVFile
{
    my $self = shift;
    my $path = shift;
    my @rows = ();

    # Read CSV file
    my $csv = Text::CSV->new({ binary => 1, auto_diag => 1 });
    open my $fh, "<:encoding(utf8)", $path or die "Cannot open $path: $!";

    # Read header row to get column indexes
    my $headers = $csv->getline($fh);
    $csv->column_names($headers);

    # Process each line in the CSV
    while (my $row = $csv->getline_hr($fh)) {
        push @rows, $row;
    }

    close $fh;
    return @rows;
}

sub _parseCSVRow
{
    my $self = shift;
    my $row = shift;

    # Get name components from separate fields
    my $lastName = $row->{'lastName'} || "";
    my $firstName = $row->{'firstName'} || "";
    my $middleName = $row->{'middleName'} || "";

    # Clean up name components - normalize empty placeholders
    $lastName =~ s/^\s+|\s+$//g;
    $firstName =~ s/^\s+|\s+$//g;
    $middleName =~ s/^\s+|\s+$//g;

    # Build full name in "Last, First Middle" format
    my $fullName = $lastName;
    if ($firstName) {
        $fullName .= ", $firstName";
        if ($middleName) {
            $fullName .= " $middleName";
        }
    }

    # Get address components and combine them
    my $addressLine = $row->{'address'} || "";
    my $city = $row->{'city'} || "";
    my $state = $row->{'state'} || "";
    my $zip = $row->{'zip'} || "";

    # Clean up address components
    $addressLine =~ s/^\s+|\s+$//g;
    $city =~ s/^\s+|\s+$//g;
    $state =~ s/^\s+|\s+$//g;
    $zip =~ s/^\s+|\s+$//g;

    # Combine address components into single address field
    my $address = join(" ", grep {$_ && $_ ne ''} ($addressLine, $city, $state, $zip));

    # Get other fields
    my $patronType = $row->{'patronType'} || "";
    my $expirationDate = $row->{'expirationDate'} || "";
    my $telephone = $row->{'phoneNumber'} || "";
    my $uniqueId = $row->{'username'} || "";
    my $barcode = $row->{'barcode'} || "";
    my $email = $row->{'emailAddress'} || "";

    # Clean up fields - normalize empty placeholders
    $patronType =~ s/^\s+|\s+$//g;
    $expirationDate =~ s/^\s+|\s+$//g;

    # Convert YYYY-MM-DD to MM-DD-YY format (CSV has ISO format, migrate.sql needs MM-DD-YY)
    if ($expirationDate =~ m{^(\d{4})-(\d{2})-(\d{2})$}) {
        my ($year, $month, $day) = ($1, $2, $3);
        $expirationDate = sprintf("%02d-%02d-%02d", $month, $day, $year % 100);
    }

    $telephone =~ s/^\s+|\s+$//g;
    $uniqueId =~ s/^\s+|\s+$//g;
    $barcode =~ s/^\s+|\s+$//g;
    $email =~ s/^\s+|\s+$//g;

    # Create patron hash
    my $patron = {
        'patron_type'            => $patronType,
        'pcode1'                 => "",
        'pcode2'                 => "",
        'pcode3'                 => "",
        'home_library'           => "",
        'patron_message_code'    => "",
        'patron_block_code'      => "",
        'patron_expiration_date' => $expirationDate,
        'name'                   => $fullName,
        'preferred_name'         => "",
        'address'                => $address,
        'telephone'              => $telephone,
        'address2'               => "",
        'telephone2'             => "",
        'department'             => "{}",
        'unique_id'              => $uniqueId,
        'barcode'                => $barcode,
        'email_address'          => $email,
        'note'                   => "",
        'esid'                   => "",  # Will be set in parse() method
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
    print "Wichita CSV Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "Wichita CSV Parser finished\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

# I really should have an abstract class that this method lives in and we extend the ParserInterface. ???
sub getPatronFingerPrint
{
    # On the off chance this getHash() function doesn't work as expected we
    # can just update this method to point to something else.
    my $self = shift;
    my $patron = shift;
    return MOBIUS::Utils->new()->getHash($patron);
}

1;
