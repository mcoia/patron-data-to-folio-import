package Parsers::CovenantParser;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use parent 'Parsers::SierraParser';

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
    $self->{'departments'} = $main::folio->getDepartmentsByTenant($self->{institution}->{tenant});

    $self->{'departments'} = [] unless $self->{'departments'} && @{$self->{'departments'}};

    # log the departments
    print "CovenantParser Departments: " . Dumper($self->{'departments'});
    $main::log->addLine("CovenantParser Departments: " . Dumper($self->{'departments'}));

}

sub afterParse
{
    my $self = shift;

    print "Updating departments for Covenant\n";

    # loop over each patron and update the department
    for my $patron (@{$self->{parsedPatrons}})
    {

        # set the department to an empty object
        $patron->{department} = "{}";

        # loop over $self->{departments}
        for my $department (@{$self->{'departments'}})
        {

            if ($patron->{pcode3} eq $department->{code})
            {
                $patron->{department} = "{$department->{name}}";
                last;
            }

        }

    }

}

1;