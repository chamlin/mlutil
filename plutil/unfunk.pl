#!/usr/bin/perl -w

use strict;

while (<>) {
    my $line = $_;
    $line =~ s/[\r\n]+$//;
    while ($line =~ /linkprotect/) {
        my ($pre, $link, $post) = ($line =~ m!^(.*)(https://linkprotect.cudasvc.com/.*typo=\d+(?:&ancr_add=\d+)?)(.*)!);
        my ($new) = ($link =~ m/a=(.+?)&/);
        $new =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
        print STDERR "> $link\n< $new\n\n";
        $line = "$pre$new$post";
    }
    print "$line\n";
}
