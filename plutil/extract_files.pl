#!/usr/bin/perl -w

use strict;
use Data::Dumper;

my @files = @ARGV;

my %map = ();

foreach my $filename (@files) {
    unless (-f $filename) {
        print "Skipping $filename, not regular file.\n";
        next;
    }
    my $base = $filename;
    $base =~ s/.*_from_(.+).zip/$1/;
    $map{$filename} = $base;
}

#die Dumper \%map;

foreach my $filename (keys %map) {
    my $base = $map{$filename};
    unless (-d $base) { mkdir $base }
    unless (-d $base) { die "Can't make $base." }
    chdir $base;
    system "unzip ../$filename";
    chdir "..";
}
