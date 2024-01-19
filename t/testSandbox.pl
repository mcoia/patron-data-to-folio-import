#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

use Text::CSV::Simple;
# archway arthur avalon bridges explore kc-towers palmer swan swbts
my $datafile = "/home/owner/repo/mobius/folio/patron-import/resources/mapping/patron-type/arthur.csv";
my $parser = Text::CSV::Simple->new;
my @data = $parser->read_file($datafile);

for my $row (@data)
{
    print "[$_]" for (@{$row});
    print "\n";
}

1;