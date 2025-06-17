package Parsers::StateTechParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;

# State Tech CSV parser
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
    print "State Tech CSV Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "State Tech CSV Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
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
                        unless (grep /$patron->{fingerprint}/, map {$_->{fingerprint}} @parsedPatrons);
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

    # Parse the name from fullname field
    my $fullname = $row->{fullname} || "";
    $fullname =~ s/^\s+|\s+$//g; # Trim whitespace
    
    # Parse name components from "Last, First Middle" format
    my ($lastName, $firstName, $middleName) = ("", "", "");
    if ($fullname =~ /^([^,]+),\s*(.+)$/) {
        $lastName = $1;
        my $firstAndMiddle = $2;
        $firstAndMiddle =~ s/^\s+|\s+$//g;
        
        # Split first and middle names
        my @nameParts = split(/\s+/, $firstAndMiddle);
        $firstName = shift @nameParts || "";
        $middleName = join(" ", @nameParts);
    }

    # Parse expiration date from the Expiration Date field
    my $expirationDate = "";
    if ($row->{'Expiration Date'} && $row->{'Expiration Date'} =~ /--(\d+\/\d+\/\d+)/) {
        $expirationDate = $1;
    }

    # Parse patron type from Expiration Date field (first part before 'l')
    my $patronType = "";
    if ($row->{'Expiration Date'} && $row->{'Expiration Date'} =~ /^(\d+)l/) {
        $patronType = $1;
        $patronType =~ s/^0+(\d+)$/$1/; # Remove leading zeros
    }

    # Parse address components
    my $address = $row->{address} || "";
    my ($street, $cityStateZip) = ("", "");
    if ($address =~ /^([^\$]+)\$(.+)$/) {
        $street = $1;
        $cityStateZip = $2;
    } else {
        $street = $address;
    }

    # Create patron hash with the same structure as in SierraParser
    my $patron = {
        'patron_type'            => $patronType,
        'pcode1'                 => substr($row->{dlsb} || "", 0, 1) || "",
        'pcode2'                 => substr($row->{dlsb} || "", 1, 1) || "",
        'pcode3'                 => substr($row->{dlsb} || "", 2, 3) || "",
        'home_library'           => "",
        'patron_message_code'    => "",
        'patron_block_code'      => "",
        'patron_expiration_date' => $expirationDate,
        'name'                   => join(", ", grep {$_} ($lastName, $firstName, $middleName)),
        'preferred_name'         => "",
        'address'                => $street,
        'telephone'              => $row->{mobilephone} || "",
        'address2'               => $cityStateZip,
        'telephone2'             => "",
        'department'             => "{}",
        'unique_id'              => $row->{uniqueid} || "",
        'barcode'                => $row->{'Student ID Barcode Number'} || "",
        'email_address'          => $row->{emailaddress} || "",
        'note'                   => "",
        'esid'                   => $row->{externalID} || "",
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
    print "State Tech CSV Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "State Tech CSV Parser finished\n" if ($main::conf->{print2Console} eq 'true');
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