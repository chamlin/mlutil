#!/usr/bin/perl -w
use strict;

my $context_lines = 15;

my $current_file = '';

my @lines = ();

my $state = 'scan';

while (my $line = <>) {
    chomp $line;
    push @lines, $line;
    # reinit for new file
    if ($current_file ne $ARGV) {
        $current_file = $ARGV;
        $state = 'scan';
        print "$current_file\n===========\n\n";
    }

    # check if state is changing.
    if ($line =~ /Segmentation fault in thread/) {
        foreach my $context_line (@lines[-$context_lines .. -1]) {
            print $context_line, "\n"
        }
        $state = 'fault';
        print "$line\n";
    } elsif ($line =~ /Critical:+/ && $state eq 'fault') {
        print "$line\n";
    } elsif ($line !~ /Critical:+/ && $state eq 'fault') {
        $state = 'scan';
        print "\n\n";
    } elsif ($state eq 'scan') {
        ;
    } else {
        die "whah?\n";
    }

    # output if printing.
    
}

