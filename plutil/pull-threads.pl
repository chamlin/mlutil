#!/usr/bin/perl -w
use strict;

# separates dumps.  should handle disconnects in dumps in/between threads
# compresses consecutive calls
use Getopt::Std;
use Data::Dumper;

my $default_date = 
       {
         'text' => 'N/A',
         'line' => 'N/A',
         'date' => '1900-00-01 00:00:00.000',
         'type' => 'date_line'
       };

my $s = { state => 'general', sys_lines => [], last_date_line => $default_date, lines => 0, dumps => [], opts => { s => 0 } };


# s is # of space delimited leading fields to carve off
getopt ('s', $s->{opts});

while (my $line = <>) {
    chomp $line;
    # skip (possibly) some fields (usually node name?)
    for (my $remove = $s->{opts}{s}; $remove; $remove--) {
        my @parts = split (/\s+/, $line, 2);
        $line = $parts[1];
    }
    $s->{lines}++;
    my $typed = type_line ($line);
    my $do = process_typed_line ($s, $typed);
}

dump_results ($s);

sub dump_results {
    my ($s) = @_;
    my @dumps = @{$s->{dumps}};
    print "lines: $s->{lines}\n\n";
    print "dumps: ", scalar (@dumps), "\n\n";

    for (my $i = 0; $i <= $#dumps; $i++) {
        print "dump #", $i+1, ":\n\n";
        dump_dump ($dumps[$i]);
    }
}

sub dump_dump {
    my ($dump) = @_;
    if ($dump->{date_line} && $dump->{date_line}{line}) {
        print "$dump->{date_line}{line}\n\n";
    } else {
        print "Huh?!  Why come no date line!?\n\n";
    }
    if ($dump->{sys_lines}) {
        foreach my $sys_line (@{$dump->{sys_lines}}) {
            print "$sys_line->{line}\n";
        }
        print "\n";
    }
    foreach my $thread (@{$dump->{threads}}) {

        my $last_line = undef;

        # compress the lines if repeated exactly
        foreach my $typed (@{$thread}) {
            if (defined $last_line) {
                #   if current type eq call_line
                #       if current text eq last text   set last->{end_num} = current->{num}
                #       else ship out last, set last to current
                #   otherwise, ship out last, ship out current
                if ($typed->{type} eq 'call_line') {
                    if ($typed->{text} eq $last_line->{text}) {
                        $last_line->{last_num} = $typed->{num};
                    } else {
                        ship_line ($last_line);
                        $last_line = $typed;
                    }
                } else {
                    ship_line ($last_line);
                    ship_line ($typed);
                    undef $last_line;
                }
            } else {
                # no last, sooooo
                #   if type eq call_line, save it as last
                #   otherwise, send it out
                if ($typed->{type} eq 'call_line') {
                    $last_line = $typed;
                } else {
                    ship_line ($typed);
                }
            }
        
        }

        ship_line ($last_line);

        print "\n";
    }
}

sub ship_line {
    my ($typed) = @_;

    unless (defined $typed) { return }

    if (exists $typed->{last_num}) {
        print "#$typed->{num} -> #$typed->{last_num} $typed->{text}\n";
    } else {
        print "$typed->{line}\n";
    }
}

sub dump_continued {
    my ($s, $typed) = @_;
    # get MR dump (if any).
    #     get last typed line in dump
    #     check this # vs that.
    my $retval = 0;

    if (scalar @{$s->{dumps}}) {
        my $mr_dump = $s->{dumps}[0];
        my $mr_thread = $mr_dump->{threads}[$#{$mr_dump->{threads}}];
        my $mr_thread_number = $mr_thread->[0]{num};
        my $typed_number = $typed->{num};
        if ($mr_thread_number > $typed_number) {
            $retval = 1;
        }
    }


    return $retval;
}

# what to do with this line?
sub process_typed_line {
    my ($s, $typed) = @_;
    my $state = $s->{state};
    my $type = $typed->{type};
    if ($state eq 'general') { 
        if ($type eq 'date_line') {
            $s->{last_date_line} = $typed;
            $s->{sys_lines} = [];
        } elsif ($type eq 'call_line') {
            # add to MR thread (last), change back to dump
            push @{${$s->{current}{threads}}[-1]}, $typed;
            $s->{state} = 'dump';
        } elsif ($type eq 'sys_line') {
            push @{$s->{sys_lines}}, $typed;
        } elsif ($type eq 'thread_line') {
        # Check for MR stack thread.  Is this number lower than that one?  Then reopen it as current.
            if (dump_continued ($s, $typed)) {
                # continue with old dump
                push @{${$s->{current}{threads}}[-1]}, $typed;
                $s->{state} = 'dump';
            } else {
                # start new dump
                my $current = {
                    date_line => $s->{last_date_line},
                    sys_lines => $s->{sys_lines},
                    threads => [ [ $typed ] ]
                };
                push @{$s->{dumps}}, $current;
                $s->{current} = $current;
                $s->{state} = 'dump';
                $s->{sys_lines} = [];
                $s->{last_date_line} = $default_date;
            }
        }
    } elsif ($state eq 'dump') { 
        if ($type eq 'date_line') {
            # dump finished
            $s->{last_date_line} = $typed;
            $s->{state} = 'general';
        } elsif ($type eq 'sys_line') {
            # add to current thread, keep thread going
            push @{${$s->{current}{threads}}[-1]}, $typed;
            #$s->{state} = 'general';
        } elsif ($type eq 'thread_line') {
            # start new thread
            push @{$s->{current}{threads}}, [ $typed ];
        } elsif ($type eq 'call_line') {
            # add to current thread (last)
            push @{${$s->{current}{threads}}[-1]}, $typed;
        } else {
            die Dumper $s;
        }
    }
};

sub type_line {
    my ($line) = @_;
    my $retval = { type => 'unknown', line => $line };
    if ($line =~ /^(\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d(?:\.\d+)) (.*)/) {
        $retval = { type => 'date_line', date => $1, text => $2, line => $line };
    } elsif ($line =~ /^#(\d+)\s+(.*)/) {
        $retval = { type => 'call_line', num => $1, text => $2, line => $line };
    } elsif ($line =~ /^Thread (\d+) (.*)/) {
        $retval = { type => 'thread_line', num => $1, text => $2, line => $line };
    } else {
        $retval = { type => 'sys_line', line => $line };
    }
    return $retval;
}
