package ParserManager;

use strict;
use warnings FATAL => 'all';
no warnings 'uninitialized';
use Time::HiRes qw(time);
use List::Util qw(any);
use Parsers::SierraParser;
use Parsers::CovenantParser;
use Parsers::TrumanParser;
use Parsers::KCKCCParser;
use Parsers::ESID;
use Parsers::TRCParser;
use Parsers::MissouriWesternParser;
use Parsers::StateTechParser;
use Parsers::GoldfarbParser;
use Parsers::WichitaParser;
use Parsers::StephensParser;
use Parsers::MVCParser;
use Parsers::MOBIUSParser;
use MOBIUS::Utils;

use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {
        dao      => shift,
        files    => shift,
        conf     => shift,
        log      => shift,
        jobID    => shift,
        debug    => shift
    };
    bless $self, $class;
    return $self;
}

sub stagePatronRecords
{
    my $self = shift;
    my $institutionID = shift; # optional

    # this is an array of institutions
    my $institutions = $self->{dao}->getInstitutionsFoldersAndFilesHash($institutionID);

    # loop over our discovered files.
    for my $institution (@{$institutions})
    {

        # Gives us the ability to skip certain institutions if needed.
        next if (!$institution->{enabled});

        # Get our Parser Module that's stored in the database column 'module' in the institution table
        my $module = "SierraParser"; # default to generic
        $module = $institution->{module} if ($institution->{module} ne '' || $institution->{module} ne undef);

        # Build the parser module.
        my $parser;
        my $createParser = '$parser = Parsers::' . $institution->{module} . '->new($institution, $self->{dao}, $self->{log}, $self->{jobID}, $self->{conf}, $self->{debug});';
        print "Creating parser: [$createParser]\n" if ($self->{debug});
        eval $createParser;
        # Parser Not working? Don't forget to load it! use Parsers::ParserNameHere;

        print "Searching for files...\n" if ($self->{debug});
        $self->{log}->addLine("Searching for files...\n");

        # The $institution now contains the files needed for parsing. Thanks patronFileDiscovery!
        # We still need to skip the files in our buildDropboxFolderStructureByInstitutionId
        $self->{files}->patronFileDiscovery($institution);


        # If we keep getting stray files in these dropbox folders we may have to disable this portion.
        # I would need to know who's uploading files that are being imported that are not actual patron files.
        ## ---- start dropbox specific folders

        my $dropboxFolder = $self->{files}->patronFileDiscoverySpecificFolder($institution->{id});

        # Check for access errors from dropbox discovery
        if ($dropboxFolder->{error}) {
            my $error_msg = "FILE ACCESS ERROR for $institution->{name}: " .
                            "$dropboxFolder->{error} - $dropboxFolder->{error_message}";
            print "$error_msg\n" if ($self->{debug});
            $self->{log}->addLine($error_msg);
            # Store error on institution for later reference in status message
            $institution->{access_error} = $dropboxFolder->{error};
            $institution->{access_error_message} = $dropboxFolder->{error_message};
        }

        # We push everything into the institution->folder and then iterate thru removing duplicates.
        push(@{$institution->{folders}}, $dropboxFolder);
        $self->removeDuplicatePaths($institution);

        ## ---- end dropbox specific folders


        # Our parsers life cycle hooks
        $parser->onInit();
        $parser->parse();
        $parser->afterParse();
        $parser->insertPatronsIntoStageTable();

        # some debug metrics
        my $totalPatrons = scalar(@{$parser->{parsedPatrons}});
        print "Total Patrons: [$totalPatrons]\n" if ($self->{debug});
        print "Migrating records to final table...\n" if ($self->{debug});
        print "================================================================================\n\n" if ($self->{debug});
        $self->{log}->addLine("Total Staged Patrons: [$totalPatrons]\n");

        # press Enter to continue - WRITE THIS
        # print "Press Enter to continue...\n" if ($self->{debug});
        # <STDIN>;
        # exit;

        my $readyCount = 0;
        my $migrationSuccess = 1;
        my $result =
            eval
            {
                $readyCount = $parser->updateFinalTable();
                1; # Return success
            };

        if (!$result || $@)
        {
            $self->{log}->addLine("Migration failed: $@");
            print "Migration failed: $@\n" if ($self->{debug});
            $migrationSuccess = 0;
            $self->sendMigrationFailureEmail();
        }

        if (
            $self->{conf}->{deleteFiles} eq 'true' &&
            $migrationSuccess &&
            $totalPatrons > 0
            )
        {
            print "All processing successful. Deleting files for institution: $institution->{name}\n" if ($self->{debug});
            $self->{log}->addLine("Deleting files - Migration successful, $totalPatrons parsed for institution: $institution->{name}");
            $self->{log}->addLine("Total final ready for FOLIO: [$readyCount]\n");
            $self->deletePatronFiles($institution);
        }
        else
        {
            my $reason = "Files preserved - ";
            $reason .= "deleteFiles=false " if ($self->{conf}->{deleteFiles} ne 'true');
            $reason .= "migration failed " if (!$migrationSuccess);
            $reason .= "no patrons parsed " if ($totalPatrons == 0);

            # Include access error information if present
            if ($institution->{access_error}) {
                $reason .= "(ACCESS ERROR: $institution->{access_error}) ";
            }

            print "$reason for institution: $institution->{name}\n" if ($self->{debug});
            $self->{log}->addLine("$reason for institution: $institution->{name}");
        }
        $self->{log}->addLine("================================================================================\n\n");

    }

    return $self;
}

sub removeDuplicatePaths
{
    my $self = shift;
    my $institution = shift;

    my %allUniquePaths;

    foreach my $folder (@{$institution->{folders}})
    {
        foreach my $file (@{$folder->{files}})
        {
            my @uniqueFilePaths;
            foreach my $pathob (@{$file->{paths}})
            {
                if (!exists $allUniquePaths{$pathob->{path}})
                {
                    # Log when a file path is added
                    print "Adding file path: [$pathob->{path}]\n" if ($self->{debug});
                    $self->{log}->addLine("Adding file path: [$pathob->{path}]");
                    $allUniquePaths{$pathob->{path}} = 1;
                    push @uniqueFilePaths, $pathob;
                }
                else
                {
                    # Log when a file path is removed as duplicate
                    print "Removed duplicate file path: [$pathob->{path}]\n" if ($self->{debug});
                    $self->{log}->addLine("Removed duplicate file path: [$pathob->{path}]");
                }
            }
            $file->{paths} = \@uniqueFilePaths;
        }
    }
}

sub deletePatronFiles
{
    my $self = shift;
    my $institution = shift;

    for my $folder (@{$institution->{folders}})
    {
        for my $file (@{$folder->{files}})
        {
            for my $fileob (@{$file->{paths}})
            {
                my $filePath = $fileob->{path};
                print "deleting file: [$filePath]\n" if ($self->{debug});
                $self->{log}->addLine("deleting file: [$filePath]");

                unlink $filePath;

            }

        }
    }

    return $self;

}

sub sendMigrationFailureEmail
{

    my $self = shift;

    # Send an email with the log file attached to the admin.
    my $adminEmail = $self->{conf}->{adminEmail};
    my @emailAddresses = ($adminEmail);

    $self->{log}->addLine("We have failed to migrate the records. Sending email to: [$adminEmail]");
    my $email = MOBIUS::Email->new($self->{conf}->{fromAddress}, \@emailAddresses, 0, 0);
    my $log = $self->{files}->readFileAsString($self->{log}->{_file});

    my $logAsHTML = $self->convertLogToHTML($log);

    my $html = "<html lang=\"en\"><body>$logAsHTML</body></html>";

    $email->sendHTML("Patron Loads FAILED!!!", "MOBIUS", $self->{log});

}

sub convertLogToHTML
{
    my $self = shift;
    my $log = shift;

    my @lines = split(/\n/, $log);
    my $html = "";
    for my $line (@lines)
    {
        $html .= "<p>$line</p>";
    }

    return $html;
}

1;

