#!/usr/bin/perl -w
use strict;
use List::Util qw(sum);
use Data::Dumper;

# 2019-08-25 08:32:10.824 Info: Merging 51 MB from /u01/MarkLogic/data/Forests/ml-xps-app-content-001-1/00012695 and /u01/MarkLogic/data/Forests/ml-xps-app-content-001-1/00012696 to /u01/MarkLogic/data/Forests/ml-xps-app-content-001-1/00012697, timestamp=15666535308241350
# 2019-08-25 08:32:11.337 Info: Merged 36 MB in 1 sec at 70 MB/sec to /u01/MarkLogic/data/Forests/ml-xps-app-content-001-1/00012697

my %merges = ();

while (<>) {
    my $line = $_;  chomp ($line);
    if ($line =~ /^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d+) (\S+):\s(.*)/) {
        my ($dt, $level, $text) = ($1, $2, $3);
        if      ($text =~ /Merging (\d+) MB from (.*) to (.+Forests.+)/) { 
            my ($mb, $from, $stand_path) = ($1, $2, $3);
            $stand_path =~ s/, timestamp.*//;
            $merges{$stand_path}{start_size} = $mb;
            $merges{$stand_path}{stand_path} = $stand_path;
            push @{$merges{$stand_path}{starts}}, $dt;
        } elsif ($text =~ /Merged (\d+) MB in .* to (.+)/) { 
            my ($mb, $stand_path) = ($1, $2);
            $merges{$stand_path}{end_size} = $mb;
            push @{$merges{$stand_path}{ends}}, $dt;
        } elsif ($text =~ /Merged (\d+) MB at \d+ .* to (.+)/) { 
            my ($mb, $stand_path) = ($1, $2);
            $merges{$stand_path}{end_size} = $mb;
            push @{$merges{$stand_path}{ends}}, $dt;
        } elsif ($text =~ /(Merging|Merged)/) {
            die "huh? $text\n   ($dt, $level, $text).\n";
        } else {
        }
    } else { print "line: $line"; }
}


# all accounted for?
# should be one each of start and end.
foreach my $stand_path (keys %merges) {
    my $stand = $merges{$stand_path};
    if (
        (! $stand->{starts}  ||  scalar @{$stand->{starts}} != 1) 
        ||
        (! $stand->{ends}  ||  scalar @{$stand->{ends}} != 1) 
    ) { print STDERR $stand_path, "  ", Dumper $stand; delete $merges{$stand_path}; }
    else { $stand->{start} = $stand->{starts}[0];  $stand->{end} = $stand->{ends}[0]; }
}

# print STDERR Dumper \%merges;


my @current_merge_ends = ();
my @current_merges = ();

# step through the stands in order of merge starts
#print "timestamp\tcurrent_merges\tcurrent_total_start_size\tcurrent_total_end_size\n";
print "timestamp    current_merges    current_total_start_size\n";
foreach my $stand_path (sort { $merges{$a}{starts}[0] cmp $merges{$b}{starts}[0] } keys %merges) {
    my $stand = $merges{$stand_path};
    my $now = $stand->{starts}[0];
    # just started, so onto the current list
    push @current_merges, $stand;
    # pare list to what's still not ended
    @current_merges = grep {$_->{ends}[0] gt $now} @current_merges;
    my $current_total_start_size = 0;
    my $current_total_end_size = 0;
    # total up the start and end size of each merge (yes, end in is the future)
    foreach my $stand (@current_merges) {
        $current_total_start_size += $stand->{start_size};
        $current_total_end_size += $stand->{end_size};
    }
    my $current_count = scalar @current_merges;
    #print "$now\t", $current_count, "\t", $current_total_start_size, "\t", $current_total_end_size, "\n";
    print "$now    $current_count    $current_total_start_size\n";
    if ($current_count > 10) {
        #print "    current total sizes:  $current_total_start_size.\n";
        foreach my $current_merge (@current_merges) {
            #print "    $current_merge->{stand_path}  =  $current_merge->{start_size} MB, $current_merge->{start} -> $current_merge->{end}.\n";
        }
    }
}

foreach my $stand_path (sort { $merges{$a}{starts}[0] cmp $merges{$b}{starts}[0] } keys %merges) {
    #print STDERR Dumper $merges{$stand_path};
}
