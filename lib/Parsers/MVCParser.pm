package Parsers::MVCParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;
use Spreadsheet::XLSX;
use Parsers::ESID;
use MOBIUS::Utils;

# Missouri Valley College XLSX parser
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
    print "Missouri Valley College Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "Missouri Valley College Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub parse
{
    my $self = shift;
    my $institution = $self->{institution};
    my @parsedPatrons = ();

    print "Starting parse for institution: $institution->{id}\n" if ($main::conf->{print2Console});

    for my $folder (@{$institution->{folders}}) {
        for my $file (@{$folder->{files}}) {
            print "Processing file: $file->{name}\n" if ($main::conf->{print2Console});

            my $patronCounter = 0;
            for my $path (@{$file->{'paths'}}) {
                my @rows = ();

                # Read Excel file
                if ($path =~ /\.xlsx$/i) {
                    print "Reading Excel file: [$path]\n" if ($main::conf->{print2Console});
                    @rows = $self->_readExcelFile($path);
                } else {
                    print "Skipping non-xlsx file: [$path]\n" if ($main::conf->{print2Console});
                    next;
                }

                # Process each row
                foreach my $row (@rows) {
                    my $patron = $self->_parseRow($row);

                    # skip if we didn't get a patron
                    next if (!defined($patron));

                    my $esidBuilder = Parsers::ESID->new($institution, $patron);

                    # Set the External System ID - use email address as ESID
                    $patron->{esid} = $patron->{email_address} || $esidBuilder->getESID();

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

                    # We need to check this list for double entries - use exact string comparison
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
        # Clean up header
        $header =~ s/&amp;/&/g;
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

sub _parseRow
{
    my $self = shift;
    my $row = shift;

    # Parse the name from "NAME" column - format is "Last,First" (no space after comma)
    my $nameField = $row->{'NAME'} || "";
    my ($lastName, $firstName) = split(/,/, $nameField, 2);
    $lastName = $lastName || "";
    $firstName = $firstName || "";

    # Trim whitespace
    $lastName =~ s/^\s+|\s+$//g;
    $firstName =~ s/^\s+|\s+$//g;

    # Get barcode - Student files have "BAR CODE", Staff files use "ID" (col 17)
    # Since both files have ID at col 0, we need to check BAR CODE first
    my $barcode = $row->{'BAR CODE'} || $row->{'ID'} || "";
    $barcode =~ s/^\s+|\s+$//g;

    # Get patron type - Student files have "PATRON CODE", Staff files have "calc1"
    my $patronType = $row->{'PATRON CODE'} || $row->{'calc1'} || "";
    $patronType =~ s/^\s+|\s+$//g;

    # Get email
    my $email = $row->{'EMAIL'} || "";
    $email =~ s/^\s+|\s+$//g;

    # Get address - Student files have "PERM_ADDRESS", Staff files have "ODS_ADDRESS.ADDRESS_LINE_1"
    my $address = $row->{'PERM_ADDRESS'} || $row->{'ODS_ADDRESS.ADDRESS_LINE_1'} || "";
    $address =~ s/^\s+|\s+$//g;

    # Build city/state/zip
    my $city = $row->{'PERM_CITY'} || "";
    my $state = $row->{'PERM_ST'} || "";
    my $zip = $row->{'PERM_ZIP'} || "";
    $city =~ s/^\s+|\s+$//g;
    $state =~ s/^\s+|\s+$//g;
    $zip =~ s/^\s+|\s+$//g;

    my $cityStateZip = "";
    if ($city || $state || $zip) {
        $cityStateZip = join(", ", grep {$_} ($city, $state)) . " " . $zip;
        $cityStateZip =~ s/^\s+|\s+$//g;
    }

    # Build phone number from area code (PERM) and number (PERM_PHONE)
    my $areaCode = $row->{'PERM'} || "";
    my $phoneNumber = $row->{'PERM_PHONE'} || "";
    $areaCode =~ s/^\s+|\s+$//g;
    $phoneNumber =~ s/^\s+|\s+$//g;

    my $telephone = "";
    if ($areaCode && $phoneNumber) {
        $telephone = "$areaCode-$phoneNumber";
    } elsif ($phoneNumber) {
        $telephone = $phoneNumber;
    }

    # Read expiration date from file
    my $expDate = $row->{'Expiration Date'} || "";
    $expDate =~ s/^\s+|\s+$//g;

    my $expirationDate = "";
    if ($expDate =~ m|^(\d{2})/(\d{2})/(\d{4})$|) {
        my ($month, $day, $year) = ($1, $2, $3);
        $expirationDate = sprintf("%02d-%02d-%02d", $month, $day, $year % 100);
    }

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
        'name'                   => join(", ", grep {$_} ($lastName, $firstName)),
        'preferred_name'         => "",
        'address'                => $address,
        'telephone'              => $telephone,
        'address2'               => $cityStateZip,
        'telephone2'             => "",
        'department'             => "{}",
        'unique_id'              => $barcode . "mvc",
        'barcode'                => $barcode,
        'email_address'          => $email,
        'note'                   => "",
        'esid'                   => "",
        'custom_fields'          => "",
    };

    # Build raw_data for fingerprinting
    my $raw_data = "";
    foreach my $key (sort keys %$row) {
        $raw_data .= "$key: " . ($row->{$key} || "") . "\n";
    }
    $patron->{raw_data} = $raw_data;

    return $patron;
}

sub afterParse
{
    my $self = shift;
    print "Missouri Valley College Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "Missouri Valley College Parser finished\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub getPatronFingerPrint
{
    my $self = shift;
    my $patron = shift;
    return MOBIUS::Utils->new()->getHash($patron);
}

1;
