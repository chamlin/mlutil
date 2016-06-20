#!/usr/bin/perl -w
use strict;

use Data::Dumper;

my $sep = "   ";

my %findings = ();
my @lines = ();
foreach my $line (<>) {
    chomp $line;
    my @parts = split (/\s+/, $line);
    push @lines, \@parts;
    my $max_columns =  $findings{cols};
    my $current =  scalar @parts;
    if ($max_columns) {
        if ($current > $max_columns)  { $findings{cols} = $current; }
    } else {
        $findings{cols} = $current;
    }
    my $i = 0;
    foreach my $part (@parts) {
        my $max =  $findings{lengths}[$i];
        my $current =  length ($part);
        if ($max) {
            if ($current > $max)  { $findings{lengths}[$i] = $current; }
        } else {
            $findings{lengths}[$i] = $current;
        }
        $i++;
    }
}

my $cols = $findings{cols};
foreach my $line (@lines) {
    #print join ('|', @{$line}), "\n";
    my @cells = ();
    for (my $i = 0; $i < $cols; $i++) {
        my $width = $findings{lengths}[$i];
        push @cells, sprintf ("%${width}s", $line->[$i]);
    }
    print join ($sep, @cells), "\n";
}

