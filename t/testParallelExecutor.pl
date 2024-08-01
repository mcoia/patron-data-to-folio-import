#!/bin/perl

use strict;
use warnings;
use Test::More;
# use Encode::Supported;
use Encode;
use FindBin qw($Bin);
use lib qw(../lib);
use ParallelExecutor;

# Create a new ParallelExecutor instance
my $executor = ParallelExecutor->new(maxProcesses => 3);

# Define tasks that use Encode module
my @texts = (
    "Hello, World!",
    "こんにちは、世界！",
    "¡Hola, Mundo!",
    "Здравствуй, мир!",
);

my @encodings = qw(UTF-8 Shift_JIS ISO-8859-1 KOI8-R);

for my $i (0..$#texts) {
    $executor->addTask(sub {
        my $text = $texts[$i];
        my $encoding = $encodings[$i];
        
        my $encoded = encode($encoding, $text);
        my $decoded = decode($encoding, $encoded);
        
        print "Original: $text\n";
        print "Encoded ($encoding): ", unpack("H*", $encoded), "\n";
        print "Decoded: $decoded\n";
        print "Roundtrip successful: ", ($text eq $decoded ? "Yes" : "No"), "\n\n";
    });
}

# Execute all tasks
$executor->execute();

# Check results
for my $i (0..$#texts) {
    my $status = $executor->getStatus($i);
    ok($status->{status} eq 'done', "Task $i completed successfully");
    like($status->{output}, qr/Roundtrip successful: Yes/, "Roundtrip encoding/decoding successful for task $i");
}

done_testing();
