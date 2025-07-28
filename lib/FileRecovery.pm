package FileRecovery;
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub recoverFileFromTracker
{
    my $self = shift;
    my $file_tracker_id = shift;
    my $recovery_path = shift;
    
    # Get file contents from database
    my $query = "SELECT path, contents, institution_id FROM patron_import.file_tracker WHERE id = ?";
    my $result = $main::dao->query($query, [$file_tracker_id]);
    
    if (!$result || !@$result) {
        print "Error: File tracker ID $file_tracker_id not found\n";
        return 0;
    }
    
    my ($original_path, $contents, $institution_id) = @{$result->[0]};
    
    if (!$contents) {
        print "Error: No contents stored for file tracker ID $file_tracker_id\n";
        return 0;
    }
    
    # Write contents to recovery path
    open(my $fh, '>', $recovery_path) or do {
        print "Error: Cannot write to recovery path $recovery_path: $!\n";
        return 0;
    };
    
    print $fh $contents;
    close($fh);
    
    print "File recovered from database to: $recovery_path\n";
    print "Original path was: $original_path\n";
    print "Institution ID: $institution_id\n";
    
    return 1;
}

sub listBackedUpFiles
{
    my $self = shift;
    my $institution_id = shift;
    my $job_id = shift;
    
    my $query = "SELECT id, path, size, lastModified, job_id, institution_id FROM patron_import.file_tracker";
    my $params = [];
    
    if ($institution_id) {
        $query .= " WHERE institution_id = ?";
        push @$params, $institution_id;
        
        if ($job_id) {
            $query .= " AND job_id = ?";
            push @$params, $job_id;
        }
    } elsif ($job_id) {
        $query .= " WHERE job_id = ?";
        push @$params, $job_id;
    }
    
    $query .= " ORDER BY lastModified DESC";
    
    my $results = $main::dao->query($query, $params);
    
    print "Backed up files:\n";
    print "ID\tPath\tSize\tModified\tJob ID\tInstitution ID\n";
    print "-" x 80 . "\n";
    
    for my $row (@$results) {
        my ($id, $path, $size, $modified, $j_id, $i_id) = @$row;
        my $mod_time = localtime($modified);
        print "$id\t$path\t$size\t$mod_time\t$j_id\t$i_id\n";
    }
    
    return $results;
}

1;