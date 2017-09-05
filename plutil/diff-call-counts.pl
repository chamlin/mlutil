#!/usr/bin/perl -w
use strict;
use Data::Dumper;

# diff the call count files from two stacksum runs.
# shows largest count diffs and unique calls

my $files = {};
my $diffs = {};
my $unique = {};
my $calls = {};

my @files = @ARGV;

foreach my $file (@files) {
    open my $fh, '<', $file;
    while (<$fh>) {
        chomp;
        my ($call, $count) = /^(.*): (\d+)\.$/;
        $files->{$file}{$call} = $count;
        $calls->{all}{$call} = 1;
    }
    close $fh;
}

my ($file1, $file2) = @files;

foreach my $call (keys %{$calls->{all}}) {
    my ($file1_count, $file2_count) = values_for_files ($file1, $file2, $call, $files);
    $diffs->{$call} = $file2_count - $file1_count;
    if ($file1_count == 0) {
        $unique->{$file2}{$call} = $file2_count;
    } elsif ($file2_count == 0) {
        $unique->{$file1}{$call} = $file1_count;
    }
}

print "\n\n---- diffs ($file1 -> $file2) \n\n\n";

foreach my $call (sort { abs ($diffs->{$b}) <=> abs ($diffs->{$a}) } keys %$diffs) {
    my ($file1_count, $file2_count) = values_for_files ($file1, $file2, $call, $files);
    print "$call: $file1_count -> $file2_count => $diffs->{$call}.\n";
}


print "\n\n---- unique \n\n\n";


foreach my $file ($file1, $file2) {

    print "\n\n$file\n\n\n";

    foreach my $call (sort { $unique->{$file}{$b} <=> $unique->{$file}{$a} } keys %{$unique->{$file}}) {
        print "$call = $unique->{$file}{$call} calls.\n";
    }
}

sub values_for_files {
    my ($file1, $file2, $call, $files) = @_;
    my ($file1_count, $file2_count) = (0, 0);
    if (exists $files->{$file1}{$call})  { $file1_count = $files->{$file1}{$call} }
    if (exists $files->{$file2}{$call})  { $file2_count = $files->{$file2}{$call} }
    return ($file1_count, $file2_count);
}
