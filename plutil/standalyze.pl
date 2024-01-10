#!/usr/bin/perl
use strict;
use Data::Dumper;

my @ok_flows = (
    'Saving->Saved->MergingFrom->Deleted',
    'MergingTo->MergedTo->MergingFrom->Deleted',
);

#
#
my %data = ();

while (<>) {
    s/[\r\n]*$//;   
    my ($time, $level, $first_word, $text) = /(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d.\d\d\d) (\S+): (\S+) (.*)/;
    if ($first_word eq 'Saved') {
        my ($mb, $s, $mb_s, $stand) = ($text =~ /(\d+) MB in (\d+) sec at (\d+) MB.*Forests[\/\\](.*)/);
        unless ($stand) {
            ($mb, $mb_s, $stand) = ($text =~ /(\d+) MB at (\d+) MB.*Forests[\/\\](.*)/);
        }
        unless ($stand) { print "*** Bad line (no Saved stand): $text.\n"; next; }
        push @{$data{stands}{$stand}}, { time => $time, text => $_, op => $first_word };
    } elsif ($first_word eq 'Saving') {
        my ($stand) = ($text =~ /Forests[\/\\](.*)/);
        push @{$data{stands}{$stand}}, { time => $time, text => $_, op => $first_word };
    } elsif ($first_word eq 'Merged' || $first_word eq 'Deleted') {
        my ($mb, $mb_s, $stand) = ($text =~ /(\d+) MB at (\d+) MB.*Forests[\/\\](.*)/);
        my $s;
        unless ($stand) {
            ($mb, $s, $mb_s, $stand) = ($text =~ /(\d+) MB in (\d+) sec at (\d+) MB.*Forests[\/\\](.*)/);
        }
        if ($first_word eq 'Deleted') {
            push @{$data{stands}{$stand}}, { time => $time, text => $_, op => 'Deleted' };
        } else {
            push @{$data{stands}{$stand}}, { time => $time, text => $_, op => 'MergedTo' };
        }
    } elsif ($first_word eq 'OnDiskStand') {
        my ($stand) = ($text =~ /Forests[\/\\](.*), disk/);
        push @{$data{stands}{$stand}}, { time => $time, text => $_, op => $first_word };
    } elsif ($first_word eq '~OnDiskStand') {
        my ($stand) = ($text =~ /Forests[\/\\](.*)/);
        push @{$data{stands}{$stand}}, { time => $time, text => $_, op => $first_word };
    } elsif ($first_word eq 'InMemoryStand' || $first_word eq '~InMemoryStand') {
        my ($stand) = ($text =~ /Forests[\/\\](.*)/);
        $stand =~ s/,.*$//;
        push @{$data{stands}{$stand}}, { time => $time, text => $_, op => $first_word };
    } elsif ($first_word eq 'Merging') {
        my ($from, $to) = ($text =~ /from (.*) to .*[\/\\]Forests[\/\\](.*)timestamp/);
        $to =~ s/[ ,]+$//;
       push @{$data{stands}{$to}}, { time => $time, text => $_, op => 'MergingTo' };
#/Users/chamlin/Library/Application Support/MarkLogic/Data/Forests/Documents/00000008.
#/Users/chamlin/Library/Application Support/MarkLogic/Data/Forests/Documents/00000007 and /Users/chamlin/Library/Application Support/MarkLogic/Data/Forests/Documents/00000006.
       foreach my $from (get_stands ($from)) { push @{$data{stands}{$from}}, { time => $time, text => $_, op => 'MergingFrom' }; }
    } elsif ($text =~ /Forests/) { 
    } 
}

print Dumper \%data;

#my %creations = ();
#foreach my $stand (sort keys %{$data{stands}}) {
#    unless ($stand =~ /^Documents/) { next }
#    print "$stand:\n";
#    my $creation = get_creation_event ($data{stands}{$stand});
#    $creations{$creation}++;
#    print "    created by: $creation\n";
#    print "\n\n";
#}

my $actions = get_stand_action_strings ($data{stands});

while (my ($stand, $action_string) = each %$actions) {
    #print "$stand -> $action_string:", check_action_string_vs_flows($action_string), "\n";
    my $is_ok = check_action_string_vs_flows($action_string);
    unless ($is_ok) {
        print STDERR "check $stand.\n";
        print STDERR "    $action_string.\n";
        foreach my $action (@{$data{stands}{$stand}}) {
            print STDERR "    $action->{text}\n";
        }
    }
}

#print Dumper $actions;

sub check_action_string_vs_flows {
    my ($action_string) = @_;
    foreach my $flow (@ok_flows) {
        if ($action_string eq substr($flow, -length ($action_string))) {
            #print "$action_string <= $flow.\n";
            return 1;
        } elsif ($flow =~ /^$action_string/) {
            #print "$action_string >= $flow.\n";
            return 1;
        }
    }
    return 0;
}

sub get_stand_action_strings {
    my ($stand_actions) = @_;
    my $ret_val = {};
    while (my ($stand, $events) = each %$stand_actions) {
        #print "get_action: $stand.\n";
        my @sorted_events = map { $_->{op} } sort { $a->{time} cmp $b->{time} } @$events;
        $ret_val->{$stand} = join ('->', @sorted_events);
    }
    return $ret_val;
}


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
    my @paths = split (/(?: and |, )/, $text);
    my @stands;
    foreach my $path (@paths) {
        #print STDERR "path: $path.\n";
        my ($stand) = ($path =~ /Forests[\/\\](.*)/);
        #print STDERR "path-stand: $stand.\n";
        unless ($stand) { next };
        $stand =~ s/[ ,]+$//;
        push @stands, $stand;
    }
    return @stands;
}
