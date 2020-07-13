#!/usr/bin/perl -w
use strict;
use File::Find;
use Data::Dumper;

my @directories = @ARGV;

# this holds some global type stuff too
my $options = {
    wanted => \&process,
    filename_match => 'dv.*gov-ErrorLog.*',
    found => {},
    outdir => 'combined-logs',
};

find ($options, @directories);

print "\n\n\n";

unless (-d $options->{outdir}) { mkdir $options->{outdir} }

# print Dumper $options->{found};

for my $node (keys %{$options->{found}}) {
    print "\n# node: $node\n\n";
    my @node_paths = sort {
         $options->{found}{$node}{$a}{start} cmp $options->{found}{$node}{$b}{start}
    } keys %{$options->{found}{$node}};

    my ($f1, $f2) = (shift @node_paths, shift @node_paths);
    while ($f2) {
        my ($s1, $e1) = @{$options->{found}{$node}{$f1}}{'start','end'};
        my ($s2, $e2) = @{$options->{found}{$node}{$f2}}{'start','end'};
        if ($s1 eq $s2) {
            if ($e1 ge $e2) {
                print "## file: $f2\n";
                print "### $s2 -> $e2\n";
                print "#### subset, ignoring\n\n";
                $f2 = shift @node_paths;
            } else {
                print "## file: $f1\n";
                print "### $s1 -> $e1\n";
                print "#### subset, ignoring\n\n";
                $f1 = $f2;
                $f2 = shift @node_paths;
            }
        } else {
            # sorted, so s2 > s1
            if ($s2 gt $e1) {
                # first is good, second doesn't overlap, but need to check against later files too
                print "## file: $f1\n";
                print "### $s1 -> $e1\n";
                $f1 =~ s/ /\\ /g;
                print "cat $f1 >> $options->{outdir}/$node\n\n";
                $f1 = $f2;
                $f2 = shift @node_paths;
            } elsif ($e1 ge $e2) {
                print "## file: $f2\n";
                print "### $s2 -> $e2\n";
                print "#### subset, ignoring\n\n";
                $f2 = shift @node_paths;
            } else {
                # overlap
                print "## file: $f1\n";
                print "### $s1 -> $e1\n";
                print "#### overlap, ignoring\n\n";
                print "## file: $f2\n";
                print "### $s2 -> $e2\n";
                print "#### overlap, ignoring\n\n";
                $f1 = shift @node_paths;
                $f2 = shift @node_paths;
            }
        }
    }

    # flush the remaining.  was only one, or better than the other(s)
    my ($s1, $e1) = @{$options->{found}{$node}{$f1}}{'start','end'};
    print "## file: $f1\n";
    print "### $s1 -> $e1\n";
    print "cat $f1 >> $options->{outdir}/$node\n\n";

    #    print "## file: $file\n";
    #    print "### $start -> $end\n";
    #}
}

sub get_node_name {
    my ($filename) = @_;
    substr ($filename, 0, 6);
};

sub process {
    my ($dir, $file, $path) = ($File::Find::dir, $_, $File::Find::name);
    if ( !$options->{filename_match} || $file =~ $options->{filename_match}) {
        unless (-s $file) { print "# ! $path is empty.\n"; return; }
        open (FH, '<', $file) or die $!;
        my ($start, $end) = ();
        while (<FH>) {
            my ($dt) = /^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d\.\d\d\d) (Finest|Finer|Fine|Debug|Config|Info|Notice|Warning|Error|Critical|Alert|Emergency)/;
            if ($dt) {
                if ($start) { $end = $dt } else { $start = $dt }
            }
        }
        close (FH);
        if ($start && $end) {
            my $node = get_node_name ($file);
            $options->{found}{$node}{$path} = { start => $start, end => $end }
        }
        else { print "# ! $path doesn't have start/end log lines found.\n"; }
    }
};
