#!/usr/bin/perl -w

$| = 1;

use strict;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use List::Util qw(sum);

my $MAX_STATIC_THREADS_LIST = 20;

my @filenames = @ARGV;

my $stats = { dump => 0 };
my $threads = { };

for my $filename (@filenames) {  do_file ($stats, $filename) }

ready_stats ($stats);

dump_stats ($stats);
dump_static_threads ($stats);
dump_tree ($stats);

#print STDERR Dumper $stats;


########### subs

sub dump_stats {
    my ($stats) = @_;
    open my $fh, ">", "stack-stats.out";

    foreach my $sid (sort { $stats->{sig_sort_keys}{$b} <=> $stats->{sig_sort_keys}{$a} } (keys %{$stats->{sig_sort_keys}})) {
        print $fh "\n========================================================= $sid\n";
        foreach my $file_index (0 .. $#{$stats->{filenames}}) {
            # avoid many rows of zeros
            if (sum (@{$stats->{sig_counts}[$file_index]{$sid}}) > 0) {
                print $fh "@{$stats->{sig_counts}[$file_index]{$sid}}  - $stats->{filenames}[$file_index]\n";
            }
        }
        print $fh "@{$stats->{sig_count_totals}{$sid}}  - totals\n";
        print $fh "$stats->{sig_text}{$sid}\n";
    }

    close $fh;
}

sub dump_static_threads {
    my ($stats) = @_;
    open my $fh, ">", "static-threads.out";

    my $static_threads = {};

    my $thread_sigs = $stats->{thread_sigs};
    foreach my $thread_sig (keys %{$thread_sigs}) {
        my $thread_info = $stats->{thread_uids}{$thread_sig};
        my $number_of_samples = $#{$stats->{file_dates}{$thread_info->{filename}}} + 1;
        my $is_static = 1;
        my $stack_hash = $thread_sigs->{$thread_sig}[0];
        # all samples have to exist and match first
        foreach my $index (1 .. $number_of_samples-1) {
            unless ($thread_sigs->{$thread_sig}[$index] && $stack_hash eq $thread_sigs->{$thread_sig}[$index]) {
                $is_static = 0;
                last;
            }
        }
        if ($is_static) {
            push @{$static_threads->{$stack_hash}}, {
                filename => $thread_info->{filename},
                id => $thread_info->{id}
            };
        }
    }

    print $fh "================= static threads ==================\n\n";

    foreach my $stack_hash (sort { $#{$static_threads->{$a}} <=> $#{$static_threads->{$b}} } keys %{$static_threads}) {
        my $stack_occurs = $static_threads->{$stack_hash};
        print $fh "=======================================\n\n";
        print $fh $stats->{sig_text}{$stack_hash};
        print $fh "\n\n";
        my $threads = scalar @{$stack_occurs};
        if ($threads > $MAX_STATIC_THREADS_LIST) {
            print $fh "Over $MAX_STATIC_THREADS_LIST occurrences of sig $stack_hash ($threads total).\n";
        } else {
            foreach my $occurrence (@{$stack_occurs}) {
                print $fh "file $occurrence->{filename}, thread id $occurrence->{id}, sig $stack_hash.\n";
            }
        }
        print $fh "\n\n";
    }

    close $fh;
}

sub dump_tree {
    my ($stats) = @_;
    open my $fh, ">", "stack-tree.out";
    _dump_tree ($fh, $stats->{stack_tree});
    close $fh;
}

sub _dump_tree {
    my ($fh, $tree) = @_;

    foreach my $call (sort { $tree->{$b}{count} <=> $tree->{$a}{count} } keys %{$tree}) {
        my $call_info = $tree->{$call};
        print $fh "\t" x $call_info->{level}, "$call_info->{count}: $call\n";
        _dump_tree ($fh, $call_info->{kids});
    }
}

sub ready_stats {
    my ($stats) = @_;
    my $dumps = $stats->{dump};
    # uggh, fill in sparse counts, then create sort key (highest, to lowest, each slice)
    foreach my $file_counts (@{$stats->{sig_counts}}) {
        foreach my $sid (keys %{$stats->{sig_text}}) {
            my $sig_counts = $file_counts->{$sid};
            foreach my $i (0 .. $dumps) {
                unless (exists $file_counts->{$sid}[$i]) { $file_counts->{$sid}[$i] = 0 }
                $stats->{sig_count_totals}{$sid}[$i] += ($sig_counts->[$i] ? $sig_counts->[$i] : 0);
            }
            $stats->{sig_sort_keys}{$sid} = join ('-', map { sprintf("%08d", $_) } @$sig_counts);
        }
    }
    # sort key for aggregates
    foreach my $sid (keys %{$stats->{sig_count_totals}}) {
        #$stats->{sig_sort_keys}{$sid} = join ('-', map { sprintf("%08d", $_) } @{$stats->{sig_count_totals}{$sid}});
        $stats->{sig_sort_keys}{$sid} = 
             sum (@{$stats->{sig_count_totals}{$sid}})
             *
             10 ** sum ( map { $_ > 0 } @{$stats->{sig_count_totals}{$sid}} )
    }
    # stack_tree
    my $stack_tree = {};
    $stats->{stack_tree} = $stack_tree;
    foreach my $sig (keys $stats->{sig_count_totals}) {
        my $level = 0;
        my $sig_count = sum (@{$stats->{sig_count_totals}{$sig}});
        my $text = $stats->{sig_text}{$sig};
        my $ref = $stack_tree;
        foreach my $line (reverse split (/[\r\n]+/, $text)) {
            $line =~ /^\S+\s+\S+\s+in\s+(.+)/;
            my $call = $1;
            if (exists $ref->{$call}) {
                $ref->{$call}{count} += $sig_count;
            } else {
                $ref->{$call} = { count => $sig_count, kids => {}, level => $level };
            }
            $ref = $ref->{$call}{kids};
            $level++;
        }
    }
}

sub do_file {
    my ($stats, $filename) = @_;
    push @{$stats->{filenames}}, $filename;
    my $fh;
    open ($fh, '<', $filename) || die "Can't open $filename.\n";
    $stats->{dump} = 0;
    my $current = { lines => [] };
    while (my $line = <$fh>) {
        $line =~ s/[\r\n]+//;
        if ($line =~ /^#\d/) {
            push @{$current->{lines}}, $line;
        } elsif ($line =~ /^Thread .*Thread (0x[^\s]+) /) {
            my $thread_id = $1;
            if (scalar (@{$current->{lines}})) {
                file_thread ($stats, $current);
            }
            $current = { tid => $thread_id, filename => $filename };
        } elsif ($line =~ /\d\d:\d\d:\d\d/) {
            # guess it's a time-date line?
            push @{$stats->{file_dates}{$filename}}, $line;
            if (scalar (@{$current->{lines}})) {
                $stats->{dump}++;
            }
        } else {
            print STDERR "What is this line: $line.\n";
        }    
    }
    close ($fh);
    file_thread ($stats, $current);
    return $stats;
}

sub file_thread {
    my ($stats, $thread) = @_;
    $thread->{text} = join ("\n", @{$thread->{lines}});
    my $sig_text = join ('', map { my $t = $_; $t =~ s/#\d+\s+\S+ in //; $t } @{$thread->{lines}});
    $thread->{sig} = md5_hex ($sig_text);
    # increment sig count for this dump
    ${$stats->{sig_counts}[$#{$stats->{filenames}}]{$thread->{sig}}}[$stats->{dump}]++;
    # increment sig count for this thread
    my $thread_uid = md5_hex ("$thread->{filename}}{$thread->{tid}}");
    $stats->{thread_uids}{$thread_uid} = { filename => $thread->{filename}, id => $thread->{tid} };
    push @{$stats->{thread_sigs}{$thread_uid}}, $thread->{sig};
    # add (or replace . . .)
    $stats->{sig_text}{$thread->{sig}} = $thread->{text};
}

