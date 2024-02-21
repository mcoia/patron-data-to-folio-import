#!/usr/bin/perl
package MOBIUS::Utils;

# Description: MOBIUS Utilities Class 
# Copyright (C) Year: 2023 

# Authors:
# Blake Graham-Henderson <blake@mobiusconsortium.org> William Scott Angel <scottangel@mobiusconsortium.org>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
# This code may be distributed under the same terms as Perl itself.

# Please notes that these modules are not products of or supported by the
# employers of the various contributors to the code.

=head1 NAME
MOBIUS::Utils - A simple utility class that provides some common functions

=head1 VERSION

Version 0.0.1

=head1 DESCRIPTION
 
MOBIUS is a vibrant, collaborative partnership of libraries providing access to shared information resources, services and expertise.

This is a simple utility class that provides some common functions

Usage:

  my $mobiusUtil = MOBIUS::Utils->new(); 
  my $config = $mobiusUtil->readConfFile($configFile);

=cut

# use strict;
# use warnings;
use MARC::Record;
use MARC::File;
use MARC::File::USMARC;
use MARC::Charset 'marc8_to_utf8';
use Net::FTP;
use MOBIUS::Loghandler;
use Data::Dumper;
use DateTime;
# use Expect;
#use Net::SSH::Expect;
use Encode;
use utf8;
use FreezeThaw qw(freeze thaw);
use Digest::SHA1;

=head1 CONSTRUCTOR

=head2 new()

Base constructor for the class. No constructor arguments. 

=cut

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}


=head2 readConfFile($filepath)

Reads a configuration file in the form of a key/value pair and assigns it to a HASH.

Example file: db.conf

  dbhost=pg_server.domain.com
  db=postgres
  dbuser=postgres
  dbpass=dbpassword
  port=5432

Example Code: 

  my $conf = $utils->readConfFile("db.conf");
  my $dbhost = $conf->{dbhost};
  my $db = $conf->{db};
  my $dbuser = $conf->{dbuser};
  my $dbpass = $conf->{dbpass};
  my $port = $conf->{port};

=cut

sub readConfFile
{
    my $self = shift;
    my $filepath = shift;

    my %ret = ();
    my $ret = \%ret;

    my $confFile = new Loghandler($filepath);
    if (!$confFile->fileExists())
    {
        print "Config File does not exist\n";
        undef $confFile;
        return false;
    }

    my @lines = @{$confFile->readFile()};
    chomp(@lines);

    undef $confFile;

    foreach my $line (@lines)
    {
        my $cur = $self->trim($line);
        my $len = length($cur);
        if ($len > 0 && substr($cur, 0, 1) ne "#")
        {
            my ($Name, $Value);
            my @s = split(/=/, $cur);
            $Name = shift @s;
            $Value = join('=', @s);
            $$ret{trim('', $Name)} = trim('', $Value);
        }
    }

    return \%ret;
}


=head2 readQueryFile($filepath)

Reads in a query file. It allows a perl developer to assign names to specific queries located inside a sql file.
This keeps the sql decoupled from the code.

What does a query file look like you might ask?

Well, It looks something like this.

Query File Example:
  # This is a commented out string.
  query_name_here~~select * from some_table;
  query_2~~select count(id) from some_table;

Implementation code:

  my $utils = MOBIUS::Utils->new();
  my $queries = $utils->readQueryFile("query-file-here.sql");
  my $query = $queries{"query_name_here"};
  my $query2 = $queries{"query_2"};

Query File Requirements:

=over 

=item * Use # to make comments

=item * You start with the name of your query.

=item * You use ~~ as a delimiter separating the name from the query.

=item * You must terminate your query with a semicolon;

=back

=cut

sub readQueryFile
{
    my $self = shift;
    my $filepath = shift;
    my %ret = ();
    my $ret = \%ret;

    my $confFile = Loghandler->new($filepath);
    if (!$confFile->fileExists())
    {
        print "Query file does not exist\n";
        undef $confFile;
        return false;
    }

    my @lines = @{$confFile->readFile()};
    undef $confFile;

    my $fullFile = "";
    foreach my $line (@lines)
    {
        $line =~ s/\n/ASDF!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!ASDF/g; #remove newline characters
        my $cur = trim('', $line);
        my $len = length($cur);
        if ($len > 0 && substr($cur, 0, 1) ne "#")
        {
            $line =~ s/\t//g;
            $fullFile .= " $line"; #collapse all lines into one string
        }
    }

    my @div = split(";", $fullFile); #split the string by semi colons
    foreach (@div)
    {
        my ($Name, $Value);
        ($Name, $Value) = split(/\~\~/, $_); #split each by the equals sign (left of equal is the name and right is the query
        $Value = trim('', $Value);
        $Name =~ s/ASDF!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!ASDF//g;    # just in case
        $Value =~ s/ASDF!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!ASDF/\n/g; # put the line breaks back in
        $$ret{trim('', $Name)} = $Value;
    }

    return \%ret;
}


=head2 makeEvenWidth($line,$width)

Makes a String variable a certain length.

  my $utils = MOBIUS::Utils->new();
  
  my $output = "Hello World!!!";
  my $utils->makeEvenWidth($output, 5);

This will output 
C<Hello>

=cut

sub makeEvenWidth #line, width
{

    my $self = shift;
    my $line = shift || return;
    my $width = shift || return;

    my $ret;

    $ret = $line;
    if (length($line) >= $width)
    {$ret = substr($ret, 0, $width);}
    else
    {
        while (length($ret) < $width)
        {$ret = $ret . " ";}
    }

    return $ret;

}


=head2 padLeft($line, $width, $fillChar)

Moves the $line text {n} number of spaces to the right filling in the spaces with your $fillChar. 

Example:
 
  my $utils = MOBIUS::Utils->new();
  print $utils->padLeft("Hello World!!!", 20, "X");

Output:

C<XXXXXXHello World!!!>

=cut

sub padLeft
{

    my $self = shift;
    my $line = shift || return;
    my $width = shift || return;
    my $fillChar = shift || return;

    my $ret;
    $ret = $line;
    if (length($line) >= $width)
    {
        $ret = substr($ret, 0, $width);
    }
    else
    {
        while (length($ret) < $width)
        {
            $ret = $fillChar . $ret;
        }
    }

    return $ret;

}


=head2 sendftp($hostname, $username, $pass, $remoteDir, $files, $log)

Send an array of files to an FTP server.

=cut

sub sendftp
{

    my $hostname = shift || return;
    my $username = shift || return;
    my $pass = shift || return;
    my $remoteDir = shift || return;
    my $files = shift || return;
    my $log = shift || return;

    $log->addLogLine("**********FTP starting -> $hostname with $username and $pass -> $remoteDir");

    my $ftp = Net::FTP->new($hostname, Debug => 0, Passive => 1)
        or die $log->addLogLine("Cannot connect to " . $hostname);

    $ftp->login($username, $pass)
        or die $log->addLogLine("Cannot login " . $ftp->message);

    $ftp->cwd($remoteDir)
        or die $log->addLogLine("Cannot change working directory ", $ftp->message);

    foreach my $file (@{$files})
    {
        $log->addLogLine("Sending file $file");
        $ftp->put($file)
            or die $log->addLogLine("Sending file $file failed");
    }

    $ftp->quit
        or die $log->addLogLine("Unable to close FTP connection");
    $log->addLogLine("**********FTP session closed ***************");

}


=head2 chooseNewFileName($path, $filename, $ext)

Constructs a new filename filepath. 

If there is a filename already in the given path it appends a sequential number to the filename. 

C<text.txt> becomes C<text1.txt>


Example: 

  my $utils = MOBIUS::Utils->new();
  my $filename = $utils->chooseNewFileName("/tmp", "temp-file", "txt");
  print "filename : $filename \n";

Output:   

 filename : /tmp/temp-file.txt

=cut

sub chooseNewFileName
{
    my $self = shift;
    my $path = shift;
    my $filename = shift;
    my $ext = shift;

    # Add trailing slash if there isn't one
    $path = $path . '/' if (substr($path, length($path) - 1, 1) ne '/');

    my $ret = 0;
    if (-d $path)
    {
        my $num = "";
        $ret = $path . $filename . $num . '.' . $ext;
        while (-e $ret)
        {
            if ($num eq "")
            {
                $num = -1;
            }
            $num = $num + 1;
            $ret = $path . $filename . $num . '.' . $ext;
        }
    }

    return $ret;
}


=head2 trim($string) 

Trims spaces from the beginning & end of a scalar string. 

Example: 

  my $utils = MOBIUS::Utils->new();
  my $string = "  this is our string.  ";
  my $trimmed = $utils->trim($string);
  print "[$trimmed]\n";

Output:

  [this is our string.] 
  
=cut

sub trim
{
    my $self = shift;
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}


=head1 findQuery($school, $platform, $addsOrCancels, $queries, $dbFromDate)






=cut

sub findQuery #self, DBhandler(object), school(string), platform(string), addsorcancels(string), queries
{
    my $self = shift;
    my $school = shift || return;
    my $platform = shift || return;
    my $addsOrCancels = shift || return;
    my $queries = shift || return;
    my $dbFromDate = shift;

    my $key = $platform . "_" . $school . "_" . $addsOrCancels;
    if (!$queries->{$key})
    {return "-1";}

    my $dt = DateTime->now; # Stores current date and time as datetime object
    my $ndt = DateTime->now;
    my $yesterday = $dt->subtract(days => 1);
    $yesterday = $yesterday->set_hour(0);
    $yesterday = $yesterday->set_minute(0);
    $yesterday = $yesterday->set_second(0);
    #$dt = $yesterday->add(days=>1); #midnight to midnight


    #
    # Now create the time string for the SQL query
    #

    my $fdate = $yesterday->ymd; # Retrieves date as a string in 'yyyy-mm-dd' format
    my $ftime = $yesterday->hms; # Retrieves time as a string in 'hh:mm:ss' format
    my $todate = $ndt;
    my $tdate = $todate->ymd;
    my $ttime = $yesterday->hms;

    # $dbFromDate = "2013-02-16 05:00:00";

    $dbFromDate = "$fdate $ftime" if (!$dbFromDate);

    my $dbToDate = "$tdate $ttime";
    my $query = $queries->{$key};
    $query =~ s/\$dbFromDate/$dbFromDate/g;
    $query =~ s/\$dbToDate/$dbToDate/g;

    return $query;

}


=head1 makeCommaFromArray($array, $delimiter)

Convert an array into a quoted, delimited string. 

Example: 

  my $utils = MOBIUS::Utils->new();
  my @a = (
      'this',
      'that',
      'and',
      'the',
      'other'
  );
  my $string = $utils->makeCommaFromArray(\@a, ",");
  print "string: [$string]\n";

Output:
C<string: ["this","that","and","the","other"]>

=cut

sub makeCommaFromArray
{

    my $self = shift;
    my $array = shift;
    my $delimiter = shift || ',';

    my @array = @{$array};

    my $ret = "";

    for my $i (0 .. $#array)
    {
        $ret .= "\"" . $array[$i] . "\"" . $delimiter;
    }
    $ret = substr($ret, 0, length($ret) - (length($delimiter)));
    return $ret;
}


=head1 makeArrayFromComma($string)

Pass in a string of values seperated by a comma and get back an array. 

Example:
 
  my $string = "admin,user,guest,other";
  my $array = $utils->makeArrayFromComma($string);
  print "$_\n" for (@{$a});

Output:

  admin
  user
  guest
  other

=cut

sub makeArrayFromComma
{
    my $self = shift;

    my $string = shift;
    my @array = split(/,/, $string);
    for my $y (0 .. $#array)
    {
        @array[$y] = trim('', @array[$y]);
    }
    return \@array;
}

=head1 insertDataIntoColumn($ret, $data, $column)

#1 based column position

=cut

sub insertDataIntoColumn
{
    my $self = shift;
    my $ret = shift;
    my $data = shift;
    my $column = shift;

    if (length($ret) < ($column - 1))
    {
        while (length($ret) < ($column - 1))
        {
            $ret .= " ";
        }
        $ret .= $data;
    }
    else
    {
        my @ogchars = split("", $ret);
        my @insertChars = split("", $data);
        for my $i (0 .. $#insertChars)
        {
            $ogchars[$i + $column - 1] = $insertChars[$i];
        }

        $ret = "";
        foreach (@ogchars)
        {$ret .= $_;}

    }

    return $ret;

}

# TODO: take this out? It's not used anywhere and it's basically this ==> if($s1 eq $s2)
sub compareStrings
{
    my $self = shift;
    my $string1 = shift;
    my $string2 = shift;
    if (length($string1) != length($string2))
    {
        return 0;
    }
    my @chars1 = split("", $string1);
    my @chars2 = split("", $string2);
    for my $i (0 .. $#chars1)
    {
        my $tem1 = @chars1[$i];
        my $tem2 = @chars2[$i];
        my $t1 = ord($tem1);
        my $t2 = ord($tem2);

        if (0)
        {
            if (ord($tem1) != ord($tem2))
            {
                return 0;
            }
        }
        if (@chars1[$i] ne @chars2[$i])
        {
            return 0;
        }
    }

    return 1;

}

# TODO: take this out? It's not used anywhere.
sub expectSSHConnect
{
    my $self = shift;
    my $login = shift;
    my $pass = shift;
    my $host = shift;
    # my $loginPrompt = shift;
    my @loginPrompt = @{@_[4]};
    # my $allPrompts = shift;
    my @allPrompts = @{@_[5]};

    my $errorMessage = 1;

    my $h = Net::SSH::Expect->new(
        host     => $host,
        password => $pass,
        user     => $login,
        raw_pty  => 1
    );

    $h->timeout(30);
    my $login_output = $h->login();

    if (index($login_output, "Choose one (D,C,M,B,A,Q)") > -1)
    {
        $h->send("c");
        $i = 0;
        my $screen = $h->read_all();
        foreach (@allPrompts)
        {
            if ($i <= $#allPrompts)
            {
                my @thisArray = @{$_};
                my $b = 0;
                foreach (@thisArray)
                {
                    if ($b <= $#thisArray)
                    {
                        if (index($screen, @thisArray[$b]) > -1)
                        {
                            ## CANNOT GET A CARRIAGE RETURN TO SEND TO THE SSH PROMPT
                            ## HERE IS SOME OF THE CODE I HAVE TRIED (COMMENTED OUT)
                            ## BGH
                            #if(index(@thisArray[$b+1],"\r")>-1)
                            #{
                            #my $l = length(@thisArray[$b+1]);
                            #my $in = index(@thisArray[$b+1],"\r");
                            #my $pos = $in;
                            #print "Len: $l index: $in $pos: $pos\n";

                            #my $cmd = substr(@thisArray[$b+1],0,index(@thisArray[$b+1],"\r"));
                            #print "Converted cmd to \"$cmd\"\n";
                            #$screen = $h->exec($cmd);

                            #}
                            #else
                            #{
                            $h->send(@thisArray[$b + 1]);
                            $screen = $h->read_all();
                            #}
                            #print "Found \"".@thisArray[$b]."\"\nSending (\"".@thisArray[$b+1]."\")\n";
                            $b++;

                        }
                        else
                        {
                            #print "Didn't find \"".@thisArray[$b]."\" - Moving onto the next set of prompts\n";
                            #print "Screen is now\n$screen\n";
                            $b = $#thisArray; ## Stop looping in this sub prompt tree
                        }
                    }
                    $b++;
                }
                $i++;
            }

        }

    }
    else
    {
        $errorMessage = "Didn't get the expected login prompt";
    }

    eval {$h->close();};
    if ($@)
    {
        $errorMessage = "Error closing SSH connect";
    }
    return $errorMessage;

}

sub expectConnect
{
    my $self = shift;
    my $login = shift;
    my $pass = shift;
    my $host = shift;

    my $allPrompts = shift;
    my @allPrompts = @{$allPrompts};
    my $keyfile = shift;
    my $errorMessage = "";
    my @promptsResponded;
    my $timeout = 30;

    my $connectVar = "ssh $login\@$host";
    $connectVar .= ' -i ' . $keyfile if $keyfile;
    my $h = Expect->spawn($connectVar);
    #turn off command output to the screen
    $h->log_stdout(0);
    my $acceptkey = 1;
    unless ($h->expect($timeout, "yes/no"))
    {$acceptkey = 0;}
    if ($acceptkey)
    {print $h "yes\r";}
    if (!$keyfile)
    {
        unless ($h->expect($timeout, "password"))
        {return "No Password Prompt";}
    }
    print $h $pass . "\r" if !$keyfile;
    unless ($h->expect($timeout, ":"))
    {} #there is a quick screen directly after logging in

    $i = 0;
    #print Dumper(@allPrompts);
    foreach (@allPrompts)
    {
        if ($i <= $#allPrompts)
        {
            my @thisArray = @{$_};
            my $b = 0;
            foreach (@thisArray)
            {
                if ($b < ($#thisArray - 1))
                {
                    #Turn on debugging:
                    #$h->exp_internal(1);
                    my $go = 1;
                    unless ($h->expect(@thisArray[$b], @thisArray[$b + 1]))
                    {
                        if (@thisArray[$b + 3] == 1) #This value tells us weather it's ok or not if that prompt was not found
                        {
                            my $screen = $h->before();
                            $screen =~ s/\[/\r/g;
                            my @chars1 = split("", $screen);
                            my $output;
                            my $pos = 0;
                            for my $i (0 .. $#chars1)
                            {
                                if ($pos < $#chars1)
                                {
                                    if (@chars1[$pos] eq ';')
                                    {
                                        $pos += 4;
                                    }
                                    else
                                    {
                                        $output .= @chars1[$pos];
                                        $pos++;
                                    }
                                }
                            }
                            $errorMessage .= "Prompt not found: '" . @thisArray[$b + 1] . "' in " . @thisArray[$b] . " seconds\r\n\r\nScreen looks like this:\r\n$output\r\n";
                        }
                        $b = $#thisArray;
                        $go = 0;
                    }
                    if ($go)
                    {
                        print $h @thisArray[$b + 2];
                        my $t = @thisArray[$b + 2];
                        $t =~ s/\r//g;
                        push(@promptsResponded, "'" . @thisArray[$b + 1] . "' answered '$t'");
                    }
                    $b++;
                    $b++;
                    $b++;
                }
                $b++;
            }
            $i++;
        }
    }

    $h->soft_close();

    $h->hard_close();
    if (length($errorMessage) == 0)
    {
        $errorMessage = 1;
    }
    push(@promptsResponded, $errorMessage);
    return \@promptsResponded;

}

sub marcRecordSize
{
    my $count = 0;
    my $marc = @_[1];
    my $out = "";
    eval {$out = $marc->as_usmarc();};
    if ($@)
    {
        return 0;
    }
    #print "size: ".length($out)."\n";
    return length($out);

    ## This code below should not execute
    my @fields = $marc->fields();
    foreach (@fields)
    {

        if ($_->is_control_field())
        {
            my $subs = $_->data();
            #print "adding control $subs\n";
            $count += length($subs);
        }
        else
        {
            my @subs = $_->subfields();
            foreach (@subs)
            {
                my @t = @{$_};
                for my $i (0 .. $#t)
                {
                    #print "adding ".@t[$i]."\n";
                    $count += length(@t[$i]);
                }
            }
        }
    }
    #print $count."\n";
    return $count;

}

sub trucateMarcToFit
{
    my $marc = @_[1];
    local $@;
    my $count = marcRecordSize('', $marc);
    #print "Recieved $count\n";
    if ($count)
    {
        my @fields = $marc->fields();
        my %fieldsToChop = ();
        foreach (@fields)
        {
            my $marcField = $_;
            #print $marcField->tag()."\n";

            if (($marcField->tag() > 899) && ($marcField->tag() != 907) && ($marcField->tag() != 998) && ($marcField->tag() != 901))
            {
                my $id = (scalar keys %fieldsToChop) + 1;
                #print "adding to chop list: $id\n";
                $fieldsToChop{$id} = $marcField;
            }
        }
        my %deletedFields = ();

        my $worked = 2;

        while ($count > 99999 && ((scalar keys %deletedFields) < (scalar keys %fieldsToChop)))
        {
            $worked = 1;
            my $foundOne = 0;
            while ((my $internal, my $value) = each(%fieldsToChop))
            {
                if (!$foundOne)
                {
                    if (!exists($deletedFields{$internal}))
                    {
                        #print "$internal going onto deleted\n";
                        $deletedFields{$internal} = 1;
                        $marc->delete_field($value);
                        #print "Chopping: ".$value->tag()."\n";#." contents: ".$value->as_formatted()."\n";
                        #$count-=$internal;
                        $count = marcRecordSize('', $marc);
                        #print "Now it's $count\n";
                        $foundOne = 1;
                    }
                }
            }
            #print "deletedFields: ".(scalar keys %deletedFields)."\nto chop: ".(scalar keys %fieldsToChop)."\n";
        }
        if ($count > 99999)
        {
            $worked = 0;
        }
        #print $marc->as_formatted();
        my @ret = ($marc, $worked);
        return \@ret;
    }
    else
    {
        return ($marc, 0);
    }

}

sub boxText
{
    shift;
    my $text = shift;
    my $hChar = shift;
    my $vChar = shift;
    my $padding = shift;
    my $ret = "";
    my $totalLength = length($text) + (length($vChar) * 2) + ($padding * 2) + 2;
    my $heightPadding = ($padding / 2 < 1) ? 1 : $padding / 2;

    # Draw the first line
    my $i = 0;
    while ($i < $totalLength)
    {
        $ret .= $hChar;
        $i++;
    }
    $ret .= "\n";
    # Pad down to the data line
    $i = 0;
    while ($i < $heightPadding)
    {
        $ret .= "$vChar";
        my $j = length($vChar);
        while ($j < ($totalLength - (length($vChar))))
        {
            $ret .= " ";
            $j++;
        }
        $ret .= "$vChar\n";
        $i++;
    }

    # data line
    $ret .= "$vChar";
    $i = -1;
    while ($i < $padding)
    {
        $ret .= " ";
        $i++;
    }
    $ret .= $text;
    $i = -1;
    while ($i < $padding)
    {
        $ret .= " ";
        $i++;
    }
    $ret .= "$vChar\n";
    # Pad down to the last
    $i = 0;
    while ($i < $heightPadding)
    {
        $ret .= "$vChar";
        my $j = length($vChar);
        while ($j < ($totalLength - (length($vChar))))
        {
            $ret .= " ";
            $j++;
        }
        $ret .= "$vChar\n";
        $i++;
    }
    # Draw the last line
    $i = 0;
    while ($i < $totalLength)
    {
        $ret .= $hChar;
        $i++;
    }
    $ret .= "\n";
    return $ret;
}

=head1 generateRandomString(length)

Generate a random string of a specified length.
If a length isn't specified than length is set to 8.

=cut
sub generateRandomString
{
    my $self = shift;
    my $length = @_[1] | 8;
    my $i = 0;
    my $ret = "";
    my @letters = ('a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z');
    my $letterl = $#letters;
    my @sym = ('@', '#', '$');
    my $syml = $#sym;
    my @nums = (1, 2, 3, 4, 5, 6, 7, 8, 9, 0);
    my $nums = $#nums;
    my @all = ([ @letters ], [ @sym ], [ @nums ]);
    while ($i < $length)
    {
        #print "first rand: ".$#all."\n";
        my $r = int(rand($#all + 1));
        #print "Random array: $r\n";
        my @t = @{@all[$r]};
        #print "rand: ".$#t."\n";
        my $int = int(rand($#t + 1));
        #print "Random value: $int = ".@{$all[$r]}[$int]."\n";
        $ret .= @{$all[$r]}[$int];
        $i++;
    }

    return $ret;
}

sub getHash
{
    my $self = shift;
    my $data = shift;
    return $self->calcSHA1(freeze($data));
}

sub calcSHA1
{
    my $self = shift;
    my $data = shift;
    my $sha1 = Digest::SHA1->new;
    $sha1->add($data);
    return $sha1->hexdigest;
}

sub is_integer
{
    defined @_[1] && @_[1] =~ /^[+-]?\d+$/;
}

1;

__END__

=head1 COPYRIGHT AND LICENSE

Description: MOBIUS Utilities Class 
Copyright (C) Year: 2023 
    
Authors:
Blake Graham-Henderson <blake@mobiusconsortium.org> William Scott Angel <scottangel@mobiusconsortium.org>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
This code may be distributed under the same terms as Perl itself.

Please note that these modules are not products of or supported by the
employers of the various contributors to the code.

=head1 AUTHORS

=over 1

=item * Blake Graham-Henderson <blake@mobiusconsortium.org>

=item * William Scott Angel <scottangel@mobiusconsortium.org>

=back

=cut

