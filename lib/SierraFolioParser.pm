package SierraFolioParser;

use strict;
use warnings FATAL => 'all';

=pod


=head1 new(log,fileManager)

=cut
sub new {
    my $class = shift;
    my $self = {
        'log' => shift,
        'fileManager' => shift,
    };
    bless $self, $class;
    return $self;
}

=head1 parse()

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
sub parse {


}

1;