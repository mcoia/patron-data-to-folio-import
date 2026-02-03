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

    my $folderCount = scalar(@{$institution->{folders}});
    print "Starting parse for institution: $institution->{id}\n" if ($main::conf->{print2Console});
    $main::log->addLine("MVCParser: Starting parse for institution $institution->{id}, folder count: $folderCount");

    if ($folderCount == 0) {
        $main::log->addLine("MVCParser WARNING: No folders found for institution $institution->{id}");
    }

    my $folderIndex = 0;
    for my $folder (@{$institution->{folders}}) {
        $folderIndex++;
        my $fileCount = scalar(@{$folder->{files}});
        $main::log->addLine("MVCParser: Processing folder $folderIndex/$folderCount, file count: $fileCount");

        if ($fileCount == 0) {
            $main::log->addLine("MVCParser WARNING: No files found in folder $folderIndex");
        }

        for my $file (@{$folder->{files}}) {
            print "Processing file: $file->{name}\n" if ($main::conf->{print2Console});
            $main::log->addLine("MVCParser: Processing file: $file->{name}");

            my $patronCounter = 0;
            my $pathCount = scalar(@{$file->{'paths'}});
            $main::log->addLine("MVCParser: File has $pathCount path(s)");

            for my $path (@{$file->{'paths'}}) {
                my @rows = ();
                $main::log->addLine("MVCParser: Examining path: $path");

                # Read Excel file
                if ($path =~ /\.xlsx$/i) {
                    print "Reading Excel file: [$path]\n" if ($main::conf->{print2Console});
                    $main::log->addLine("MVCParser: Path matches xlsx pattern, reading Excel file");
                    @rows = $self->_readExcelFile($path);
                    $main::log->addLine("MVCParser: Read " . scalar(@rows) . " rows from Excel file");
                } else {
                    print "Skipping non-xlsx file: [$path]\n" if ($main::conf->{print2Console});
                    $main::log->addLine("MVCParser: SKIPPING non-xlsx file: $path");
                    next;
                }

                # Process each row
                my $rowIndex = 0;
                my $skippedNoPatron = 0;
                my $skippedNoEsid = 0;
                my $skippedEmptyEsid = 0;

                foreach my $row (@rows) {
                    $rowIndex++;
                    my $patron = $self->_parseRow($row, $rowIndex);

                    # skip if we didn't get a patron
                    if (!defined($patron)) {
                        $skippedNoPatron++;
                        next;
                    }

                    my $esidBuilder = Parsers::ESID->new($institution, $patron);

                    # Set the External System ID - use email address as ESID
                    $patron->{esid} = $patron->{email_address} || $esidBuilder->getESID();

                    # skip if we didn't get an esid
                    if (!defined($patron->{esid})) {
                        $main::log->addLine("MVCParser: Row $rowIndex SKIPPED - esid is undefined (barcode: $patron->{barcode}, email: $patron->{email_address})");
                        $skippedNoEsid++;
                        next;
                    }
                    if ($patron->{esid} eq '') {
                        $main::log->addLine("MVCParser: Row $rowIndex SKIPPED - esid is empty (barcode: $patron->{barcode}, email: $patron->{email_address})");
                        $skippedEmptyEsid++;
                        next;
                    }

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

                # Log skip summary for this path
                $main::log->addLine("MVCParser: Path processing complete - Rows: $rowIndex, Skipped(no patron): $skippedNoPatron, Skipped(no esid): $skippedNoEsid, Skipped(empty esid): $skippedEmptyEsid");
            }

            print "Total Patrons in $file->{name}: [$patronCounter]\n" if ($main::conf->{print2Console});
            $main::log->addLine("MVCParser: Total Patrons in $file->{name}: [$patronCounter]");
        }
    }

    print "Finished parsing institution: $institution->{id}\n" if ($main::conf->{print2Console});
    $main::log->addLine("MVCParser: Finished parsing institution $institution->{id}, total unique patrons: " . scalar(@parsedPatrons));

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

    # Log headers found
    my $headerList = join(", ", map { "'$_'" } @headers);
    $main::log->addLine("MVCParser: Excel headers found: [$headerList]");
    $main::log->addLine("MVCParser: Excel row range: $minRow to $maxRow (expected data rows: " . ($maxRow - $minRow) . ")");

    # Check for expected headers
    my %headerCheck = map { $_ => 1 } @headers;
    my @expectedHeaders = ('NAME', 'BAR CODE', 'PATRON CODE', 'EMAIL', 'Expiration Date', 'ID', 'calc1');
    my @foundHeaders = grep { $headerCheck{$_} } @expectedHeaders;
    my @missingHeaders = grep { !$headerCheck{$_} } @expectedHeaders;
    $main::log->addLine("MVCParser: Expected headers found: " . join(", ", @foundHeaders));
    $main::log->addLine("MVCParser: Expected headers missing: " . join(", ", @missingHeaders)) if @missingHeaders;

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
    my $rowIndex = shift || 0;

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

    # Log key fields for first few rows to help debugging
    if ($rowIndex <= 3) {
        $main::log->addLine("MVCParser: Row $rowIndex key fields - NAME='$nameField', BAR CODE='" . ($row->{'BAR CODE'} || '') . "', ID='" . ($row->{'ID'} || '') . "', PATRON CODE='" . ($row->{'PATRON CODE'} || '') . "', calc1='" . ($row->{'calc1'} || '') . "', EMAIL='$email'");
    }

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

    # Log expiration date for first few rows
    if ($rowIndex <= 3) {
        $main::log->addLine("MVCParser: Row $rowIndex expiration - raw='$expDate', parsed='$expirationDate'");
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
