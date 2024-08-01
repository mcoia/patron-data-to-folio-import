#!/usr/bin/perl

use strict;
use warnings;
use lib qw(../lib);
use Data::Dumper;
use MOBIUS::Loghandler;
use ParallelExecutor;
use FileService;
use Time::HiRes qw(sleep);

my $log = initLog();

sub initLog {
    $log = Loghandler->new("test.log");
    $log->truncFile("");
    return $log;
}

sub doSomething {
    my $file = shift;
    print "Processing $file\n";

    # Simulate some work
    sleep(rand(3) + 2);  # Sleep for 2-5 seconds

    # Randomly throw an error (about 20% of the time)
    if (rand() < 0.4) {
        die "Random error occurred while processing $file";
    }

    print "Done processing $file\n";
}

# Create a ParallelExecutor instance
my $parallel = ParallelExecutor->new(
    maxProcesses => 3,
    log => $log
);

# Add tasks to the executor
for my $i (1..10) {
    $parallel->addTask(sub { doSomething("file$i.txt") });
}

# Execute tasks in parallel
$parallel->execute();

# Print final status for all tasks
for my $i (0..9) {
    print "Status for task $i:\n";
    print Dumper($parallel->getStatus($i));
    print "\n";
}