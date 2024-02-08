#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use feature 'signatures';
no warnings qw(experimental::signatures);
use FreezeThaw qw(freeze);
use Digest::SHA1;
use lib qw(../lib);
use MOBIUS::Utils;

# hash();
sub hash
{

    # my $finalValue = 63785864725478782;
    my $finalValue = "f29e4f403bb8e50cad7ad4e84b7f623c402ae433";

    # zero field
    my $patron = {};
    $patron->{'field_code'} = 'some-data-here';
    $patron->{'patron_type'} = 'some-data-here';
    $patron->{'pcode1'} = 'some-data-here';
    $patron->{'pcode2'} = 'some-data-here';
    $patron->{'pcode3'} = 'some-data-here';
    $patron->{'home_library'} = 'some-data-here';
    $patron->{'patron_message_code'} = 'some-data-here';
    $patron->{'patron_block_code'} = 'some-data-here';
    $patron->{'patron_expiration_date'} = 'some-data-here';
    $patron->{'name'} = 'some-data-here';
    $patron->{'address'} = 'some-data-here';
    $patron->{'telephone'} = 'some-data-here';
    $patron->{'address2'} = 'some-data-here';
    $patron->{'telephone2'} = 'some-data-here';
    $patron->{'department'} = 'some-data-here';
    $patron->{'unique_id'} = 'some-data-here';
    $patron->{'barcode'} = 'some-data-here';
    $patron->{'email_address'} = 'some-data-here';
    $patron->{'note'} = 'some-data-here';

    my $patron1 = {};
    $patron1->{'field_code'} = 'some-data-here';
    $patron1->{'patron_type'} = 'some-data-here';
    $patron1->{'pcode1'} = 'some-data-here';
    $patron1->{'pcode2'} = 'some-data-here';
    $patron1->{'pcode3'} = 'some-data-here';
    $patron1->{'home_library'} = 'some-data-here';
    $patron1->{'patron_message_code'} = 'some-data-here';
    $patron1->{'patron_block_code'} = 'some-data-here';
    $patron1->{'patron_expiration_date'} = 'some-data-here';
    $patron1->{'name'} = 'some-data-here';
    $patron1->{'address'} = 'some-data-here';
    $patron1->{'telephone'} = 'some-data-here';
    $patron1->{'address2'} = 'some-data-here';
    $patron1->{'telephone2'} = 'some-data-here';
    $patron1->{'department'} = 'some-data-here';
    $patron1->{'unique_id'} = 'some-data-here';
    $patron1->{'barcode'} = 'some-data-here';
    $patron1->{'email_address'} = 'some-data-here';
    $patron1->{'note'} = 'some-data-here';

    # for (0 .. 100)
    # {
    #
    #     my $freeze = freeze($patron);
    #     my $freeze1 = freeze($patron1);
    #
    #     my $hash = "";
    #     my $hash1 = "";
    #     $hash = $hash . ord($_) for (split //, $freeze);
    #     $hash1 = $hash1 . ord($_) for (split //, $freeze1);
    #
    #     my $phash = `python3 -c "print (str(hash($hash)))"`;
    #     my $phash1 = `python3 -c "print (str(hash($hash1)))"`;
    #
    #     if ($phash != $phash1)
    #     {
    #         print "we failed!\n";
    #         print "$phash\n";
    #         print "$phash1\n";
    #         exit;
    #     }
    # }
    #

    for (0 .. 100)
    {

        my $s = MOBIUS::Utils->getHash(freeze($patron));
        my $s2 = MOBIUS::Utils->getHash(freeze($patron1));

        if ($s ne $finalValue && $s2 ne $finalValue)
        {
            print "we failed!!!\n";
            print "$s\n";
            print "$s2\n";
            exit;
        }

    }

    print "works\n";
    print MOBIUS::Utils->getHash(freeze($patron)) . "\n";
    print MOBIUS::Utils->getHash(freeze($patron1)) . "\n";

}

# my @modules = glob("./Parsers/*");
# my @modules = glob("../lib/Parsers/*");
# for my $module (@modules)
# {
#     $module =~ s/\.pm$//g;
#     print "$module\n";
#     require "Parsers::$module";
# }


print localtime;
