#!/usr/bin/perl -w

use strict;

use FindBin;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Data::Dumper;

my $info_dir = "$FindBin::Bin/stack-info";
my $stack_info = read_stack_info_files ($info_dir);
print Dumper $stack_info;


sub read_stack_info_files {
    my ($info_dir) = @_;
    my $retval = { matchers => [] };
    my @info_files = <$info_dir/*.info>;
    foreach my $filename (@info_files) {
        my $matcher = { filename => $filename };
        open my $fh, "<", $filename or die "Can't open $filename for read.\n";
        while (my $line = <$fh>) {
            $line =~ s/[\r\n]+$//;
            my ($operator, $value) = ($line =~ /^#([\S]+)\s+(.*)/);
            if (! $operator) { push @{$matcher->{lines}}, $line; }
            elsif ($operator eq 'NAME') { push @{$matcher->{name}}, $value }
            elsif ($operator eq 'TAGS') { push @{$matcher->{tags}}, split ('\s*,\s*', $value) }
            else { print STDERR "Unknown operator $operator?\n"; }
        }
        close $fh;
        $matcher->{full_hash} = md5_hex (join ('', @{$matcher->{lines}}));
        push @{$retval->{matchers}}, $matcher;
    }
    return $retval;
}

