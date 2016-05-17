#!/usr/bin/perl -w

$| = 1;

use strict;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use List::Util qw(sum);


my @filenames = @ARGV;

my $stats = { dump => 0 };

for my $filename (@filenames) {  do_file ($stats, $filename) }

ready_stats ($stats);
#print STDERR Dumper $stats;
dump_stats ($stats);



########### subs

sub dump_stats {
    my ($stats) = @_;
    foreach my $sid (sort { $stats->{sig_sort_keys}{$b} <=> $stats->{sig_sort_keys}{$a} } (keys %{$stats->{sig_sort_keys}})) {
        print "\n=========================================================\n";
        foreach my $file_index (0 .. $#{$stats->{filenames}}) {
            # avoid many rows of zeros
            if (sum (@{$stats->{sig_counts}[$file_index]{$sid}}) > 0) {
                print "@{$stats->{sig_counts}[$file_index]{$sid}}  - $stats->{filenames}[$file_index]\n";
            }
        }
        print "@{$stats->{sig_count_totals}{$sid}}  - totals\n";
        print "$stats->{sig_text}{$sid}";
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
    foreach my $sid (keys %{$stats->{sig_count_totals}}) {
        #$stats->{sig_sort_keys}{$sid} = join ('-', map { sprintf("%08d", $_) } @{$stats->{sig_count_totals}{$sid}});
        $stats->{sig_sort_keys}{$sid} = 
             sum (@{$stats->{sig_count_totals}{$sid}})
             *
             10 ** sum ( map { $_ > 0 } @{$stats->{sig_count_totals}{$sid}} )
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
        if ($line =~ /^#\d/) {
            push @{$current->{lines}}, $line;
        } elsif ($line =~ /^Thread .*Thread (0x[^\s]+) /) {
            my $thread_id = "$filename-$1";
            if (scalar (@{$current->{lines}})) {
                file_thread ($stats, $current);
            }
            $current = { tid => $thread_id };
        } else {
            if (scalar (@{$current->{lines}})) {
                $stats->{dump}++;
            }
        }    
    }
    close ($fh);
    file_thread ($stats, $current);
    return $stats;
}

sub file_thread {
    my ($stats, $thread) = @_;
    $thread->{text} = join ('', @{$thread->{lines}});
    my $sig_text = join ('', map { my $t = $_; $t =~ s/#\d+\s+\S+ in //; $t } @{$thread->{lines}});
    $thread->{sig} = md5_hex ($sig_text);
    # increment sig count for this dump
    ${$stats->{sig_counts}[$#{$stats->{filenames}}]{$thread->{sig}}}[$stats->{dump}]++;
    # increment sig count for this thread
    #${$stats->{thread_sigs}{$thread->{tid}}}{$thread->{sig}}++;
    # add (or replace . . .)
    $stats->{sig_text}{$thread->{sig}} = $thread->{text};
}

