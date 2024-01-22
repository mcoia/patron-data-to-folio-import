#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

my $a;

for (0 .. 10)
{

    my $h = {
        'id'   => $_,
        'rand' => rand(10),
    };
    push(@$a, $h);
}


$a = t1($a);
print Dumper($a);

sub t1
{
    my $b = shift;
    for my $h (@$b)
    {
        $h->{name} = "TEST";
    }
    return $b;
}

1;