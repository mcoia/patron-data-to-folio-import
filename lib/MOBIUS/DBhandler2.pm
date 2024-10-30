#!/usr/bin/perl
package DBhandler;

use strict;
use warnings;
use v5.10;

our $VERSION = '2.0.0';

use DBI;
use DBD::Pg;
use Carp qw(croak);
use Time::HiRes qw(time);
use Log::Log4perl qw(:easy);
use Scalar::Util qw(weaken);
use POSIX qw(strftime);

# Constants
use constant {
    DEFAULT_PORT            => 5432,
    DEFAULT_MAX_CONNECTIONS => 5,
    DEFAULT_BATCH_SIZE      => 1000,
    STATEMENT_CACHE_SIZE    => 100,
    CONNECTION_TIMEOUT      => 30,
    IDLE_TIMEOUT            => 300,
};

# Connection pool storage
my %_connection_pools;
my %_prepared_statements;

sub new
{
    my ($class, %params) = @_;

    # Validate required parameters
    for my $required (qw(dbname host login password))
    {
        croak "Missing required parameter: $required"
            unless exists $params{$required};
    }

    my $self = {
        dbname          => $params{dbname},
        host            => $params{host},
        login           => $params{login},
        password        => $params{password},
        port            => $params{port} || DEFAULT_PORT,
        max_connections => $params{max_connections} || DEFAULT_MAX_CONNECTIONS,
        connections     => [],
        statement_cache => {},
        last_cleanup    => time(),
    };

    bless $self, $class;

    # Initialize connection pool
    $self->_initialize_pool();

    return $self;
}

sub _initialize_pool
{
    my ($self) = @_;

    my $pool_key = $self->_get_pool_key();
    $_connection_pools{$pool_key} //= {
        connections  => [],
        in_use       => {},
        last_cleanup => time(),
    };

    # Create initial connection
    $self->_add_connection_to_pool();
}

sub _get_pool_key
{
    my ($self) = @_;
    return join(':', $self->{dbname}, $self->{host}, $self->{port}, $self->{login});
}

sub _add_connection_to_pool
{
    my ($self) = @_;

    my $conn = eval {
        DBI->connect(
            "DBI:Pg:dbname=$self->{dbname};host=$self->{host};port=$self->{port}",
            $self->{login},
            $self->{password},
            {
                AutoCommit        => 1,
                RaiseError        => 1,
                PrintError        => 0,
                pg_enable_utf8    => 1,
                pg_server_prepare => 1,
                HandleError       => sub {
                    my ($err, $dbh) = @_;
                    ERROR("Database error: $err");
                    die $err;
                },
            }
        );
    };

    if ($@)
    {
        croak "Failed to create database connection: $@";
    }

    my $pool_key = $self->_get_pool_key();
    push @{$_connection_pools{$pool_key}{connections}}, {
        handle    => $conn,
        created   => time(),
        last_used => time(),
    };
}

sub _get_connection
{
    my ($self) = @_;

    my $pool_key = $self->_get_pool_key();
    my $pool = $_connection_pools{$pool_key};

    # Clean up dead connections
    $self->_cleanup_pool() if time() - $pool->{last_cleanup} > IDLE_TIMEOUT;

    # Find available connection
    for my $conn (@{$pool->{connections}})
    {
        next if $pool->{in_use}{$conn->{handle}};

        if ($conn->{handle}->ping)
        {
            $pool->{in_use}{$conn->{handle}} = 1;
            $conn->{last_used} = time();
            return $conn->{handle};
        }
    }

    # Create new connection if pool isn't full
    if (@{$pool->{connections}} < $self->{max_connections})
    {
        $self->_add_connection_to_pool();
        my $conn = $pool->{connections}->[-1];
        $pool->{in_use}{$conn->{handle}} = 1;
        return $conn->{handle};
    }

    # Wait for available connection
    my $timeout = time() + CONNECTION_TIMEOUT;
    while (time() < $timeout)
    {
        for my $conn (@{$pool->{connections}})
        {
            next if $pool->{in_use}{$conn->{handle}};
            if ($conn->{handle}->ping)
            {
                $pool->{in_use}{$conn->{handle}} = 1;
                $conn->{last_used} = time();
                return $conn->{handle};
            }
        }
        select(undef, undef, undef, 0.1);
    }

    croak "Couldn't get database connection from pool within timeout period";
}

sub _release_connection
{
    my ($self, $dbh) = @_;

    my $pool_key = $self->_get_pool_key();
    delete $_connection_pools{$pool_key}{in_use}{$dbh};
}

sub _cleanup_pool
{

    my $self = shift;
    my $pool_key = $self->_get_pool_key();
    my $pool = $_connection_pools{$pool_key};

    my $now = time();
    my @active_connections;

    for my $conn (@{$pool->{connections}})
    {
        if ($now - $conn->{last_used} > IDLE_TIMEOUT)
        {
            eval {$conn->{handle}->disconnect};
        }
        elsif ($conn->{handle}->ping)
        {
            push @active_connections, $conn;
        }
    }

    $pool->{connections} = \@active_connections;
    $pool->{last_cleanup} = $now;
}

sub query
{

    my $self = shift;
    my $sql = shift;
    my $params = shift;
    my $options = shift;

    my $dbh = $self->_get_connection();
    my $results = eval {
        my $sth = $self->_prepare_cached($dbh, $sql);

        if ($params && ref($params) eq 'ARRAY')
        {
            $sth->execute(@$params);
        }
        else
        {
            $sth->execute();
        }

        my @results;
        while (my $row = $sth->fetchrow_arrayref)
        {
            push @results, [ map {
                defined $_ ? ($_ =~ s/\xa0/ /gr) : undef
            } @$row ];
        }

        return \@results;
    };

    my $error = $@;
    $self->_release_connection($dbh);
    die $error if $error;

    return $results;
}

sub process_in_batches
{
    my ($self, $sql, $batch_size, $callback, $params) = @_;

    $batch_size ||= DEFAULT_BATCH_SIZE;

    my $dbh = $self->_get_connection();
    eval {
        my $sth = $self->_prepare_cached($dbh, $sql);

        if ($params && ref($params) eq 'ARRAY')
        {
            $sth->execute(@$params);
        }
        else
        {
            $sth->execute();
        }

        my @batch;
        while (my $row = $sth->fetchrow_arrayref)
        {
            push @batch, [ map {
                defined $_ ? ($_ =~ s/\xa0/ /gr) : undef
            } @$row ];

            if (@batch >= $batch_size)
            {
                $callback->(\@batch);
                @batch = ();
            }
        }

        $callback->(\@batch) if @batch;
    };

    my $error = $@;
    $self->_release_connection($dbh);
    die $error if $error;
}

sub _prepare_cached
{
    my ($self, $dbh, $sql) = @_;

    my $cache_key = join(':', $self->_get_pool_key(), $sql);

    unless (exists $_prepared_statements{$cache_key})
    {
        # Limit cache size
        if (keys %_prepared_statements >= STATEMENT_CACHE_SIZE)
        {
            my @old_keys = sort {
                $_prepared_statements{$a}{last_used} <=>
                    $_prepared_statements{$b}{last_used}
            } keys %_prepared_statements;

            delete $_prepared_statements{shift @old_keys};
        }

        $_prepared_statements{$cache_key} = {
            statement => $dbh->prepare($sql),
            last_used => time(),
        };
    }

    $_prepared_statements{$cache_key}{last_used} = time();
    return $_prepared_statements{$cache_key}{statement};
}

sub update
{
    my ($self, $sql, $params) = @_;

    my $dbh = $self->_get_connection();
    my $result = eval {
        my $sth = $self->_prepare_cached($dbh, $sql);

        if ($params && ref($params) eq 'ARRAY')
        {
            $sth->execute(@$params);
        }
        else
        {
            $sth->execute();
        }

        return $sth->rows;
    };

    my $error = $@;
    $self->_release_connection($dbh);
    die $error if $error;

    return $result;
}

sub begin_work
{
    my ($self) = @_;
    my $dbh = $self->_get_connection();
    $dbh->begin_work;
    return $dbh;
}

sub commit
{
    my ($self, $dbh) = @_;
    $dbh->commit;
    $self->_release_connection($dbh);
}

sub rollback
{
    my ($self, $dbh) = @_;
    $dbh->rollback;
    $self->_release_connection($dbh);
}

sub DESTROY
{
    my ($self) = @_;

    my $pool_key = $self->_get_pool_key();
    if (my $pool = $_connection_pools{$pool_key})
    {
        for my $conn (@{$pool->{connections}})
        {
            eval {$conn->{handle}->disconnect};
        }
        delete $_connection_pools{$pool_key};
    }
}

1;