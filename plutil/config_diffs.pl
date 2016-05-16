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
    map { my ($base) = $_ =~ /^([a-z]+)/; { 'filename' => $_, 'base' => $1} }
    grep { /\.xml$/ }
    readdir ($dir);
close ($dir);

# add timestamps and sort by them
foreach my $file (@files) { file_timestamp ($file) }
@files = sort { $a->{timestamp} <=> $b->{timestamp} } @files;

# initialize the current_files to start, and preceding files
my %current_files = ();
my %bases = ();
foreach my $file (@files) {
    my $base = $file->{base};
    $bases{$base} = 0;
    if (exists $current_files{$base}) {
        $file->{preceding} = $current_files{$base};
    }
    $current_files{$base} = $file->{filename};
}
my $number_of_bases = scalar keys %bases;


#init groups
my @groups = ();
my $first = shift @files;
my %bases_seen = (
    $first->{base} => 1,
);
new_group (\@groups, $first);
while (scalar keys %bases_seen < $number_of_bases) {
    my $next = shift @files;
    unless (exists $next->{filename}) { die "Huh?  File: ", Dumper ($next), "\n"; }
    $bases_seen{$next->{base}}++;
    new_group_file (\@groups, $next);
}


my $group_window = seconds_in_ticks (120);

# finish groups
while (scalar @files) {
    my $top_group = $groups[-1];
    my $next = shift @files;
    if ($next->{timestamp} - $top_group->{end_timestamp} > $group_window) {
        new_group (\@groups, $next);
    } else {
        new_group_file (\@groups, $next);
    }
}


# dump_current (\%current_files);

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

sub current_files {
    my ($files) = @_;
    foreach my $base (sort keys %$files) {
        print "    $files->{$base}\n";
    }
}

# dump out the groups in order
sub dump_groups {
    my ($groups) = @_;
    my %files;
    foreach my $group (@$groups) {
        print "\n\n\n";
        print "=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* start: ", timestamp_to_datetime ($group->{start_timestamp}), "\n";
        foreach my $file_diff (@{$group->{files}}) {
            $files{$file_diff->{base}} = $file_diff->{filename};
            if ($file_diff->{preceding}) {
                print "\n\n-------------------------------------\n";
            }
            print '',
                  ($file_diff->{preceding} ? "$file_diff->{preceding} -> " : ''),
                  $file_diff->{filename}, 
                  ' @ ', timestamp_to_datetime ($file_diff->{timestamp}), "\n";
            #print "\n-------------------------------------\n";
            if ($file_diff->{preceding}) {
                print "\n\n";
                system "diff $file_diff->{preceding} $file_diff->{filename}";
            }
        }
        print "\n\n";
        dump_current (\%files);
        print "=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=*=* end: ", timestamp_to_datetime ($group->{end_timestamp}), "\n";
    }
}

sub new_group_file {
    my ($groups, $file) = @_;
    push @{$groups->[-1]{files}}, $file;
    $groups->[-1]{end_timestamp} = $file->{timestamp};
}

sub new_group {
    my ($groups, $file) = @_;
    push @$groups, {
        start_timestamp => $file->{timestamp},
        end_timestamp => $file->{timestamp},
        files => [$file]
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


sub file_timestamp {
    my ($file) = @_;
    $file->{timestamp} = 0;
    open (my $fh, "<", $file->{filename}) or die "cannot open $file->{filename}: $!";
    for (my $i = 0; $i < 5; $i++) {
        my $line = <$fh>;
        if ($line =~ /timestamp\s*=\s*['"](\d+)['"]/) {
            $file->{timestamp} = $1;
            last;
        }
    }
    close ($fh);
};
