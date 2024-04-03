#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use lib qw(../lib);
use FolioService;

# Note: use single ticks to use special chars in password variable.
# export folio_password='some-password-here'
# sudo apt install liblwp-protocol-https-perl

# my $url = "https://bugfest-poppy-consortium.int.aws.folio.org";
# /authn/login-with-expiry
my $url = "https://okapi-bugfest-quesnelia-consortium.int.aws.folio.org";
my $username = $ENV{folio_username};
my $password = $ENV{folio_password};
my $tenant = "cs00000int";

my $folio = FolioService->new($username, $password, $tenant, $url);

$folio->login();

print Dumper($folio);