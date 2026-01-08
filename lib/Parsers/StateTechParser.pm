package Parsers::StateTechParser;
use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Data::Dumper;
use Try::Tiny;
use Spreadsheet::XLSX;
use Parsers::ESID;
use MOBIUS::Utils;

# State Tech CSV/Excel parser
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
    print "State Tech CSV/Excel Parser initialized\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub beforeParse
{
    my $self = shift;
    print "State Tech CSV/Excel Parser starting parse\n" if ($main::conf->{print2Console} eq 'true');
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
                    # print "Processing row: " . Dumper($row) if ($main::conf->{print2Console});

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

sub _parseCSVRow
{
    my $self = shift;
    my $row = shift;

    # Helper to convert literal "NULL" string to empty string
    my $sanitize = sub {
        my $value = shift;
        return "" unless defined $value;
        return "" if ($value eq "NULL" || $value eq "null");
        return $value;
    };

    # Parse the name from fullname field
    my $fullname = $sanitize->($row->{fullname});
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

    # Parse Sierra "0 line" format from PTYPE & Expiration field
    my $zeroLine = $row->{'PTYPE & Expiration'} || $row->{'Expiration Date'} || "";
    
    # Extract patron info from Sierra "0 line" format using substr operations
    my ($patronType, $pcode1, $pcode2, $pcode3, $homeLibrary, $patronMessageCode, $patronBlockCode, $expirationDate) = ("", "", "", "", "", "", "", "");
    
    # Check if this is State Tech hybrid format (e.g. "0061l-000lsb  --05/17/2026")
    # This format follows standard Sierra positions 0-15, but uses extended date format
    if ($zeroLine =~ /^0\d{3}l/) {
        # State Tech hybrid format: follows standard Sierra positions 0-15,
        # but uses extended date format (mm/dd/yyyy instead of mm-dd-yy)

        # Clean the data first
        $zeroLine =~ s/^\s*//g;
        $zeroLine =~ s/\s*$//g;
        $zeroLine =~ s/\n//g;
        $zeroLine =~ s/\r//g;

        # Parse using standard Sierra positions (0-15)
        eval {
            $patronType = substr($zeroLine, 1, 3) + 0;  # Positions 1-3, convert to number
        };

        eval {
            $pcode1 = substr($zeroLine, 4, 1);  # Position 4
        };

        eval {
            $pcode2 = substr($zeroLine, 5, 1);  # Position 5
        };

        eval {
            $pcode3 = substr($zeroLine, 6, 3);  # Positions 6-8
        };

        eval {
            $homeLibrary = substr($zeroLine, 9, 5);  # Positions 9-13
        };

        eval {
            $patronMessageCode = substr($zeroLine, 14, 1);  # Position 14
        };

        eval {
            $patronBlockCode = substr($zeroLine, 15, 1);  # Position 15
        };

        # Extract expiration date using regex (non-standard format at end)
        # Handles mm/dd/yyyy, mm-dd-yy, or similar formats
        eval {
            ($expirationDate) = $zeroLine =~ /(\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4})\s*$/;
            $expirationDate ||= "";
        };

    } elsif ($zeroLine =~ /^0/) {
        # New "Sierra Zero Line" parsing logic
        
        # Clean the data first
        $zeroLine =~ s/^\s*//g;
        $zeroLine =~ s/\s*$//g; 
        $zeroLine =~ s/\n//g;
        $zeroLine =~ s/\r//g;
        
        # Parse using substr operations (following SierraParser pattern)
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
        
        # Extract expiration date using regex (from end of string)
        eval {
            ($expirationDate) = $zeroLine =~ /(\d{1,2}[\-\/\.]\d{1,2}[\-\/\.]\d{2,4})\s*$/;
            $expirationDate ||= "";
        };
    }

    # Parse address components
    my $address = $sanitize->($row->{address});
    my ($street, $cityStateZip) = ("", "");
    if ($address =~ /^([^\$]+)\$(.+)$/) {
        $street = $1;
        $cityStateZip = $2;
    } else {
        $street = $address;
    }

    # Create patron hash with properly parsed Sierra format fields
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
        'address'                => $street,
        'telephone'              => $sanitize->($row->{mobilephone}),
        'address2'               => $cityStateZip,
        'telephone2'             => "",
        'department'             => "{}",
        'unique_id'              => $sanitize->($row->{username}) || $sanitize->($row->{uniqueid}) || $sanitize->($row->{emailaddress}),
        'barcode'                => $sanitize->($row->{Barcode}) || $sanitize->($row->{'Student ID Barcode Number'}),
        'email_address'          => $sanitize->($row->{emailaddress}),
        'note'                   => "",
        'esid'                   => $sanitize->($row->{externalID}),
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
    print "State Tech CSV/Excel Parser completed parse\n" if ($main::conf->{print2Console} eq 'true');
    return $self;
}

sub finish
{
    my $self = shift;
    print "State Tech CSV/Excel Parser finished\n" if ($main::conf->{print2Console} eq 'true');
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