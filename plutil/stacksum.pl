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

my $stats = { dump => 0, max_dump => 0, classes => read_stack_info_files ($info_dir) };
my $threads = { };

for my $filename (@filenames) {  do_file ($stats, $filename) }

ready_stats ($stats);

# print STDERR Dumper $stats;

dump_stats ($stats);
dump_sample_times ($stats);
dump_static_threads ($stats);
dump_busy_threads ($stats);
# junk
#dump_tree ($stats);
dump_flame_info ($stats);
dump_call_counts ($stats);
dump_call_stats ($stats);


# $sig = md5 of call stack
# $sid = md5 of node+sig  (thread uid)
# $tid = thread id in movie
# (may not be fully consistent throughout)

# $stats->{call_counts}{$call} = count
# $stats->{classes}{matchers} = [ list of matcher refs ]
# $stats->{dump} = counter for the sample you are reading.  zero based (so index)
# $stats->{file_dates}{$filename} = [ sample date lines ... ]
# $stats->{filenames} = [ list of filenames in order ]
# $stats->{max_dump} = max of $stats->{dump} across files/ndoes.
# $stats->{sig_classes}{$sig}{names} = [ names of matched matchers ]
# $stats->{sig_classes}{$sig}{tags}{$tag} = 1
# $stats->{sig_count_totals}{$sig} = [ list of counts for each sample across all nodes ]
# $stats->{sig_counts}[$file_index]{$sig}[$dump_index] = count.
# $stats->{sig_lines}{$sig} = [ text lines of sig, chomped ]
# $stats->{sig_matches}{$sig} = [ refs to matchers matched ]
# $stats->{sig_sort_keys}{$sig} = hokey sort for stats
# $stats->{sigs_idle}{$sig}++   flag of idle matches. used to find busy threads
# $stats->{sig_sums}{$sig} = summary line for flamegraph and matcher
# $stats->{static_thread_uids}{$sid} = 1
# $stats->{static_threads}{$sig} = [ { filename => x, id => y} ... ]
# $stats->{thread_sigs}{$sid} = $sig
# $stats->{thread_uids}{$sid} = { filename => $file, id => $tid }
# $stats->{call_stats}{$timestamp}{pstack_call}{$filename}{$call} += $count;
# $stats->{file_max_dump}[$file_dump_index] = max dump index for filename (0 based)






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
                elsif (! (scalar @{$matcher->{lines}} && $matcher->{name} && $matcher->{tags})) {
                    print STDERR "Matcher missing name or tags or lines (discarded): ", Dumper ($matcher), "\n";
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
            if (! (scalar @{$matcher->{lines}} && $matcher->{name} && $matcher->{tags}))  {
                print STDERR "Matcher missing name or tags or lines (discarded): ", Dumper ($matcher), "\n";
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

# show times of samples
sub dump_sample_times {
    my ($stats) = @_;
    open my $fh, ">", "stack-sample-times.out";

    print $fh "========================= sample date times ==========================\n";
    foreach my $file (sort keys %{$stats->{file_dates}}) {
        print $fh "\n\n", "$file:\n";
        foreach my $time (@{$stats->{file_dates}{$file}}) {
            print $fh "    $time\n";
        } 
    }

    close $fh;
}

# show aggregate stats
sub dump_stats {
    my ($stats) = @_;
    open my $fh, ">", "stack-stats.out";

    foreach my $sig (sort { $stats->{sig_sort_keys}{$b} <=> $stats->{sig_sort_keys}{$a} } (keys %{$stats->{sig_sort_keys}})) {
        print $fh "\n========================================================= $sig\n";
        foreach my $file_index (0 .. $#{$stats->{filenames}}) {
            # avoid many rows of zeros
            if (sum (@{$stats->{sig_counts}[$file_index]{$sig}}) > 0) {
                my $counts = join ('', (map { sprintf '%6s', $_ } @{$stats->{sig_counts}[$file_index]{$sig}}));
                #print $fh "@{$stats->{sig_counts}[$file_index]{$sig}}  - $stats->{filenames}[$file_index]\n";
                print $fh "$counts - $stats->{filenames}[$file_index]\n";
            }
        }
        my $totals = join ('', (map { sprintf '%6s', $_ } @{$stats->{sig_count_totals}{$sig}}));
        print $fh "$totals - totals\n\n";
        my $classes = $stats->{sig_classes}{$sig};
        if ($classes) {
            if ($classes->{names}) { print $fh join ("\n", map { "> " . $_ } @{$classes->{names}}), "\n"; }
            if ($classes->{tags}) { print $fh "tags: ", join (' ', @{$classes->{tags}}), "\n"; }
        }
        print $fh join ("\n", @{$stats->{sig_lines}{$sig}}), "\n";
    }

    close $fh;
}

sub dump_busy_threads {
    my ($stats) = @_;
    open my $fh, ">", "busy-threads.out";

    print $fh "================= ", scalar (keys %{$stats->{thread_sigs_busy}}), " busy non-static threads ==================\n\n";

    foreach my $thread_uid (keys %{$stats->{thread_sigs_busy}}) {
        print $fh "====================================== $thread_uid\n";
        my $thread_info = $stats->{thread_uids}{$thread_uid};
        print $fh "filename: $thread_info->{filename}.\n";
        print $fh "thread id: $thread_info->{id}.\n\n";
        foreach my $stack_sig (@{$stats->{thread_sigs}{$thread_uid}}) {
            foreach my $stack_line (@{$stats->{sig_lines}{$stack_sig}}) {
                print $fh "$stack_line\n";
            }
            print $fh "\n";
        }
    }

    close $fh;
}

# show threads that don't change
sub dump_static_threads {
    my ($stats) = @_;
    open my $fh, ">", "static-threads.out";

    my $static_threads = $stats->{static_threads};

    print $fh "================= static threads ==================\n\n";

    foreach my $stack_hash (sort { $#{$static_threads->{$a}} <=> $#{$static_threads->{$b}} } keys %{$static_threads}) {
        my $stack_occurrences = $static_threads->{$stack_hash};
        print $fh "=======================================\n\n";
        print $fh join ("\n", @{$stats->{sig_lines}{$stack_hash}}), "\n";
        print $fh "\n\n";
        my $threads = scalar @{$stack_occurrences};
        if ($threads > $MAX_STATIC_THREADS_LIST) {
            print $fh "Over $MAX_STATIC_THREADS_LIST occurrences of sig $stack_hash ($threads total).\n";
        } else {
            foreach my $occurrence (@{$stack_occurrences}) {
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

    # build info on ignored sigs
    my %ignored = ();
    foreach my $sig (keys %{$stats->{sig_count_totals}}) {
        my $noflame = grep { $_ eq 'noflame' } @{$stats->{sig_classes}{$sig}{tags}};
        if ($noflame)  { $ignored{$sig} = 1 }
        else           { $ignored{$sig} = 0 }
    }

    # overall flamegraphs
    open my $fh, ">", "flame-info.out";
    open my $reverse_fh, ">", "flame-reversed-info.out";
    foreach my $sig (sort keys %{$stats->{sig_count_totals}}) {
        if ($ignored{$sig}) { next }
        # sum
        my $sig_count = sum (@{$stats->{sig_count_totals}{$sig}});
        my $call_stack = sum_line (reverse @{$stats->{sig_lines}{$sig}});
        print $fh "$call_stack $sig_count\n";
        my $reverse_call_stack = $stats->{sig_sums}{$sig};
        print $reverse_fh "$reverse_call_stack $sig_count\n";
    }
    close $reverse_fh;
    close $fh;

    # per node
    for (my $index = 0; $index <= $#{$stats->{filenames}}; $index++) {
        my $filename = $stats->{filenames}[$index];
        open $fh, ">", "$filename-flame-info.out";
        open $reverse_fh, ">", "$filename-flame-reversed-info.out";
        foreach my $sig (keys %{$stats->{sig_count_totals}}) {
            if ($ignored{$sig}) { next }
            # sum
            my $sig_count = sum (@{$stats->{sig_counts}[$index]{$sig}}, 0);
            if ($sig_count == 0) { next }
            my $call_stack = sum_line (reverse @{$stats->{sig_lines}{$sig}});
            print $fh "$call_stack $sig_count\n";
            my $reverse_call_stack = $stats->{sig_sums}{$sig};
            print $reverse_fh "$reverse_call_stack $sig_count\n";
        }
        close $reverse_fh;
        close $fh;
    }

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

# dump call stats
sub dump_call_stats {
    my ($stats) = @_;
    open my $fh, ">", "stack-call-stats.tsv";
    print $fh "timestamp\treading\tresource\taction\tvalue\n";
    foreach my $timestamp (sort keys %{$stats->{call_stats}}) {
        foreach my $filename (keys %{$stats->{call_stats}{$timestamp}{pstack_call}}) {
            foreach my $call (keys %{$stats->{call_stats}{$timestamp}{pstack_call}{$filename}}) {
                my $count = $stats->{call_stats}{$timestamp}{pstack_call}{$filename}{$call};
                if ($count) {
                    # not each node may have it
                    print $fh "$timestamp\tpstack_call\t$filename\t$call\t$count\n";
                }
            }
        }
    }
    close $fh;
}


# dump call counts
sub dump_call_counts {
    my ($stats) = @_;
    my $call_counts = $stats->{call_counts};
    open my $fh, ">", "stack-call-counts.out";
    foreach my $call (sort { $call_counts->{$b} <=> $call_counts->{$a} } keys %{$call_counts}) {
        print $fh "$call: $call_counts->{$call}.\n";
    }
    close $fh;
}

# tree printer
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
    my $dumps = $stats->{max_dump};


    # sig_counts: array of hashes for each node/file.  each hash as sigs -> array of counts for each sample for the node/file.

    # uggh, fill in sparse counts, then create sort key (highest, to lowest, each slice)
    foreach my $file_counts (@{$stats->{sig_counts}}) {
        foreach my $sig (keys %{$stats->{sig_lines}}) {
            my $sig_counts = $file_counts->{$sig};
            foreach my $i (0 .. $dumps) {
                unless (exists $file_counts->{$sig}[$i]) { $file_counts->{$sig}[$i] = 0 }
                $stats->{sig_count_totals}{$sig}[$i] += ($sig_counts->[$i] ? $sig_counts->[$i] : 0);
            }
            $stats->{sig_sort_keys}{$sig} = join ('-', map { sprintf("%08d", ($_ ? $_ : 0)) } @$sig_counts);
        }
    }

    # sort key for aggregates
    foreach my $sig (keys %{$stats->{sig_count_totals}}) {
        #$stats->{sig_sort_keys}{$sig} = join ('-', map { sprintf("%08d", $_) } @{$stats->{sig_count_totals}{$sig}});
        $stats->{sig_sort_keys}{$sig} = 
             sum (@{$stats->{sig_count_totals}{$sig}})
             *
             10 ** sum ( map { $_ > 0 } @{$stats->{sig_count_totals}{$sig}} )
    }

    # sig_sums
    foreach my $sig (keys %{$stats->{sig_lines}}) {
        $stats->{sig_sums}{$sig} = sum_line (@{$stats->{sig_lines}{$sig}});
    }

    # assign sig_classes/sig_matches
    foreach my $sig (keys %{$stats->{sig_sums}}) {
        # check for matches
        foreach my $matcher (@{$stats->{classes}{matchers}}) {
            my $matcher_sum_line = $matcher->{sum_line};
            my $match = quotemeta ($matcher_sum_line);
            if ($stats->{sig_sums}{$sig} =~ m/$match/) {
                push @{$stats->{sig_matches}{$sig}}, $matcher;
            }
        }
        # get out if no match
        unless ($stats->{sig_matches}{$sig})  { next }
        # summary
        foreach my $match (@{$stats->{sig_matches}{$sig}}) {
            push @{$stats->{sig_classes}{$sig}{names}}, $match->{name};
            foreach my $tag (@{$match->{tags}}) {
                #push @{$stats->{sig_classes}{$sig}{tags}}, $tag;
                $stats->{sig_classes}{$sig}{tags}{$tag} = 1;
            }
        }
        # save idle sigs for busy report
        if ($stats->{sig_classes}{$sig}{tags}{idle}) {
            $stats->{sigs_idle}{$sig}++
        }
        # get back keys for unique list
        my @unique_tags = keys %{$stats->{sig_classes}{$sig}{tags}};
        $stats->{sig_classes}{$sig}{tags} = \@unique_tags;
    }

    # create call counts
    while (my ($sig, $sig_sum) = each %{$stats->{sig_sums}}) {
        my $call_count = 0;
        foreach my $count (@{$stats->{sig_count_totals}{$sig}}) { $call_count += $count }
        foreach my $call (split /;/, $sig_sum) { $stats->{call_counts}{$call} += $call_count }
    }

    # create call stats, maybe plot-able
    for (my $file_index = 0; $file_index <= $#{$stats->{filenames}}; $file_index++) {
        my $filename = $stats->{filenames}[$file_index];
        foreach my $sig (keys %{$stats->{sig_counts}[$file_index]}) {
            for (my $dump_index = 0; $dump_index <= $stats->{file_max_dump}[$file_index]; $dump_index++) {
                my $dateline = $stats->{file_dates}{$filename}[$dump_index];
#print STDERR "$filename, $sig, $dump_index @ $dateline.\n";
                my $timestamp = iso_from_pstack ($dateline);
                my $count = $stats->{sig_counts}[$file_index]{$sig}[$dump_index];
#print STDERR "$file_index/$filename, $sig, $dump_index, $count.\n";
                unless ($count)  { next }
                foreach my $call (split /;/, $stats->{sig_sums}{$sig}) { 
                    $call =~ s/[\(<].*//;
                    $stats->{call_stats}{$timestamp}{pstack_call}{$filename}{$call} += $count;
                }
            }
        }
    }

    # static threads
    my $thread_sigs = $stats->{thread_sigs};
    foreach my $thread_sid (keys %{$thread_sigs}) {
        my $thread_info = $stats->{thread_uids}{$thread_sid};
        my $number_of_samples = $#{$stats->{file_dates}{$thread_info->{filename}}} + 1;
        my $is_static = 1;
        my $stack_hash = $thread_sigs->{$thread_sid}[0];
        # all samples have to exist and match first
        foreach my $index (1 .. $number_of_samples-1) {
            unless ($thread_sigs->{$thread_sid}[$index] && $stack_hash eq $thread_sigs->{$thread_sid}[$index]) {
                $is_static = 0;
                last;
            }
        }
        if ($is_static) {
            push @{$stats->{static_threads}{$stack_hash}}, $thread_info;
            $stats->{static_thread_uids}{$thread_sid} = 1;
        }
    }

    # threads always busy (not idle)
    foreach my $thread_uid (keys %{$stats->{thread_sigs}}) {
        my $thread_info = $stats->{thread_uids}{$thread_uid};
        my $thread_samples = scalar @{$stats->{thread_sigs}{$thread_uid}};
        my $file_samples = scalar @{$stats->{file_dates}{$thread_info->{filename}}};
        # can't be busy always if it doesn't exist always
        if ($thread_samples < $file_samples) {  next }
        if ($stats->{static_thread_uids}{$thread_uid}) { next }
        $stats->{thread_sigs_busy}{$thread_uid} = 1;
        foreach my $thread_sig (@{$stats->{thread_sigs}{$thread_uid}}) {
            if ($stats->{sigs_idle}{$thread_sig}) { delete $stats->{thread_sigs_busy}{$thread_uid}; last }
        }
    }

    # stack_tree
    #my $stack_tree = {};
    #$stats->{stack_tree} = $stack_tree;
    #foreach my $sig (keys %{$stats->{sig_count_totals}}) {
        #my $level = 0;
        ##my $sig_count = sum (@{$stats->{sig_count_totals}{$sig}});
        #my $ref = $stack_tree;
        #foreach my $line (reverse @{$stats->{sig_lines}{$sig}}) {
            #$line =~ /^\S+\s+\S+\s+in\s+(.+)/;
            #my $call = $1;
            #if (exists $ref->{$call}) {
                #$ref->{$call}{count} += $sig_count;
            #} else {
                #$ref->{$call} = { count => $sig_count, kids => {}, level => $level };
            #}
            #$ref = $ref->{$call}{kids};
            #$level++;
        #}
    #}
}

# input file
sub do_file {
    my ($stats, $filename) = @_;
    push @{$stats->{filenames}}, $filename;
    my $fh;
    open ($fh, '<', $filename) || die "Can't open $filename.\n";
    $stats->{dump} = 0;
    my $current = { lines => [] };
    my $line_number = 0;
    while (my $line = <$fh>) {
        $line_number++;
        $line =~ s/[\r\n]+//;
        if (length ($line) == 0) { next }
        if ($line =~ /^#\d/) {
            push @{$current->{lines}}, $line;
        } elsif ($line =~ /^Thread .*Thread (0x[^\s]+) / || $line =~ /^Thread \d+ \(LWP (\d+)\):/) {
            my $thread_id = $1;
            if (scalar (@{$current->{lines}})) {
                file_thread ($stats, $current);
            }
            $current = { tid => $thread_id, filename => $filename, dump => $stats->{dump} };
        } elsif ($line =~ /\d\d:\d\d:\d\d/) {
            # guess it's a time-date line?
            push @{$stats->{file_dates}{$filename}}, $line;
            if (scalar (@{$current->{lines}})) {
                $stats->{dump}++;
            }
        } else {
            print STDERR "What is this line (file $filename; line $line_number): $line.\n";
        }    
    }
    close ($fh);
    # max for this file(index)
    $stats->{file_max_dump}[$#{$stats->{filenames}}] = $stats->{dump}; 
    # max across files/nodes
    if ($stats->{dump} > $stats->{max_dump})  { $stats->{max_dump} = $stats->{dump} }
    file_thread ($stats, $current);
    return $stats;
}

sub iso_from_pstack {
    my ($s) = @_;
    my ($day, $mo, $date, $time, $offset, $year) = split (/\s+/, $s);
    my %mos = (
        Jan => 1, Feb => 2, Mar => 3, Apr => 4, May => 5, Jun => 6, Jul => 7, Aug => 8, Sep => 9, Oct => 10, Nov => 11, Dec => 12
    );
    my $iso = sprintf ('%04d-%02d-%02d', $year, $mos{$mo}, $date, ) . ' ' . $time;
    unless ($iso =~ /2\d\d\d-\d[1-9]-\d\d \d\d:\d\d:\d\d/) {
        print STDERR "Can't make timestamp from $s.\n";
        return "1970-01-01 00:00:00";
    }
    return $iso;
}

# add a thread dump to the stats
sub file_thread {
    my ($stats, $thread) = @_;
    $thread->{text} = join ("\n", @{$thread->{lines}});
    my $sig_text = join ('', map { my $t = $_; $t =~ s/#\d+\s+\S+ in //; $t } @{$thread->{lines}});
    $thread->{sig} = md5_hex ($sig_text);
    # increment sig count for this dump.  sig_counts index matches filenames index.
    # $stats->{sig_counts}[$file_index]{$sig}[$dump]     (dump is the sample in the file).
    ${$stats->{sig_counts}[$#{$stats->{filenames}}]{$thread->{sig}}}[$thread->{dump}]++;
    # increment sig count for this thread
    my $thread_uid = md5_hex ("$thread->{filename}}{$thread->{tid}}");
    $stats->{thread_uids}{$thread_uid} = { filename => $thread->{filename}, id => $thread->{tid} };
    push @{$stats->{thread_sigs}{$thread_uid}}, $thread->{sig};
    # add (or replace . . .)
    $stats->{sig_lines}{$thread->{sig}} = $thread->{lines};
}

