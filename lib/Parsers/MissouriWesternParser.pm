package Parsers::MissouriWesternParser;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use JSON;

use parent 'Parsers::SierraParser';

=head1 NAME

Parsers::MissouriWesternParser - Missouri Western State University Patron Parser

=head1 DESCRIPTION

Extends SierraParser to provide custom field mapping for Missouri Western State University.
Maps Sierra PCODE fields to FOLIO custom fields using database-driven mappings.

Field Mappings:
- PCODE1 -> (removed - not mapped)
- PCODE2 -> Class Level (custom field)
- PCODE3 -> Department (field)
- Note -> note (field)

=cut

sub afterParse
{
    my $self = shift;

    my $pcode_mappings = {
        pcode2 => {
            'f'      => 'FRESHMAN',
            'g'      => 'GRADUATE',
            'h'      => 'HIGH SCHOOL',
            'j'      => 'JUNIOR',
            'r'      => 'SENIOR',
            's'      => 'SOPHOMORE',
            '-'      => 'NONE'
        },
        pcode3 => {
            '0'       => 'Undecided',
            '1'       => 'Accounting',
            '2'       => 'Administrators/Staff',
            '10'      => 'Art',
            '12'      => 'Biology',
            '15'      => 'Chemistry',
            '17'      => 'Communication Studies',
            '18'      => 'Computer Science',
            '21'      => 'Continuing Education',
            '23'      => 'Criminal Justice',
            '28'      => 'Economics',
            '30'      => 'Education-Elementary',
            '31'      => 'Education-General',
            '37'      => 'English',
            '40'      => 'Engineering Technology',
            '47'      => 'General Business',
            '53'      => 'History',
            '69'      => 'Mathematics',
            '77'      => 'Music',
            '79'      => 'Nursing',
            '82'      => 'Physical Education',
            '84'      => 'Physical Therapist Assistant',
            '88'      => 'Psychology',
            '103'     => 'Academic Affairs',
            '104'     => 'Fine Arts',
            '105'     => 'Health Professions'
        }
    };

    print "Loaded PCODE mappings: " . scalar(keys %{$pcode_mappings->{pcode2}}) . " PCODE2, " .
        scalar(keys %{$pcode_mappings->{pcode3}}) . " PCODE3\n" if ($self->{debug});

    print "=== Missouri Western Parser: afterParse ===\n" if ($self->{debug});
    $self->{log}->addLine("Missouri Western Parser: Starting afterParse processing");

    my $institution_id = $self->{institution}->{id};
    my $tenant = $self->{institution}->{tenant};

    print "Processing institution ID: $institution_id, tenant: $tenant\n" if ($self->{debug});
    $self->{log}->addLine("Processing institution ID: $institution_id, tenant: $tenant");

    # Process each parsed patron
    if ($self->{parsedPatrons} && @{$self->{parsedPatrons}})
    {
        print "Processing " . scalar(@{$self->{parsedPatrons}}) . " patrons for custom field mapping\n"
            if ($self->{debug});
        $self->{log}->addLine("Processing " . scalar(@{$self->{parsedPatrons}}) . " patrons for custom field mapping");

        $self->_processPatronCustomFields($_, $pcode_mappings) foreach (@{$self->{parsedPatrons}});
    }
    else
    {
        print "No patrons to process\n" if ($self->{debug});
        $self->{log}->addLine("No patrons to process in afterParse");
    }

    print "=== Missouri Western Parser: afterParse Complete ===\n" if ($self->{debug});
    $self->{log}->addLine("Missouri Western Parser: afterParse processing complete");

    return $self;
}

sub _processPatronCustomFields
{
    my ($self, $patron, $pcode_mappings) = @_;

    my $patron_id = $patron->{unique_id} || $patron->{barcode} || 'unknown';
    my %custom_fields = ();

    # PCODE1 mapping removed - originalTenantID not needed

    # Map PCODE2 to Class Level custom field
    if ($patron->{pcode2} && $patron->{pcode2} ne '' && $patron->{pcode2} ne '-')
    {
        my $class_level = $pcode_mappings->{pcode2}->{$patron->{pcode2}};
        if ($class_level)
        {
            $custom_fields{'classlevel'} = $class_level;
            print "  Mapped PCODE2 '$patron->{pcode2}' -> Class Level: $class_level\n" if ($self->{debug});
        }
        else
        {
            $self->{log}->addLine("WARNING: No mapping found for PCODE2 '$patron->{pcode2}' for patron $patron_id");
            print "  WARNING: No mapping found for PCODE2 '$patron->{pcode2}'\n" if ($self->{debug});
        }
    }

    # Map PCODE3 to Department field
    if ($patron->{pcode3} && $patron->{pcode3} ne '' && $patron->{pcode3} ne '-')
    {
        # Normalize PCODE3 by removing leading zeros (e.g., '047' becomes '47', '000' becomes '0')
        my $normalized_pcode3 = $patron->{pcode3} + 0;
        my $department = $pcode_mappings->{pcode3}->{$normalized_pcode3};
        if ($department)
        {
            # Update the department field as PostgreSQL array (staging table expects text[])
            $patron->{department} = [ $department ];
            print "  Mapped PCODE3 '$patron->{pcode3}' (normalized: $normalized_pcode3) -> Department: $department\n" if ($self->{debug});
        }
        else
        {
            $self->{log}->addLine("WARNING: No mapping found for PCODE3 '$patron->{pcode3}' (normalized: $normalized_pcode3) for patron $patron_id");
            print "  WARNING: No mapping found for PCODE3 '$patron->{pcode3}' (normalized: $normalized_pcode3)\n" if ($self->{debug});
        }
    }

    # Store custom fields in the patron record
    if (%custom_fields)
    {
        # Convert custom fields to JSON for storage
        eval {
            $patron->{custom_fields} = JSON::encode_json(\%custom_fields);
        };
        if ($@)
        {
            $self->{log}->addLine("ERROR encoding custom fields to JSON for patron $patron_id: $@");
            print "ERROR encoding custom fields to JSON: $@\n" if ($self->{debug});
        }
    }

    return $patron;
}

1;

=head1 AUTHOR

MOBIUS Consortium

=head1 SEE ALSO

L<Parsers::SierraParser>, L<Parsers::ParserInterface>

=cut
