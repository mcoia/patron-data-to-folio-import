#!/usr/bin/perl
use strict;
use warnings;
use DBI;
use Getopt::Long;
use Data::Dumper;
use Try::Tiny;

# Main execution
main();

sub main {
    my $filename = getFilename();
    my $dbh = connectToDatabase();
    my $jobId = createJob($dbh);
    processFile($filename, $dbh, $jobId);
    updateJobStopTime($dbh, $jobId);
    finalize($dbh);
}

# Get filename from command line
sub getFilename {
    my $filename;
    GetOptions("file=s" => \$filename) or die "Usage: $0 --file=filename\n";
    die "Usage: $0 --file=filename\n" unless $filename;
    print "Starting patron import process for file: $filename\n";
    return $filename;
}

# Connect to the database
sub connectToDatabase {
    my $dbhost = 'localhost';
    my $db = 'postgres';
    my $dbuser = 'postgres';
    my $dbpass = 'postgres';
    my $port = 5432;

    print "Connecting to database...\n";
    my $dsn = "DBI:Pg:dbname=$db;host=$dbhost;port=$port";
    my $dbh = DBI->connect($dsn, $dbuser, $dbpass, { RaiseError => 1, AutoCommit => 0 })
        or die "Could not connect to database: $DBI::errstr";
    print "Connected to database successfully.\n";
    return $dbh;
}

# Create a new job record
sub createJob {
    my ($dbh) = @_;
    print "Creating job record...\n";
    my $sth = $dbh->prepare("INSERT INTO patron_import.job (job_type, start_time) VALUES ('patron_import', NOW()) RETURNING id");
    $sth->execute();
    my ($jobId) = $sth->fetchrow_array();
    print "Job record created with ID: $jobId\n";
    return $jobId;
}

# Process the input file
sub processFile {
    my ($filename, $dbh, $jobId) = @_;

    open(my $fh, '<', $filename) or die "Could not open file '$filename': $!";
    print "File opened successfully.\n";

    my $sth = prepareInsertStatement($dbh);

    my @patronRecord;
    my $patronCount = 0;

    print "Starting to process patron records...\n";
    while (my $line = <$fh>) {
        chomp $line;

        if ($line =~ /^0/ && @patronRecord) {
            my $patron = parsePatronRecord(\@patronRecord);
            if ($patron) {
                insertPatron($patron, $sth, $jobId);
                $patronCount++;
            }
            @patronRecord = ();
        }

        push @patronRecord, $line;
    }

    # Process the last patron record
    if (@patronRecord) {
        my $patron = parsePatronRecord(\@patronRecord);
        if ($patron) {
            insertPatron($patron, $sth, $jobId);
            $patronCount++;
        }
    }

    close($fh);
    print "Finished processing patron records. Total records processed: $patronCount\n";
}

# Parse patron record
sub parsePatronRecord {
    my ($patronRecord) = @_;
    my $isParsed = 1;

    my $patron = {
        'patron_type'            => "",
        'pcode1'                 => "",
        'pcode2'                 => "",
        'pcode3'                 => "",
        'home_library'           => "",
        'patron_message_code'    => "",
        'patron_block_code'      => "",
        'patron_expiration_date' => "",
        'name'                   => "",
        'address'                => "",
        'telephone'              => "",
        'address2'               => "",
        'telephone2'             => "",
        'department'             => "",
        'unique_id'              => "",
        'barcode'                => "",
        'email_address'          => "",
        'note'                   => "",
        'esid'                   => "",
        'preferred_name'         => "",
    };

    for my $data (@{$patronRecord}) {
        $data =~ s/^\s*//g if ($data =~ /^0/);
        $data =~ s/\s*$//g if ($data =~ /^0/);
        $data =~ s/\n//g if ($data =~ /^0/);
        $data =~ s/\r//g if ($data =~ /^0/);

        if ($data =~ /^0/) {
            $patron->{'field_code'} = '0';

            try {
                $patron->{'patron_type'} = substr($data, 1, 3) + 0;
            } catch {
                try {
                    $patron->{'patron_type'} = ($data =~ /^0(\d{3}).*/gm)[0] + 0;
                } catch {
                    print "Failed to parse patron_type: [$data]\n";
                    $isParsed = 0;
                };
            };

            # Similar try-catch blocks for other fixed-length fields...
            # (pcode1, pcode2, pcode3, home_library, patron_message_code, patron_block_code, patron_expiration_date)

        } elsif ($data =~ /^n/) { $patron->{'name'} = ($data =~ /^n(.*)$/gm)[0]; }
        elsif ($data =~ /^a/) { $patron->{'address'} = ($data =~ /^a(.*)$/gm)[0]; }
        elsif ($data =~ /^h/) { $patron->{'address2'} = ($data =~ /^h(.*)$/gm)[0]; }
        elsif ($data =~ /^t/) { $patron->{'telephone'} = ($data =~ /^t(.*)$/gm)[0]; }
        elsif ($data =~ /^p/) { $patron->{'telephone2'} = ($data =~ /^p(.*)$/gm)[0]; }
        elsif ($data =~ /^d/) { $patron->{'department'} = ($data =~ /^d(.*)$/gm)[0]; }
        elsif ($data =~ /^u/) { $patron->{'unique_id'} = ($data =~ /^u(.*)$/gm)[0]; }
        elsif ($data =~ /^b/) { $patron->{'barcode'} = ($data =~ /^b(.*)$/gm)[0]; }
        elsif ($data =~ /^z/) { $patron->{'email_address'} = ($data =~ /^z(.*)$/gm)[0]; }
        elsif ($data =~ /^x/) { $patron->{'note'} = ($data =~ /^x(.*)$/gm)[0]; }
        elsif ($data =~ /^e/) { $patron->{'esid'} = ($data =~ /^e(.*)$/gm)[0]; }
        elsif ($data =~ /^s/) { $patron->{'preferred_name'} = ($data =~ /^s(.*)$/gm)[0]; }
    }

    $patron->{raw_data} = join("\n", @{$patronRecord});

    return $isParsed ? $patron : undef;
}

# Prepare the SQL insert statement
sub prepareInsertStatement {
    my ($dbh) = @_;
    print "Preparing SQL statement...\n";
    my $sth = $dbh->prepare("INSERT INTO patron_import.stage_patron
        (job_id, institution_id, file_id, raw_data, field_code, patron_type,
        pcode1, pcode2, pcode3, home_library, patron_message_code, patron_block_code,
        patron_expiration_date, name, address, telephone, address2, telephone2,
        department, unique_id, barcode, email_address, note, esid, preferred_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    print "SQL statement prepared.\n";
    return $sth;
}

# Insert a patron record
sub insertPatron {
    my ($patron, $sth, $jobId) = @_;

    $sth->execute(
        $jobId,
        1, # institution_id (you may need to adjust this)
        1, # file_id (you may need to adjust this)
        $patron->{raw_data},
        $patron->{field_code},
        $patron->{patron_type},
        $patron->{pcode1},
        $patron->{pcode2},
        $patron->{pcode3},
        $patron->{home_library},
        $patron->{patron_message_code},
        $patron->{patron_block_code},
        $patron->{patron_expiration_date},
        $patron->{name},
        $patron->{address},
        $patron->{telephone},
        $patron->{address2},
        $patron->{telephone2},
        $patron->{department},
        $patron->{unique_id},
        $patron->{barcode},
        $patron->{email_address},
        $patron->{note},
        $patron->{esid},
        $patron->{preferred_name}
    );

    print "Inserted patron: $patron->{name}\n";  # Debug output
}

# Update job stop time
sub updateJobStopTime {
    my ($dbh, $jobId) = @_;
    print "Updating job record with stop time...\n";
    my $sth = $dbh->prepare("UPDATE patron_import.job SET stop_time = NOW() WHERE id = ?");
    $sth->execute($jobId);
    print "Job record updated.\n";
}

# Finalize the process
sub finalize {
    my ($dbh) = @_;
    print "Committing transaction...\n";
    $dbh->commit;
    print "Transaction committed successfully.\n";

    print "Disconnecting from database...\n";
    $dbh->disconnect;
    print "Disconnected from database.\n";

    print "Patron data import process completed successfully.\n";
}