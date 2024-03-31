#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use POSIX;

my $a = "abcdefghijklmnopqrstuvwxyz";

my @a = split('', $a);

my @b = map {uc $_} @a;
push(@b, @a);

my @c = (0 .. 9);
push(@b, @c);

print "@b";

my $size = @b;

my @final = ();
for (0 .. $size - 1)
{
    push(@final, {
        'char'  => $b[$_],
        'ascii' => ord($b[$_])
    });

}

# @final = map {$_->{char} eq 'a' ? () : $_->{char}} @final;
# @final = map {$_->{char} eq 'a' ? () : $_} @final;


my @chars = grep /\d/, map {$_->{char}} @final;

print Dumper(\@chars);
# print Dumper(\@final);




