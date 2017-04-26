#!/usr/bin/perl -w

use strict;

# hack as needed

my @zips = @ARGV;

unless (-d 'combi')  { system "mkdir combi" }

foreach my $zip (@zips) {
    my $fullname = $zip;
    my $basename = $fullname;  $basename =~ s/.*_from_(.+)\.zip/$1/;
    system "unzip $zip\n";
    system "mv tmp/*/pstack.log combi/$basename";
    system "rm -rf ./tmp\n";
}

