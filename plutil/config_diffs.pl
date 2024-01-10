#!/usr/bin/perl -w
use strict;
use POSIX qw(strftime);
use Data::Dumper;

# Timestamps may not be exact, and of course tz shifts can happen.

# print time() * 10000000;

my $dirpath = '.';
my $dir;
opendir ($dir, $dirpath);
my @files =
    map { my ($base, $version) = $_ =~ /^([a-z]+)(_\d+)?/; { 'filename' => $_, 'base' => $base, 'version' => $version } }
    grep { /\.xml$/ }
    readdir ($dir);
close ($dir);

# add timestamps, fix up versions, and sort by timestamp, version
foreach my $file (@files) {
    file_timestamp ($file);
    if ($file->{version}) { $file->{version} =~ s/^_// } else { $file->{version} = 0; }
}
@files = sort {
    if ($a->{timestamp} != $b->{timestamp}) {
        $a->{timestamp} <=> $b->{timestamp}
    } else {
        $b->{version} <=> $a->{version}
    }
} @files;

dump_sorted_files (@files);

# create timestamp-ordered diffs and init groups
my @groups = ();
# this is max gap between actions that will be grouped.
my $group_window = seconds_in_ticks (120);
my %current_bases = ();

foreach my $file (@files) {
    my $base = $file->{base};
    if (exists $current_bases{$base}) {
        my $diff = {
            older => $current_bases{$base},
            newer => $file,
            # timestamp is time of change
            timestamp => $file->{timestamp},
        };
        # update current for base and current set
        $current_bases{$base} = $file;
        $diff->{current} = join ', ', sort map { $_->{filename} } values %current_bases;
        # add to group or start first
        if (scalar @groups) {
            # add to current, or create next
            my $current_group_timestamp = $groups[-1][-1]{timestamp};
            if ($diff->{timestamp} - $current_group_timestamp > $group_window) {
                # new group
                push @groups, [$diff];
            } else {
                # add to mr group
                push @{$groups[-1]}, $diff;
            } 
        } else {
            # first group
            push @groups, [$diff];
            next;
        }
    } else {
        $current_bases{$base} = $file;
    }
}

#print Dumper \@groups;

dump_groups (\@groups);

# for each group
#     ======
#     print start time
#     for each file diff
#          print timestamp, print file from -> to, print diff
#     print end time
#     ======

sub timestamp_to_datetime {
    my ($timestamp) = @_;
    strftime "%Y-%m-%d %H:%M:%S", localtime ($timestamp / 10000000);
}

# dump out the groups in order
sub dump_groups {
    my ($groups) = @_;
    my %files;
    my $group_number = 0;
    foreach my $group (@$groups) {
        $group_number++;
        print "\n\n\n";
        print "=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* change group number $group_number.  start: ", timestamp_to_datetime ($group->[0]{timestamp}), "\n\n";
        my $diff_number = 0;
        my ($older, $newer);
        foreach my $file_diff (@{$group}) {
            $diff_number++;
            if ($diff_number > 1) { print "\n-------------------------------------\n"; }
            ($older, $newer) = @{$file_diff}{'older','newer'};
            print "$older->{filename} -> $newer->{filename} @ ", timestamp_to_datetime ($newer->{timestamp}), "\n";
            print "\n-------------------------------------\n";
            print "\n\n";
            system "diff -C 5 $older->{filename} $newer->{filename}";
            print "\n";
            print "Current file set (so far): ", $file_diff->{current}, ".\n";
            print "\n\n";
        }
        print "\n\n";
        print "=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* end: ", timestamp_to_datetime ($newer->{timestamp}), "\n";
    }
}

sub seconds_in_ticks {
    my ($seconds) = @_;
    # return ticks
    return $seconds * 10000000;
}

sub dump_current {
    my ($current) = @_;
    print "\n";
    print "* current file set\n";
    foreach my $base (sort keys %$current) {
        print "    $current->{$base}\n";
    }
};

sub dump_sorted_files {
    my (@files) = @_;
    print "\n=============== sorted files=========\n\n";
    foreach my $file (@files) {
        printf '%-17s', $file->{filename};
        print ' @ ', timestamp_to_datetime ($file->{timestamp}), "\n";
    }
    print "\n=====================================\n\n";
};

sub file_timestamp {
    my ($file) = @_;
    # default of 1969-12-31 19:00:00 or so
    $file->{timestamp} = 0;
    open (my $fh, "<", $file->{filename}) or die "cannot open $file->{filename}: $!";
    for (my $i = 0; $i < 5; $i++) {
        my $line = <$fh>;
        unless ($line) { next }
        if ($line =~ /timestamp\s*=\s*['"](\d+)['"]/) {
            $file->{timestamp} = $1;
            last;
        }
    }
    if ($file->{timestamp} == 0) {
        print STDERR "No timestamp for $file->{filename}.\n";
    }
    close ($fh);
};
