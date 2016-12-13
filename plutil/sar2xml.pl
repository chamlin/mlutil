#!/usr/bin/perl -w
use strict;

$| = 1;

# TODO  -  quote separator character
# TODO  -  grab date from top header, add to time.

use Getopt::Std;
use Data::Dumper;

$| = 1;

# for debug
my $BLOCK_LINE_MAX = 9999999;

my $opts = {};


getopts ('0d:f:u', $opts);

# leftovers
my @filenames = @ARGV;

if ($opts->{u} or scalar @filenames == 0) {
    print "    -d    debug output---comma/semi separated\n";
    print "    -f    file---comma/semicolon separated\n";
    print "    -u    use (this) \n";
    print "    -0    no output (except debug)\n";
    print "\n";
    print "options parsed: ", Dumper ($opts), "\n";
    exit;
}

# split.  to check for 'merge' flag, as:  $opts->{debug}{merge}
if (exists $opts->{d}) {
    my @flags = split /[,;]/, $opts->{d};
    foreach my $flag (@flags) { $opts->{debug}{$flag} = 1 }
}

if ($opts->{debug}{config}) { print STDERR Dumper \$opts }

print "<events xmlns='http://esereno.com/logging/event'>\n";

# do each file (hmm, maybe only one at a time, or overwrites)
foreach my $filename (@filenames) {
    if (-f $filename) {
        if ($opts->{debug}{io}) {
            print_message ("< $filename\n")
        }
    } else {
        print_message ("ERROR: no file $filename\n");
        next;
    }

    open(my $fh, "<", $filename);

    # get the blocks
    my $blocks = read_blocks ($filename, $fh);
    close ($fh);

    prep_blocks ($opts, $blocks);

    unless ($opts->{'0'}) { dump_blocks ($opts, $blocks) }

    if ($opts->{debug}{blocks}) { print_message ('blocks: ', Dumper $blocks) }
}

print "</events>\n";

####### subs

sub dump_blocks {
    my ($opts, $blocks) = @_;
    foreach my $block (@$blocks) {
        foreach my $event (@{$block->{events}}) {
            print $event, "\n";
        }
    }
}

sub prep_blocks {
    my ($opts, $blocks) = @_;
    my ($date, $node) = ();
    foreach my $block (@$blocks) {
        my $col1 = $block->{columns}[0];
        # get date
        if ($col1 eq 'Linux') { 

#print STDERR 'date: ', Dumper ($block), "\n";
            # set date
            foreach my $col (@{$block->{columns}}) {
#print STDERR 'col: ', $col, "\n";
                # date
                if      ($col =~ /\d\d\d\d-\d\d-\d\d/) {
                    $date = $col;
                } elsif ($col =~ /(\d\d)\/(\d\d)\/(\d{2,4})/) {
#print STDERR 'col match: ', $col, "\n";
                    my ($month, $day, $year) = ($1, $2, $3);
                    if ($year < 2000) { $year += 2000 }
                    if ($month > 12) {
                        # switch
                        ($month, $day) = ($2, $1);
                    }
                    $date = sprintf ('%04d-%02d-%02d', $year, $month, $day);
                }
                if ($col =~ /^\((\S+)\)$/) {
                    $node = $1;
                }
            }
            # really nothing else to do for this block
            next;
        }
#print STDERR 'date: ', $date, "\n";
        # set date (mostly debug)
        $block->{date} = $date;
        $block->{node} = $node;
        # convert lines
        my $lines = $block->{lines};
        my $cols = $block->{columns};
        my $num_cols = scalar @$cols;
        if ($#$lines > 0) {
            my $line_0 = split_line ($opts, $lines->[0]);
            my $line_1 = split_line ($opts, $lines->[1]);
            unless ($line_0->{time} && $line_1->{time}) {
                die ("ERROR: Bad time compare:  $lines->[0] eq $lines->[1]\n");
            }
            my $line_number = 0;
            foreach my $line (@$lines) {
                $line_number++;
                my $parsed = split_line ($opts, $line);
                unless (scalar @{$parsed->{values}} == $num_cols) { die "wrong number of columns: $line.\n"; }
                my $date_time = join ('T', ($date, $parsed->{time}));
                my $sub_event = undef;
                for (my $i = 0; $i < $num_cols; $i++) {
                    my $col = $cols->[$i];
                    if ($i == 0 && $col =~ /^[A-Z]+$/) {
                        # just qualifier for other values
                        $sub_event = $parsed->{values}[$i];
                        next;
                    }
                    my $event = join ('', (
                        '<event>',
                        create_element ('timestamp', $date_time),
                        create_element ('filename', $block->{filename}),
                        create_element ('linenumber', $line_number),
                        create_element ('node', $node),
                        create_element ('source', 'sar'),
                        create_element ('measure', $col),
                        (defined $sub_event ? create_element ('submeasure', $sub_event) : ''),
                        create_element ('value', $parsed->{values}[$i]),
                        '</event>',
                    ));
                    push @{$block->{events}}, $event;
                }
            }
        }
    }
}

sub xmlize_colname {
    my ($qname) = @_;
    $qname =~ s/%/percent-/g;
    $qname =~ s/\//-per-/g;
    return $qname;
}

sub create_element {
    my ($qname, $content) = @_;
    join ('', (
        '<', $qname, '><![CDATA[', $content, ']]></', $qname, '>'
    ));
}

# read blank-line delimited blocks
sub read_blocks {
    my ($filename, $fh) = @_;
    my @blocks = ();
    my $line_number = 0;
    my $holdover_line = undef;
    while (1) {
        my $block = [];
        if ($holdover_line) { 
            push @$block, $holdover_line;
            $holdover_line = undef;
        } else {
            while (my $line = <$fh>) {
                $line_number++;
                if ($line =~ /^[^\d].* \[sar -/) { $line = '' }
                if ($line =~ /^Average/) { next }
                if ($line =~ /^\s*$/) { last }
                if ($line =~ /^Linux/) { $holdover_line = $line; last }
                chomp ($line);
                push @$block, $line;
            }
        }
        unless (scalar @$block) {
            if (eof ($fh)) { last } else { next }
        }

        # header is first line, minus time
        my $header = shift @$block;
        $header =~ s/^\d\d:\d\d:\d\d//;
        $header =~ s/^\s+(AM|PM)\s*//;
        $header =~ s/^\s+//;
        $header =~ s/\s+$//;
        my @columns = split (/\s+/, $header);
        push @blocks, {
            filename => $filename,
            header => $header,
            columns => \@columns,
            lines => (scalar (@$block) > $BLOCK_LINE_MAX ? [@{$block}[0 .. $BLOCK_LINE_MAX-1]] : $block),
        };
    }
    return \@blocks;
}


# split line to time and columns. adjust time to 24 hr.
sub split_line {
    my ($opts, $line) = @_;
    my @parts = split '\s+', $line;
    # nothing, return of nothing means error
    my $return = {};
    unless ($#parts > 0)  { return $return }
    my ($time, $values);
    if    ($parts[1] eq 'AM') {
        my ($h,$m,$s) = split (':', $parts[0]);
        $return->{time} = join (':', (($h == 12 ? '00' : $h), $m, $s));
        $return->{values} = [@parts[2 .. $#parts]];
    } elsif ($parts[1] eq 'PM') {
        my ($h,$m,$s) = split (':', $parts[0]);
        $return->{time} = join (':', (($h < 12 ? $h+12 : $h), $m, $s));
        $return->{values} = [@parts[2 .. $#parts]];
    } elsif ($parts[0] eq 'Average') {
        $return->{time} = 'Average'
    } else {
        $return->{time} = $parts[0];
        $return->{values} = [@parts[1 .. $#parts]];
    }
    return $return;
}

sub print_message {
    my @strings = @_;
    print STDERR @strings, "\n";
}

