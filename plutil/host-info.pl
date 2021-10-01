#!/usr/bin/perl -w
use strict;
use Data::Dumper;

my %results = ();

my @files = @ARGV;

foreach my $filename (@files) {
    open my $fh, '<', $filename || die "Can't open $filename.\n";
    while (my $line = <$fh>) {
        chomp $line;
        if ($line =~ /Starting MarkLogic Server (\S+) (\S+) in (\S+) with data in (.*)/) {
            my ($version, $architecture, $install_dir, $data_dir) = ($1, $2, $3, $4);
            $results{$filename}{version}{$version}++;
            $results{$filename}{architecture}{$architecture}++;
            $results{$filename}{install_dir}{$install_dir}++;
            $results{$filename}{data_dir}{$data_dir}++;
            $results{$filename}{restarts}++;
        } elsif ($line =~ /Info: Host (\S+) with (\S+) memory running (.*)/) {
            my ($host, $memory, $platform) = ($1, $2, $3);
            $results{$filename}{isLocal}{$host}++;
            $results{$filename}{local_host_mentions}{$host}++;
            $results{$filename}{host}{$host}++;
            $results{$filename}{memory}{$memory}++;
            $results{$filename}{platform}{$platform}++;
        } elsif ($line =~ /(XDQPServerConnection).*?(\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,5}):(\d{3,5})-(\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,5}):(\d{3,5})/) {
            my ($context, $local, $local_port, $foreign, $foreign_port) = ($1, $2, $3, $4, $5);
print "$line\n     ($context, $local, $local_port, $foreign, $foreign_port).\n";

            if ($foreign_port eq '7999')    { $results{$filename}{local_host_mentions}{$foreign}++; }
            elsif ($foreign_port eq '7998') { $results{$filename}{foreign_host_mentions}{$foreign}++; }
            else                            { $results{$filename}{host_mentions}{$foreign}++; }

            $results{$filename}{host}{$local}++;
        } elsif ($line =~ /(XDQPServerConnection::init:)\s+(\d{1,5}\.\d{1,5}\.\d{1,5}\.\d{1,5})/) {
            my ($context, $foreign) = ($1, $2);
print "$line\n     ($context, $foreign).\n";
            $results{$filename}{host_mentions}{$foreign}++;
        }
        # next can be more general?
#        } elsif ($line =~ /(SSL_accept|SSL_write|BIO_read|recv|send) (\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.):(\d{3,5})-(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\.):(\d{3,5})/) {
#            my ($problem, $local, $local_port, $foreign, $foreign_port) = ($1, $2, $3, $4, $5);
#print "$line\n     ($problem, $local, $local_port, $foreign, $foreign_port).\n";
#            $results{$filename}{host_mentions}{$local}++;
#            $results{$filename}{host_mentions}{$foreign}++;
#            $results{$filename}{isLocal}{$local}++;
#        }
    }
    close ($fh);
}

print Dumper \%results;
