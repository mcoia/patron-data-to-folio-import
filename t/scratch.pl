#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use FreezeThaw qw(freeze);
use bignum;

# my $x = {
#     'name' => 'scott',
#     'age'  => 43
# };

my $finalValue = 63785864725478782;

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

for (0 .. 100)
{

    my $freeze = freeze($patron);
    my $hash = "";
    $hash = $hash . ord($_) for (split //, $freeze);
    # print "[$hash]\n";

    my $hash1 = $hash + 0;
    my $newHash = $hash / 1000;

    my $phash = `python3 -c "print (str(hash($hash)))"`;
    # print $phash . "\n";

    if($phash != $finalValue){
        print "we failed!\n";
       exit;
    }
}

