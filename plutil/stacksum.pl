#!/usr/bin/perl -w

$| = 1;

use strict;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $filename = 'pstack.log';

my $stats = do_file ($filename);

ready_stats ($stats);
dump_stats ($stats);

#print Dumper $stats;

sub dump_stats {
    my ($stats) = @_;
    foreach my $sid (sort { $stats->{sig_sort_keys}{$b} cmp $stats->{sig_sort_keys}{$a} } (keys %{$stats->{sig_sort_keys}})) {
        print "=========================================================\n";
        print "@{$stats->{sig_counts}{$sid}}\n";
        print "$stats->{sig_text}{$sid}";
    }
}

sub ready_stats {
    my ($stats) = @_;
    my $dumps = $stats->{dump};
    # uggh, fill in sparse counts, then create sort key (highest, to lowest, each slice)
    foreach my $sid (keys %{$stats->{sig_counts}}) {
        my $sig_counts = $stats->{sig_counts}{$sid};
        foreach my $i (0 .. $dumps) {
            unless (exists $sig_counts->[$i]) { $sig_counts->[$i] = 0 }
        }
        $stats->{sig_sort_keys}{$sid} = join ('-', map { sprintf("%06d", $_) } @$sig_counts);
    }
}

sub do_file {
    my ($filename) = @_;
    my $fh;
    open ($fh, '<', $filename) || die "Can't open $filename.\n";
    my $stats = { 
        dump => 0,
    };
    my $current = { lines => [] };
    while (my $line = <$fh>) {
        if ($line =~ /^#\d/) {
            push @{$current->{lines}}, $line;
        } elsif ($line =~ /^Thread .*Thread (0x[^\s]+) /) {
            my $thread_id = $1;
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
    $thread->{sig} = md5_hex ($thread->{text});
    # increment sig count for this dump
    ${$stats->{sig_counts}{$thread->{sig}}}[$stats->{dump}]++;
    # increment sig count for this thread
    ${$stats->{thread_sigs}{$thread->{tid}}}{$thread->{sig}}++;
    # add (or replace . . .)
    $stats->{sig_text}{$thread->{sig}} = $thread->{text};
}

