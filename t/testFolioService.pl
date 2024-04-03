#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use lib qw(../lib);
use FolioService;

# Note: use single ticks to use special chars in password variable.
# export folio_password='some-password-here'
# sudo apt install liblwp-protocol-https-perl

my $username = $ENV{folio_username};
my $password = $ENV{folio_password};

my $url = "https://bugfest-poppy-consortium.int.aws.folio.org";
# my $url = "https://bugfest-quesnelia-consortium.int.aws.folio.org";

my $folio = FolioService->new($username, $password, $url);
my $response = $folio->loginOKAPI();

print Dumper($response);