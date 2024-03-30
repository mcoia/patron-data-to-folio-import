#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
#
# # my $filePath = "/mnt/dropbox/avalon/home/avalon/incoming/CMUfac20240126.out";
# my $filePath = "/mnt/dropbox/kc-towers/home/kc-towers/incoming/AvilaUniversity01-19-2023.txt";
# my @data = ();
#
#
#
# sub containsValue
# {
#     my $array = shift;
#     my $digit = shift;
#
#     for (@{$array})
#     {return 1 if ($digit == $_ || $digit eq $_);}
#     return 0;
#
# }
#
# # // open $filePath and read it into the @data array
# open(my $fh, '<', $filePath) or die "Could not open file '$filePath' $!";
# while (my $line = <$fh>)
# {
#     if ($line =~ /^0/)
#     {
#         # chomp $line;
#         $line =~ s/\r//;
#         $line =~ s/\n//;
#         push @data, $line;
#     }
# }
# close $fh;
#
# my @digits = ();
# for my $data (@data)
# {
#     my $tmp = ($data =~ /^0(\d{3})/gm)[0] + 0;
#
#     push(@digits, $tmp) if (!containsValue(\@digits, $tmp));
#
# }
#
# print "[$_]" for(@digits);
# print "\n";
#


my $patron = {
    # 'patron_type'            => "",
    # 'pcode1'                 => "",
    # 'pcode2'                 => "",
    # 'pcode3'                 => "",
    # 'home_library'           => "",
    # 'patron_message_code'    => "",
    # 'patron_block_code'      => "",
    # 'patron_expiration_date' => "",
};

# my $data = "0015M-01 mfb  --12/31/24";
my $data = "0015M-01 mfb  X-12/31/24";

$patron->{'patron_type'} = substr($data, 1, 3) + 0 if ($data =~ /^0/);
$patron->{'pcode1'} = substr($data, 4,1) if ($data =~ /^0/);
$patron->{'pcode2'} = substr($data, 5,1) if ($data =~ /^0/);
$patron->{'pcode3'} = substr($data, 6,3) if ($data =~ /^0/);
$patron->{'home_library'} = substr($data, 9,5) if ($data =~ /^0/);
$patron->{'patron_message_code'} = substr($data, 14,1) if ($data =~ /^0/);
$patron->{'patron_block_code'} = substr($data, 15,1) if ($data =~ /^0/);
$patron->{'patron_expiration_date'} = substr($data, 16,8) if ($data =~ /^0/);
print $data . "\n";
print Dumper($patron);

















