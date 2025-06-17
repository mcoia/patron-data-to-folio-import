package Parsers::MissouriWesternParser;
use strict;
use warnings FATAL => 'all';

use parent 'Parsers::SierraParser';
use FolioService;

# I want to change the name of this parser to Missouri Western State University Parser - MissouriWesternStateUniversityParser.pm
# it needs to be more identifiable as a parser for Missouri Western State University.

sub afterParse
{

    my $self = shift;

    print Dumper($self->{institution});

    my $folio = FolioService->new();

    my $departments = $folio->getDepartmentsByTenant($tenant);
    print Dumper($departments);

}
