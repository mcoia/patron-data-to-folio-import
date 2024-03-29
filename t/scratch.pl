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
    'patron_type'            => "",
    'pcode1'                 => "",
    'pcode2'                 => "",
    'pcode3'                 => "",
    'home_library'           => "",
    'patron_message_code'    => "",
    'patron_block_code'      => "",
    'patron_expiration_date' => "",
};
=pod
The initial field: Always 24 char long
example: 0101c-003clb  --01/31/24

Field:Char Length
------------
Field Code: 1
Patron Type: 3 (000 to 255)
PCODE1: 1
PCODE2: 1
PCODE3: 3 (000 to 255)
Home Library: 5 char, padded with blanks if needed (e.g. "shb  ")
Patron Message Code: 1
Patron Block Code: 1
Patron Expiration Date: 8 (mm-dd-yy)

Patron Parser Info:
n = Name
a = Address
t = Telephone
h = Address2
p = Telephone2
d = Department
u = Unique ID
b = Barcode
z = Email Address
x = Note
=cut

my $data = "0001--   avb  --01-31-23";

$patron->{'field_code'} = '0' if ($data =~ /^0/);
$patron->{'patron_type'} = ($data =~ /^0(\d{3}).*/gm)[0] + 0 if ($data =~ /^0/);
$patron->{'pcode1'} = ($data =~ /^0\d{3}(.{1}).*/gm)[0] if ($data =~ /^0/);
$patron->{'pcode2'} = ($data =~ /^0\d{3}.{1}(.{1}).*/gm)[0] if ($data =~ /^0/);
$patron->{'pcode3'} = ($data =~ /^0\d{3}.{2}(.{3}).*/gm)[0] if ($data =~ /^0/);
$patron->{'home_library'} = ($data =~ /^0\d{3}.{2}.{3}(.{5}).*/gm)[0] if ($data =~ /^0/);
$patron->{'patron_message_code'} = ($data =~ /^0\d{3}.{2}.{3}.{5}(.{1}).*/gm)[0] if ($data =~ /^0/);
$patron->{'patron_block_code'} = ($data =~ /^0\d{3}.{2}.{3}.{6}(.{1}).*/gm)[0] if ($data =~ /^0/);

$patron->{'patron_expiration_date'} = ($data =~ /--(\d+.*$)/gm)[0] if ($data =~ /^0/);

print "[$data]\n";
print Dumper($patron);

# 'field_code' => '0',
# 'patron_type' => 1,
# 'pcode1' => '-',
# 'pcode2' => '-'
# 'pcode3' => undef,
# 'patron_message_code' => undef,
# 'patron_block_code' => undef,
# 'patron_expiration_date' => '   avb  --01-31-23',
# 'home_library' => undef,
