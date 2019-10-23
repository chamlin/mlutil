#!/usr/bin/perl -w
use strict;

use Data::Dumper;

my %stats = ();
my $total = 0;

while (<>) {
    if (m!^(.*)\.\d\d\d Debug: (~?)OnDiskStand.*Forests/([^/]+)/!) {
        my $delta = ($2 eq '~' ? -1 : 1);
        my ($dt, $forest) = ($1, $3);
        unless ($forest =~ /TRUSTED/) { next }
        $stats{forests}{$forest} += $delta;
        $stats{total} += $delta;
        $stats{rows}{$dt}{forests}{$forest} = $stats{forests}{$forest};
        $stats{rows}{$dt}{total} = $stats{total};
        #print "$dt:  total = $stats{rows}{$dt}{total};  $forest = $stats{rows}{$dt}{forests}{$forest}.\n";
    }
}

my @forests = sort keys %{$stats{forests}};

# print header
print "timestamp\tstat\tvalue\n";

foreach my $dt (sort keys %{$stats{rows}}) {
    foreach my $forest (keys %{$stats{rows}{$dt}{forests}}) {
        my $value = $stats{rows}{$dt}{forests}{$forest};
        print "$dt\t$forest\t$value\n"
    }
    my $total = $stats{rows}{$dt}{total};
    print "$dt\ttotal\t$total\n";
}

#print Dumper \%stats;
