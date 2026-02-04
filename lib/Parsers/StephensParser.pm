package Parsers::StephensParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;
use Spreadsheet::XLSX;
use Parsers::ESID;
use MOBIUS::Utils;

# Stephens College CSV/Excel parser
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
    print "Stephens College Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "Stephens College Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
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
                    # print "Processing row: " . Dumper($row) if ($main::conf->{print2Console});

                    my $patron = $self->_parseRow($row);

                    # skip if we didn't get a patron
                    next if (!defined($patron));

                    my $esidBuilder = Parsers::ESID->new($institution, $patron);

                    # Set the External System ID
                    $patron->{esid} = $row->{'External ID'} || $esidBuilder->getESID();

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
        # Handle potential XML/HTML entities in header if necessary, though Spreadsheet::XLSX usually handles basic ones.
        # But based on inspect_xlsx.pl output, we might see encoded chars.
        # Let's clean up the header just in case.
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

    # Parse the name from "Last Name" and "First Name" columns
    my $lastName = $row->{'Last Name'} || "";
    my $firstName = $row->{'First Name'} || "";
    my $middleName = "";

    # Trim whitespace
    $lastName =~ s/^\s+|\s+$//g;
    $firstName =~ s/^\s+|\s+$//g;

    # Parse Sierra "0 line" format from "Patron Group" field
    my $zeroLine = $row->{'Patron Group'} || "";
    
    # Extract patron info from Sierra "0 line" format using substr operations
    my ($patronType, $pcode1, $pcode2, $pcode3, $homeLibrary, $patronMessageCode, $patronBlockCode, $expirationDate) = ("", "", "", "", "", "", "", "");
    
    if ($zeroLine =~ /^0/) {
        # Clean the data first
        $zeroLine =~ s/^\s*//g;
        $zeroLine =~ s/\s*$//g; 
        $zeroLine =~ s/\n//g;
        $zeroLine =~ s/\r//g;
        
        # Parse using substr operations
        eval {
            $patronType = substr($zeroLine, 1, 3) + 0;  # Convert to number, removes leading zeros
        };
        
        eval {
            $pcode1 = substr($zeroLine, 4, 1);
        };
        
        eval {
            $pcode2 = substr($zeroLine, 5, 1);
        };
        
        eval {
            $pcode3 = substr($zeroLine, 6, 3);
        };
        
        eval {
            $homeLibrary = substr($zeroLine, 9, 5);
        };
        
        eval {
            $patronMessageCode = substr($zeroLine, 14, 1);
        };
        
        eval {
            $patronBlockCode = substr($zeroLine, 15, 1);
        };
        
        # Get expiration date from separate "Expiration" column
        $expirationDate = $row->{'Expiration'} || "";
    }

    # Get the full address - keep the $ delimiter intact for database trigger parsing
    # The $ character is a line break delimiter in Sierra addresses (see SierraParser line 460)
    my $address = $row->{address} || "";

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
        'name'                   => join(", ", grep {$_} ($lastName, $firstName, $middleName)),
        'preferred_name'         => "",
        'address'                => $address,  # Keep full address with $ delimiter for DB trigger
        'telephone'              => $row->{mobilephone} || "",
        'address2'               => "",        # Only for separate second address if provided
        'telephone2'             => "",
        'department'             => "{}",
        'unique_id'              => $row->{'Email'} || "",
        'barcode'                => $row->{'Barcode'} || "",
        'email_address'          => $row->{'Email'} || "",
        'note'                   => "",
        'esid'                   => $row->{'External ID'} || "",
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
    print "Stephens College Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "Stephens College Parser finished\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub getPatronFingerPrint
{
    my $self = shift;
    my $patron = shift;
    return MOBIUS::Utils->new()->getHash($patron);
}

1;
