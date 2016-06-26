#!/usr/bin/perl -w

$| = 1;

use strict;
no warnings 'recursion';
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use List::Util qw(sum);
use FindBin;

my $MAX_STATIC_THREADS_LIST = 20;

my @filenames = @ARGV;

my $info_dir = "$FindBin::Bin/stack-class";

my $stats = { dump => 0, classes => read_stack_info_files ($info_dir) };
my $threads = { };

for my $filename (@filenames) {  do_file ($stats, $filename) }

ready_stats ($stats);

dump_stats ($stats);
dump_static_threads ($stats);
dump_tree ($stats);
dump_flame_info ($stats);

print STDERR Dumper $stats;


########### subs

# get classifier config(s)
sub read_stack_info_files {
    my ($info_dir) = @_;
    my $retval = { matchers => [] };
    my @info_files = <$info_dir/stack-class-*.config>;
    foreach my $filename (@info_files) {
        open my $fh, "<", $filename or die "Can't open $filename for read.\n";
        my $matcher = undef;
        while (my $line = <$fh>) {
            $line =~ s/[\s\r\n]*$//;
            # deal with blank lines
            if (length $line == 0) {
                # just nothing happening
                if    (! $matcher) { next }
                # something missing at end of def
                elsif (! ($matcher->{lines} && $matcher->{name} && $matcher->{tags})) {
                    print "Matcher missing name or tags or lines (discarded): ", Dumper ($matcher), "\n";
                    $matcher = undef;
                # a def, that is good
                } else {
                    push @{$retval->{matchers}}, $matcher;
                    $matcher = undef;
                }
            }
            # deal with thread lines
            elsif  ($line =~ /^#/) {
                if ($matcher) { push @{$matcher->{lines}}, $line; }
                else { print STDERR "Thread line |$line| with no tags/name in $filename.\n"; }
            }
            # deal with tag lines
            elsif ($line =~ /^=/) {
                unless ($matcher) { $matcher = { lines => [] } }; 
                my ($operator, $value) = ($line =~ /^=\s*([\S]+)\s+(.*)/);
                if ($operator eq 'NAME') { $matcher->{name} = $value; }
                elsif ($operator eq 'TAGS') { push @{$matcher->{tags}}, split ('\s*,\s*', $value) }
                else { print STDERR "Unknown operator $operator?\n"; }
            } else {
                print STDERR "What means: |$line| from file $filename?\n";
            }
        }
        close $fh;
        # flush last one
        if ($matcher) {
            if (! ($matcher->{lines} && $matcher->{name} && $matcher->{tags})) {
                print "Matcher missing name or tags or lines (discarded): ", Dumper ($matcher), "\n";
            } else {
                push @{$retval->{matchers}}, $matcher;
            }
        }
    }
    foreach my $matcher (@{$retval->{matchers}}) {
        $matcher->{sum_line} = sum_line (@{$matcher->{lines}});
    }
    return $retval;
}

# show aggregate stats
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
        print $fh join ("\n", @{$stats->{sig_lines}{$sid}}), "\n";
    }

    close $fh;
}

# show threads that don't change
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
        print $fh join ("\n", @{$stats->{sig_lines}{$stack_hash}}), "\n";
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

# dump out info to run and create flamegraph
sub dump_flame_info {
    my ($tree) = @_;
    open my $fh, ">", "flame-info.out";

    # stack_tree
    my $stack_tree = {};
    $stats->{stack_tree} = $stack_tree;

    foreach my $sig (keys $stats->{sig_count_totals}) {
        my $sig_count = sum (@{$stats->{sig_count_totals}{$sig}});
        print $fh "$stats->{sig_sums}{$sig} $sig_count\n";
    }

    close $fh;
}

# create lines summary for flamegraph output and matcher checking
sub sum_line {
    my (@lines) = @_;
    my @calls = ();
    foreach my $line (@lines) {
        $line =~ s/^\S+\s+\S+\s+in\s+//;
        $line =~ s/\s+from\s+.*//;
        $line =~ s/\(\)\s*$//;
        $line =~ s/ const$//;
        $line =~ s/\s//g;
        push @calls, $line;
    }
    return join (';', @calls);
}

sub dump_tree {
    my ($stats) = @_;
    open my $fh, ">", "stack-tree.out";
    _dump_tree ($fh, $stats->{stack_tree});
    close $fh;
}

# recursive tree printer
sub _dump_tree {
    my ($fh, $tree) = @_;

    foreach my $call (sort { $tree->{$b}{count} <=> $tree->{$a}{count} } keys %{$tree}) {
        my $call_info = $tree->{$call};
        print $fh "\t" x $call_info->{level}, "$call_info->{count}: $call\n";
        _dump_tree ($fh, $call_info->{kids});
    }
}

# compile from basic info
sub ready_stats {
    my ($stats) = @_;
    my $dumps = $stats->{dump};
    # uggh, fill in sparse counts, then create sort key (highest, to lowest, each slice)
    foreach my $file_counts (@{$stats->{sig_counts}}) {
        foreach my $sid (keys %{$stats->{sig_lines}}) {
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
    # sig_sums
    my $stack_tree = {};
    foreach my $sig (keys $stats->{sig_lines}) {
        $stats->{sig_sums}{$sig} = sum_line (@{$stats->{sig_lines}{$sig}});
    }
    # assign sig_classes/sig_matches
    foreach my $sig (keys $stats->{sig_sums}) {
        # check for matches
        foreach my $matcher (@{$stats->{classes}{matchers}}) {
            my $matcher_sum_line = $matcher->{sum_line};
            my $match = quotemeta ($matcher_sum_line);
            if ($stats->{sig_sums}{$sig} =~ m/$match/) {
                push @{$stats->{sig_matches}{$sig}}, $matcher;
            }
        }
        unless ($stats->{sig_matches}{$sig})  { next }
        # summary
        foreach my $match (@{$stats->{sig_matches}{$sig}}) {
            push @{$stats->{sig_classes}{$sig}{names}}, $match->{name};
            foreach my $tag (@{$match->{tags}}) {
                #push @{$stats->{sig_classes}{$sig}{tags}}, $tag;
                $stats->{sig_classes}{$sig}{tags}{$tag} = 1;
            }
        }
        # get back keys for unique list
        my @unique_tags = keys %{$stats->{sig_classes}{$sig}{tags}};
        $stats->{sig_classes}{$sig}{tags} = \@unique_tags;
    }
    # stack_tree
    $stats->{stack_tree} = $stack_tree;
    foreach my $sig (keys $stats->{sig_count_totals}) {
        my $level = 0;
        my $sig_count = sum (@{$stats->{sig_count_totals}{$sig}});
        my $ref = $stack_tree;
        foreach my $line (reverse @{$stats->{sig_lines}{$sig}}) {
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
    $stats->{sig_lines}{$thread->{sig}} = $thread->{lines};
}

