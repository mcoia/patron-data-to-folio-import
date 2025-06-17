package Parsers::MissouriWesternParser;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use JSON;

use parent 'Parsers::SierraParser';
use FolioService;

=head1 NAME

Parsers::MissouriWesternParser - Missouri Western State University Patron Parser

=head1 DESCRIPTION

Extends SierraParser to provide custom field mapping for Missouri Western State University.
Maps Sierra PCODE fields to FOLIO custom fields using database-driven mappings.

Field Mappings:
- PCODE1 -> originalTenantID (custom field)  
- PCODE2 -> Class Level (custom field)
- PCODE3 -> Department (field)
- Note -> note (field)

=cut

sub afterParse
{
    my $self = shift;

    print "=== Missouri Western Parser: afterParse ===\n" if ($main::conf->{print2Console} eq 'true');
    $main::log->addLine("Missouri Western Parser: Starting afterParse processing");

    my $institution_id = $self->{institution}->{id};
    my $tenant = $self->{institution}->{tenant};
    
    print "Processing institution ID: $institution_id, tenant: $tenant\n" if ($main::conf->{print2Console} eq 'true');
    $main::log->addLine("Processing institution ID: $institution_id, tenant: $tenant");

    # Load PCODE mappings from database
    my $pcode_mappings = $self->_loadPcodeMappings($institution_id);
    
    if (!$pcode_mappings) {
        $main::log->addLine("ERROR: Failed to load PCODE mappings for institution $institution_id");
        return $self;
    }

    print "Loaded PCODE mappings: " . scalar(keys %{$pcode_mappings->{pcode2}}) . " PCODE2, " . 
          scalar(keys %{$pcode_mappings->{pcode3}}) . " PCODE3\n" if ($main::conf->{print2Console} eq 'true');

    # Process each parsed patron
    if ($self->{parsedPatrons} && @{$self->{parsedPatrons}}) {
        print "Processing " . scalar(@{$self->{parsedPatrons}}) . " patrons for custom field mapping\n" 
            if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("Processing " . scalar(@{$self->{parsedPatrons}}) . " patrons for custom field mapping");

        foreach my $patron (@{$self->{parsedPatrons}}) {
            $self->_processPatronCustomFields($patron, $pcode_mappings);
        }
    } else {
        print "No patrons to process\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("No patrons to process in afterParse");
    }

    print "=== Missouri Western Parser: afterParse Complete ===\n" if ($main::conf->{print2Console} eq 'true');
    $main::log->addLine("Missouri Western Parser: afterParse processing complete");

    return $self;
}

=head2 _loadPcodeMappings($institution_id)

Loads PCODE mappings from the database for the specified institution.
Returns a hashref with pcode2 and pcode3 mappings.

=cut

sub _loadPcodeMappings
{
    my ($self, $institution_id) = @_;
    
    my $mappings = {
        pcode2 => {},
        pcode3 => {}
    };

    # Load PCODE2 mappings (Class Level)
    eval {
        my $pcode2_query = "SELECT pcode2, pcode2_value FROM patron_import.pcode2_mapping WHERE institution_id = ?";
        my @pcode2_results = @{$main::dao->{db}->query($pcode2_query, [$institution_id])};
        
        foreach my $row (@pcode2_results) {
            $mappings->{pcode2}->{$row->[0]} = $row->[1];
        }
        
        print "Loaded " . scalar(@pcode2_results) . " PCODE2 mappings\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("Loaded " . scalar(@pcode2_results) . " PCODE2 mappings for institution $institution_id");
    };
    if ($@) {
        $main::log->addLine("ERROR loading PCODE2 mappings: $@");
        print "ERROR loading PCODE2 mappings: $@\n" if ($main::conf->{print2Console} eq 'true');
        return undef;
    }

    # Load PCODE3 mappings (Department)
    eval {
        my $pcode3_query = "SELECT pcode3, pcode3_value FROM patron_import.pcode3_mapping WHERE institution_id = ?";
        my @pcode3_results = @{$main::dao->{db}->query($pcode3_query, [$institution_id])};
        
        foreach my $row (@pcode3_results) {
            $mappings->{pcode3}->{$row->[0]} = $row->[1];
        }
        
        print "Loaded " . scalar(@pcode3_results) . " PCODE3 mappings\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("Loaded " . scalar(@pcode3_results) . " PCODE3 mappings for institution $institution_id");
    };
    if ($@) {
        $main::log->addLine("ERROR loading PCODE3 mappings: $@");
        print "ERROR loading PCODE3 mappings: $@\n" if ($main::conf->{print2Console} eq 'true');
        return undef;
    }

    return $mappings;
}

=head2 _processPatronCustomFields($patron, $pcode_mappings)

Processes a single patron record to populate custom fields based on PCODE mappings.

=cut

sub _processPatronCustomFields
{
    my ($self, $patron, $pcode_mappings) = @_;
    
    my $patron_id = $patron->{unique_id} || $patron->{barcode} || 'unknown';
    my @custom_fields = ();
    my $updated_fields = 0;

    # Map PCODE1 to originalTenantID custom field
    if ($patron->{pcode1} && $patron->{pcode1} ne '' && $patron->{pcode1} ne '-') {
        push @custom_fields, {
            name => 'originalTenantID',
            value => $patron->{pcode1}
        };
        $updated_fields++;
        print "  Mapped PCODE1 '$patron->{pcode1}' -> originalTenantID\n" if ($main::conf->{print2Console} eq 'true');
    }

    # Map PCODE2 to Class Level custom field
    if ($patron->{pcode2} && $patron->{pcode2} ne '' && $patron->{pcode2} ne '-') {
        my $class_level = $pcode_mappings->{pcode2}->{$patron->{pcode2}};
        if ($class_level) {
            push @custom_fields, {
                name => 'Class Level',
                value => $class_level
            };
            $updated_fields++;
            print "  Mapped PCODE2 '$patron->{pcode2}' -> Class Level: $class_level\n" if ($main::conf->{print2Console} eq 'true');
        } else {
            $main::log->addLine("WARNING: No mapping found for PCODE2 '$patron->{pcode2}' for patron $patron_id");
            print "  WARNING: No mapping found for PCODE2 '$patron->{pcode2}'\n" if ($main::conf->{print2Console} eq 'true');
        }
    }

    # Map PCODE3 to Department field
    if ($patron->{pcode3} && $patron->{pcode3} ne '' && $patron->{pcode3} ne '-') {
        my $department = $pcode_mappings->{pcode3}->{$patron->{pcode3}};
        if ($department) {
            # Update the department field as PostgreSQL array (staging table expects text[])
            $patron->{department} = [$department];
            $updated_fields++;
            print "  Mapped PCODE3 '$patron->{pcode3}' -> Department: $department\n" if ($main::conf->{print2Console} eq 'true');
        } else {
            $main::log->addLine("WARNING: No mapping found for PCODE3 '$patron->{pcode3}' for patron $patron_id");
            print "  WARNING: No mapping found for PCODE3 '$patron->{pcode3}'\n" if ($main::conf->{print2Console} eq 'true');
        }
    }

    # Map Note directly to note field (not in custom_fields)
    if ($patron->{note} && $patron->{note} ne '') {
        # Note field is already mapped in the base parser, so we don't need to do anything here
        # Just log the note for visibility
        $updated_fields++;
        print "  Note field preserved: '$patron->{note}'\n" if ($main::conf->{print2Console} eq 'true');
    }

    # Store custom fields in the patron record
    if (@custom_fields) {
        # Convert custom fields to JSON for storage
        eval {
            $patron->{custom_fields} = JSON::encode_json(\@custom_fields);
        };
        if ($@) {
            $main::log->addLine("ERROR encoding custom fields to JSON for patron $patron_id: $@");
            print "ERROR encoding custom fields to JSON: $@\n" if ($main::conf->{print2Console} eq 'true');
        }
    }

    if ($updated_fields > 0) {
        # Recalculate fingerprint after modifying patron data
        $patron->{fingerprint} = $main::parserManager->getPatronFingerPrint($patron);
        print "Updated $updated_fields custom fields for patron: $patron_id (fingerprint recalculated)\n" if ($main::conf->{print2Console} eq 'true');
        $main::log->addLine("Updated $updated_fields custom fields for patron: $patron_id");
    }

    return $patron;
}

1;

=head1 AUTHOR

MOBIUS Consortium

=head1 SEE ALSO

L<Parsers::SierraParser>, L<Parsers::ParserInterface>

=cut
