#!/usr/bin/perl -w
use strict;

use Getopt::Long;
use Data::Dumper;

# defaults.  23 is full dt with space and 3 digits right of .
my $options = { datecol => 1, timecol => 2, prefix => 23, regex => '', check => 0, debug => 0 };

# puts together datecol + ' ' + timecol and truncates to prefix chars, then bins/counts events

GetOptions (
    'datecol=n' => \$options->{datecol},
    'timecol=n' => \$options->{timecol},
    'prefix=n' => \$options->{prefix},
    'regex=s' => \$options->{regex},
    'check' => \$options->{check},
    'debug' => \$options->{debug},
);

# to zero-based index
$options->{datecol}--; $options->{timecol}--;

my $regex = $options->{regex};
my $debug = $options->{debug};

if ($options->{check}) { die Dumper $options }
if ($debug) { print Dumper $options; print "\n"; }

my %results = ();

if ($regex) {
    print "Matching lines with '$regex'.\n";
}

while (<>) {
    if ($regex) {
        my $matched = /$regex/;
        if ($debug) { print "matched = $matched:  ", $_; }
        unless ($matched) { next }
    }
    my @parts = split (/\s+/);
    my $dt = substr ($parts[$options->{datecol}] . ' ' . $parts[$options->{timecol}], 0, $options->{prefix});
    $results{$dt}++;
}

foreach my $dt (sort keys %results) {
    print $dt, " = ", $results{$dt}, "\n";
}

