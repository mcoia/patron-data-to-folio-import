package Parsers::ESID;
use strict;
use warnings FATAL => 'all';
use Try::Tiny;

# sub new
# {
#     my $class = shift;
#     my $self = {};
#     bless $self, $class;
#     return $self;
# }

=pod

We don't actually instantiate this class.

=cut

sub getESID
{
    my $patron = shift;
    my $institutionID = shift;

    my $institution = $main::dao->getInstitutionMapHashById($institutionID);

    my $esid = "";

    return "" if ($institution->{esid} eq '');

    # I'm trying to error check this. I want a try/catch
    try
    {
        $esid = eval "$institution->{esid}(\$patron)";
    }
    catch
    {
        return "";
    };

    return $esid;

}

sub email
{
    my $patron = shift;
    return $patron->{email_address};
}

sub barcode
{
    my $patron = shift;
    return $patron->{barcode};
}

1;