package ParallelExecutor;

use strict;
use warnings;
use Parallel::ForkManager;
use Time::HiRes qw(time);
use MOBIUS::Loghandler;
use POSIX qw(strftime);

sub new {
    my ($class, %args) = @_;
    my $self = {
        maxProcesses => $args{maxProcesses} || 5,
        log => $args{log} || Loghandler->new("parallel_executor.log"),
        forkManager => undef,
        tasks => [],
        results => {},
    };
    bless $self, $class;
    $self->_initForkManager();
    return $self;
}

sub _initForkManager {
    my $self = shift;
    $self->{forkManager} = Parallel::ForkManager->new($self->{maxProcesses});

    $self->{forkManager}->run_on_start(sub {
        my ($pid, $ident) = @_;
        $self->{results}->{$ident} = {
            pid => $pid,
            startTime => time(),
            stopTime => undef,
            status => 'running',
            output => '',
            error => undef,
        };
        $self->{log}->addLine("Started process $pid for task $ident");
    });

    $self->{forkManager}->run_on_finish(sub {
        my ($pid, $exit_code, $ident, $exit_signal, $core_dump, $data) = @_;
        $self->{results}->{$ident}->{stopTime} = time();
        $self->{results}->{$ident}->{status} = $exit_code == 0 ? 'done' : 'error';
        $self->{results}->{$ident}->{output} = $data->{output} if $data && $data->{output};
        $self->{results}->{$ident}->{error} = $data->{error} if $data && $data->{error};
        $self->{log}->addLine("Finished process $pid for task $ident with status " . $self->{results}->{$ident}->{status});
        $self->_printStatus($ident);
    });
}

sub addTask {
    my ($self, $task) = @_;
    push @{$self->{tasks}}, $task;
}

sub execute {
    my $self = shift;

    for my $i (0 .. $#{$self->{tasks}}) {
        my $pid = $self->{forkManager}->start($i) and next;

        my $task = $self->{tasks}->[$i];
        my $output = '';
        my $error = undef;

        eval {
            open my $stdout, '>', \$output or die "Can't capture STDOUT: $!";
            local *STDOUT = $stdout;
            $task->();
        };

        if ($@) {
            $error = $@;
            $self->{log}->addLine("Error in task $i: $error");
            $output .= "Error occurred during execution. Check error details.";
        }

        $self->{forkManager}->finish(0, { output => $output, error => $error });
    }

    $self->{forkManager}->wait_all_children;
}

sub _printStatus {
    my ($self, $ident) = @_;
    my $result = $self->{results}->{$ident};
    my $upTime = $result->{stopTime} - $result->{startTime};

    my $status = sprintf(
        "PID: %d\nStart Time: %s\nStop Time: %s\nUp Time: %.2f\nStatus: %s\nConsole: %s\n",
        $result->{pid},
        strftime("[%a %B %d, %I:%M%P]", localtime($result->{startTime})),
        strftime("[%a %B %d, %I:%M%P]", localtime($result->{stopTime})),
        $upTime,
        $result->{status},
        $result->{output}
    );

    if ($result->{error}) {
        $status .= sprintf("Error: %s\n", $result->{error});
    }

    print $status;
    $self->{log}->addLine($status);
}

sub getStatus {
    my ($self, $ident) = @_;
    return $self->{results}->{$ident};
}

1;