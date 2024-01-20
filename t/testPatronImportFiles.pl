#!/usr/bin/perl
use warnings FATAL => 'all';
use lib qw(../lib);

use MOBIUS::Loghandler;
use MOBIUS::Utils;

use PatronImportFiles;
use SierraFolioParser;
use Text::CSV::Simple;
use Data::Dumper;

our $conf;
initConf();

our $log = Loghandler->new("test.log");
$log->truncFile("");

sub initConf
{

    my $utils = MOBIUS::Utils->new();

    # Check our conf file
    my $configFile = "/home/owner/repo/mobius/folio/patron-import/patron-import.conf";
    $conf = $utils->readConfFile($configFile);

    exit if ($conf eq "false");

    # leave it de-reffed, talk with blake about this being the norm.
    # %conf = %{$conf};

}


my $files = PatronImportFiles->new($conf, $log);
my $importFilesPaths = $files->getSierraImportFilePaths();

for my $file (@{$files->getFilePatterns($importFilesPaths)})
{
    print "Processing $file\n";
    $log->addLine("$file");
}

1;