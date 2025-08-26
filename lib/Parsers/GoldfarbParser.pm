package Parsers::GoldfarbParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;
use Spreadsheet::XLSX;

# Goldfarb CSV/Excel parser
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
    print "Goldfarb CSV/Excel Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "Goldfarb CSV/Excel Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
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
                my @rows = ();
                
                # Detect file type and read accordingly
                if ($path =~ /\.xlsx$/i) {
                    print "Reading Excel file: [$path]\n" if ($main::conf->{print2Console});
                    @rows = $self->_readExcelFile($path);
                } else {
                    print "Reading CSV file: [$path]\n" if ($main::conf->{print2Console});
                    @rows = $self->_readCSVFile($path);
                }

                # Process each row
                foreach my $row (@rows) {
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

sub _readExcelFile
{
    my $self = shift;
    my $path = shift;
    my @rows = ();
    
    # Read Excel file
    my $excel = Spreadsheet::XLSX->new($path);
    unless ($excel) {
        die "Cannot open Excel file: $path";
    }
    
    # Get the first worksheet
    my $worksheet = $excel->{Worksheet}->[0];
    unless ($worksheet) {
        die "No worksheet found in Excel file: $path";
    }
    
    # Get the range of data
    my $minRow = $worksheet->{MinRow};
    my $maxRow = $worksheet->{MaxRow};
    my $minCol = $worksheet->{MinCol};
    my $maxCol = $worksheet->{MaxCol};
    
    # Read header row (first row)
    my @headers = ();
    for my $col ($minCol .. $maxCol) {
        my $cell = $worksheet->{Cells}->[$minRow]->[$col];
        my $header = $cell ? $cell->{Val} : "";
        push @headers, $header;
    }
    
    # Read data rows
    for my $row (($minRow + 1) .. $maxRow) {
        my %rowData = ();
        for my $col ($minCol .. $maxCol) {
            my $cell = $worksheet->{Cells}->[$row]->[$col];
            my $value = $cell ? $cell->{Val} : "";
            my $header = $headers[$col - $minCol];
            $rowData{$header} = $value if defined $header;
        }
        push @rows, \%rowData if %rowData;
    }
    
    return @rows;
}

sub _parseCSVRow
{
    my $self = shift;
    my $row = shift;

    # Get name components from separate fields
    my $lastName = $row->{'Last Name'} || "";
    my $firstName = $row->{'First Name'} || "";
    my $middleInitial = $row->{'Middle Initial'} || "";
    
    # Clean up name components
    $lastName =~ s/^\s+|\s+$//g;
    $firstName =~ s/^\s+|\s+$//g;
    $middleInitial =~ s/^\s+|\s+$//g;

    # Build full name in "Last, First Middle" format
    my $fullName = $lastName;
    if ($firstName) {
        $fullName .= ", $firstName";
        if ($middleInitial) {
            $fullName .= " $middleInitial";
        }
    }

    # Get address components - prefer campus address, fall back to home address
    my $address = "";
    my $campusAddress = $row->{'Campus Address'} || "";
    my $campusCity = $row->{'City'} || "";
    my $campusState = $row->{'State'} || "";
    my $campusZip = $row->{'Zip'} || "";
    
    my $homeAddress = $row->{'Home Address'} || "";
    my $homeCity = $row->{'City_1'} || "";
    my $homeState = $row->{'State_1'} || "";
    my $homeZip = $row->{'Zip_1'} || "";

    # Use campus address if available, otherwise home address
    if ($campusAddress || $campusCity || $campusState || $campusZip) {
        $address = join(" ", grep {$_} ($campusAddress, $campusCity, $campusState, $campusZip));
    } elsif ($homeAddress || $homeCity || $homeState || $homeZip) {
        $address = join(" ", grep {$_} ($homeAddress, $homeCity, $homeState, $homeZip));
    }

    # Get other fields
    my $patronType = $row->{'Patron Type'} || "";
    my $expirationDate = $row->{'Expiration Date'} || "";
    my $telephone = $row->{'Telephone Number'} || "";
    my $uniqueId = $row->{'Unique ID Number'} || "";
    my $universityId = $row->{'University ID'} || "";
    my $barcode = $row->{'Barcode'} || "";
    my $email = $row->{'E-mail Address'} || "";
    my $note = $row->{'Note'} || "";
    my $homeLibrary = $row->{'Home Libray'} || "";  # Note: matches CSV header spelling
    my $upn = $row->{'User Principal Name (UPN)'} || "";

    # Create patron hash
    my $patron = {
        'patron_type'            => $patronType,
        'pcode1'                 => "",
        'pcode2'                 => "",
        'pcode3'                 => "",
        'home_library'           => $homeLibrary,
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
        'note'                   => $note,
        'esid'                   => $universityId,
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
    print "Goldfarb CSV/Excel Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "Goldfarb CSV/Excel Parser finished\n" if ($main::conf->{print2Console} eq 'true');
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