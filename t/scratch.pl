#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';

# my $s = "K'Niya.Thompson\@uhsp.edu";
#
# print $s . "\n";
# $s =~ s/'/\\'/g;
#
# print $s . "\n";

# Patron fails to update due to ' in the esid
# {
#     'phone' => '',
#     'barcode' => '146258COP',
#     'preferredcontacttypeid' => 'email',
#     'address' => [
#         {
#             'postalcode' => 'Louis',
#             'addresstypeid' => 'Home',
#             'addressline2' => '935 Meadow Acres Lane, St. Louis, MO, 63125',
#             'addressline1' => '',
#             'city' => '935 Meadow Acres Lane',
#             'region' => 'Saint',
#             'countryid' => 'US',
#             'primaryaddress' => 1,
#             'primaryAddress' => 'true'
#         }
#     ],
#     'preferredfirstname' => '',
#     'active' => 1,
#     'middlename' => 'KNiya',
#     'lastname' => 'Thompson',
#     'enrollmentdate' => '',
#     'firstname' => 'KNiya',
#     'dateofbirth' => '',
#     'mobilephone' => '',
#     'username' => '146258COP',
#     'patrongroup' => 'UHSP Student',
#     'expirationdate' => '2023-05-31',
#     'email' => 'K'Niya.Thompson@uhsp.edu',
#     'externalsystemid' => 'K'Niya.Thompson@uhsp.edu'
# },



my $s = "'";
print ord($s) . "\n";
print chr(39) . "\n";