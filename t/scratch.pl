#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use JSON;


my $patron = {
    name => 'John Doe',
};

if (!keys %$patron) {
    print "patron is empty\n";
} else {
    print "patron is not empty\n";
}