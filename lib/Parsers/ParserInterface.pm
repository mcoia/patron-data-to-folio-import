package Parsers::ParserInterface;
use strict;
use warnings FATAL => 'all';

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub onInit {
    die "Subclass must implement onInit()";
}

sub beforeParse {
    die "Subclass must implement beforeParse()";
}

sub parse {
    die "Subclass must implement parse()";
}

sub afterParse {
    die "Subclass must implement afterParse()";
}

sub finish {
    die "Subclass must implement finish()";
}

1;