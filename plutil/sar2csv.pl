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
# for not blow up
my $MAX_FH = 200;

my $opts = {};


getopts ('0ab:d:f:hs:ux', $opts);

if ($opts->{u} or !exists $opts->{f}) {
    print "    -a    keep average rows\n";
    print "    -b    base prefix for output files\n";
    print "    -d    debug output---comma/semi separated\n";
    print "    -e    extension\n";
    print "    -f    file---comma/semicolon separated\n";
    print "    -h    header line\n";
    print "    -s    separator\n";
    print "    -x    separate block with multiple readings (e.g., CPU0, CPU1, ..., all)\n";
    print "    -u    use (this) \n";
    print "    -0    no output (except debug)\n";
    print "\n";
    print "options parsed: ", Dumper ($opts), "\n";
    exit;
}

if ($opts->{e}) { $opts->{e} =~ s/^\.// }
else            { $opts->{e} = 'csv' }
unless ($opts->{s}) { $opts->{s} = ',' }

# split.  to check for 'merge' flag, as:  $opts->{debug}{merge}
if (exists $opts->{d}) {
    my @flags = split /[,;]/, $opts->{d};
    foreach my $flag (@flags) { $opts->{debug}{$flag} = 1 }
}

if ($opts->{debug}{config}) { die Dumper \$opts }

# do each file (hmm, maybe only one at a time, or overwrites)
foreach my $filename (split /[,;]/, $opts->{f}) {
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
    my $blocks = read_blocks ($fh);
    close ($fh);

    # first block is file header
    my $head_block = shift @$blocks;

    merge_blocks ($blocks);

    prep_blocks ($opts, $blocks);

    unless ($opts->{'0'}) { foreach my $block (@$blocks) { dump_block ($opts, $block) } }

    if ($opts->{debug}{blocks}) { print_message ('blocks: ', Dumper $blocks) }
}


####### subs

sub filename {
    my ($opts, $block, $values) = @_;
    my $prefix = exists $opts->{b} ? "$opts->{b}-" : '';
    my $filename;
    if ($block->{repeats} && $opts->{x}) {
        $filename = $prefix . $block->{title} . '_' . $values->[0] . '.' . $opts->{e};
    } else {
        $filename = $prefix . $block->{title} . '.' . $opts->{e};
    }
    return $filename;
}

sub dump_block {
    my ($opts, $block) = @_;
    my %fhs = ();
    my $title = $block->{title};
    my $repeats = $block->{repeats} && $opts->{x};
    my $lines = $block->{lines};
    foreach my $line (@$lines) {
        my ($time, $values) = @{split_line ($opts, $line)}{'time', 'values'};
        unless ($time && scalar @$values) {
            print_message ("ERROR:  Bad line ignoring (shown in pipes):\n|$line|");
            next;
        }
        my $fn = filename ($opts, $block, $values);
        my $start_index = 0;
        # unless, repeats . . .
        if ($repeats) { $start_index = 1; }
        my $row = join ($opts->{s}, ($time, @{$values}[$start_index .. $#{$values}])) . "\n";
        my $got_fh = get_fh (\%fhs, $fn);
        my $fh = $got_fh->{fh};

        # header line.  avoid the repeated header, if you are avoiding the repeated values.
        my @headers = ('time', @{$block->{columns}}[$start_index .. $#{$block->{columns}}]);
        if ($opts->{h} && $got_fh->{new}) { print $fh '#',  join ($opts->{s}, @headers), "\n" }
        print $fh $row;
    }
    # close fhs
    foreach my $filename (keys %fhs) { if ($fhs{$filename}) { close $fhs{$filename} } }
}

# { return:  { 'new' -> 0/1, 'fh' -> <fh> }
sub get_fh {
    # $fhs->{$fn} = fh
    my ($fhs, $fn) = @_;

    # default, creates errors
    my $retval = { 'new' => 0, 'fh' => undef };

    # has open fn
    if ($fhs->{$fn}) {
        $retval = { 'new' => 0, 'fh' => $fhs->{$fn} };
    } else {
        # if it was false, but key exists, then was open but got closed
        my $was_open = exists $fhs->{$fn};

        # get OPEN filenames
        my @filenames = grep { $fhs->{$_} } keys %$fhs;

        if ((scalar @filenames) >= $MAX_FH) {
            # clear some FH, but leave key, which means we've written (even if currently closed (false))
            foreach my $to_close ((@filenames)[0]) {
                close $fhs->{$to_close};
                $fhs->{$to_close} = 0;
                if ($opts->{debug}{io}) { print_message ("< $to_close") }
            }
        }
        my $open_op = $was_open ? '>>' : '>';
        open (my $fh, $open_op, $fn);
        print "$open_op $fn\n" if $opts->{debug}{io};
        $fhs->{$fn} = $fh;
        $retval = { 'new' => (!$was_open), 'fh' => $fh };
    }

    return $retval;
}

sub prep_blocks {
    my ($opts, $blocks) = @_;
    my %titles = ();
    foreach my $block (@$blocks) {
        # create title
        my $title = $block->{columns}[0];
        # uniquify a bit; enough?
        if ($title =~ /^[A-Z]+$/)   { $title = $title . '_' . $block->{columns}[1]; }
        # 0126 is 'word' char, but really stand-in for hyphen
        $title =~ s|\/s|\x{0126}per\x{0126}s|g;
        $title =~ s/\W//g;
        $title =~ s|\x{0126}|-|g;
        # uniquified a bit; enough?
        if (exists $titles{$title})  {
            print_message ("ERROR: Repeat title $title.\n", Dumper (\$block), Dumper \$blocks);
            die;
        }
        $titles{$title}++;
        $block->{title} = $title;

        # check if this is repeating times, if so, then it's repeating for different values in col 1
        my $lines = $block->{lines};
        if ($#$lines > 0) {
            my $line_0 = split_line ($opts, $lines->[0]);
            my $line_1 = split_line ($opts, $lines->[1]);
            unless ($line_0->{time} && $line_1->{time}) {
                print_message ("ERROR: Bad time compare:  $lines->[0] eq $lines->[1]\n");
            }
            $block->{repeats} = $line_0->{time} eq $line_1->{time};
        } 
    }
}

sub merge_blocks {
    my ($blocks) = @_;
    my $index = 0;
    my $debug = $opts->{debug}{merge};
    while ($index < $#{$blocks}) {
        print_message ("Merge check $blocks->[$index]{header}.\n") if $debug;
        my $to_check = $index + 1;
        while ($to_check <= $#{$blocks}) {
            print_message ("   vs $blocks->[$to_check]{header}.\n") if $debug; 
            # if it matches, merge it
            if ($blocks->[$to_check]{header} eq 'LINUX RESTART') {
                # just toss these; they note a restart, but have no readings
                print_message ("Toss $blocks->[$to_check]{header}.\n") if $debug; 
                splice @$blocks, $to_check, 1;
            } elsif ($blocks->[$index]{header} eq $blocks->[$to_check]{header}) {
                print_message ("MERGE $blocks->[$index]{header} ($index and $to_check).\n") if $debug; 
                push @{$blocks->[$index]{lines}}, @{$blocks->[$to_check]{lines}};
                splice @$blocks, $to_check, 1;
            } else {
                $to_check++;
            }
        }
        $index++;
    }
}

# read blank-line delimited blocks
sub read_blocks {
    my ($fh) = @_;
    my @blocks = ();
    while (1) {
        my $block = read_block ($fh);
        unless (scalar @$block) { last }
        # header is first line, minus time
        my $header = shift @$block;
        $header =~ s/^\d\d:\d\d:\d\d//;
        $header =~ s/^\s+(AM|PM)\s*//;
        $header =~ s/^\s+//;
        $header =~ s/\s+$//;
        my @columns = split (/\s+/, $header);
        push @blocks, {
            header => $header,
            columns => \@columns,
            lines => (scalar (@$block) > $BLOCK_LINE_MAX ? [@{$block}[0 .. $BLOCK_LINE_MAX-1]] : $block),
        };
    }
    return \@blocks;
}

# read blank-line delimited block
sub read_block {
    my ($fh) = @_;
    my @line_array = ();
    while (my $line = <$fh>) {
        if ($line =~ /^Average/ && ! $opts->{a}) { next }
        if ($line =~ /^\s*$/) { last }
        chomp ($line);
        push @line_array, $line;
    }
    return \@line_array;
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

