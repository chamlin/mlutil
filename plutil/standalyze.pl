#!/usr/bin/perl -w
use strict;

$| = 1;

use Data::Dumper;

#
#
my %data = ();

while (<>) {
    chomp;
    my ($time, $level, $first_word, $text) = /(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d.\d\d\d) (\S+): (\S+) (.*)/;
    if ($first_word eq 'Saved') {
        my ($mb, $s, $mb_s, $stand) = ($text =~ /(\d+) MB in (\d+) sec at (\d+) MB.*Forests\/(.*)/);
        unless ($stand) {
            ($mb, $mb_s, $stand) = ($text =~ /(\d+) MB at (\d+) MB.*Forests\/(.*)/);
        }
        unless ($stand) { print "*** Bad line (no Saved stand): $text.\n"; next; }
        push @{$data{stands}{$stand}}, { time => $time, op => $first_word };
    } elsif ($first_word eq 'Saving') {
        my ($stand) = ($text =~ /Forests\/(.*)/);
        push @{$data{stands}{$stand}}, { time => $time, op => $first_word };
    } elsif ($first_word eq 'Merged' || $first_word eq 'Deleted') {
        my ($mb, $mb_s, $stand) = ($text =~ /(\d+) MB at (\d+) MB.*Forests\/(.*)/);
        my $s;
        unless ($stand) {
            ($mb, $s, $mb_s, $stand) = ($text =~ /(\d+) MB in (\d+) sec at (\d+) MB.*Forests\/(.*)/);
        }
        if ($first_word eq 'Deleted') {
            push @{$data{stands}{$stand}}, { time => $time, op => 'Deleted' };
        } else {
            push @{$data{stands}{$stand}}, { time => $time, op => 'MergedTo' };
        }
    } elsif ($first_word eq 'OnDiskStand') {
        my ($stand) = ($text =~ /Forests\/(.*), disk/);
        push @{$data{stands}{$stand}}, { time => $time, op => $first_word };
    } elsif ($first_word eq '~OnDiskStand') {
        my ($stand) = ($text =~ /Forests\/(.*)/);
        push @{$data{stands}{$stand}}, { time => $time, op => $first_word };
    } elsif ($first_word eq 'InMemoryStand' || $first_word eq '~InMemoryStand') {
        my ($stand) = ($text =~ /Forests\/(.*)/);
        $stand =~ s/,.*$//;
        push @{$data{stands}{$stand}}, { time => $time, op => $first_word };
    } elsif ($first_word eq 'Merging') {
        my ($from, $to) = ($text =~ /from (.*) to .*\/Forests\/(.*)timestamp/);
        $to =~ s/[ ,]+$//;
       push @{$data{stands}{$to}}, { time => $time, op => 'MergingTo' };
#/Users/chamlin/Library/Application Support/MarkLogic/Data/Forests/Documents/00000008.
#/Users/chamlin/Library/Application Support/MarkLogic/Data/Forests/Documents/00000007 and /Users/chamlin/Library/Application Support/MarkLogic/Data/Forests/Documents/00000006.
       foreach my $from (get_stands ($from)) { push @{$data{stands}{$from}}, { time => $time, op => 'MergingFrom' }; }
    } elsif ($text =~ /Forests/) { 
    } 
}

my %creations = ();
foreach my $stand (sort keys %{$data{stands}}) {
    unless ($stand =~ /^Documents/) { next }
    print "$stand:\n";
    my $creation = get_creation_event ($data{stands}{$stand});
    $creations{$creation}++;
    print "    created by: $creation\n";
    print "\n\n";
}

print Dumper \%creations;

sub get_creation_event {
    my ($events) = @_;
    my $creation_event = 'unknown';
    foreach my $event (@$events) {
        my ($op, $time) = ($event->{op}, $event->{time});
        if ($op eq 'MergedTo' || $op eq 'InMemoryStand') { $creation_event = $op }
        print "    $time:  $op\n";
    }
    return $creation_event;
}

sub get_stands {
    my ($text) = @_;
    my @paths = split (/( and |, )/, $text);
    my @stands;
    foreach my $path (@paths) { my ($stand) = ($path =~ /Forests\/(.*)/); unless ($stand) { next }; $stand =~ s/[ ,]+$//; push @stands, $stand; }
    return @stands;
}
