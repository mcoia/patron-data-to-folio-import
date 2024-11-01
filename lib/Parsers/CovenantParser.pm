package Parsers::CovenantParser;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use parent 'Parsers::SierraParser';

sub afterParse
{
    my $self = shift;

    # We make an api call to folio and get the departments and set it to class object
    $self->{'departments'} = $main::folio->getDepartmentsByTenant($self->{institution}->{tenant}) || [];

    print "Updating departments for Covenant\n" if ($main::conf->{print2Console});

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