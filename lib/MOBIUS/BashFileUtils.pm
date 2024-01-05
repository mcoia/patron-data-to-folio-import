package MOBIUS::BashFileUtils;
use strict;
use warnings FATAL => 'all';

sub new
{
    my $class = shift;
    my $self = {
        'VERSION' => '1.0',
        'path'    => shift,
    };
    bless $self, $class;
    return $self;
}

sub printVersion
{
    my $self = shift;
    print "BashFileUtils v$self->{VERSION}\n";
}

sub getFilePermissions
{
    my $self = shift;
    my $file = shift;

    my $permissions = `stat -c "%a" $file`;
    chomp $permissions;

    return $permissions;
}

sub findFileByPath
{
    my $self = shift;
    my $filename = shift;
    my $path = shift;
    print "find $path -name \"$filename\"\n";
    my @command = `find $path -name "$filename"`;
    chomp @command;

    # fix the \n line endings 
    # $_ =~ s/\n$// for (@command);
    # chomp @command; <== does exactly this!

    return \@command;
}

sub listDirectories
{
    my $self = shift;
    my $path = shift || $self->{PATH};

    $path .= "/" unless ($path =~ /\/$/);

    my @command = `ls -d $path*`;
    chomp @command;

    return \@command;
}

sub listFiles
{
    my $self = shift;
    my $path = shift || $self->{PATH};

    my @command = `find $path -maxdepth 1 -type f`;
    chomp @command;

    return \@command;
}

sub diffFiles
{
    my $self = shift;
    my $file1 = shift;
    my $file2 = shift;

    print "file1: $file1\n";
    print "file2: $file2\n";

    return `diff $file1 $file2`;

}

1;