#!perl -T
use Test::More;
use strict;

use lib 't';

use Distributed::Process;

use Socket qw/ :crlf /;
use IO::Socket;
$/ = CRLF;

my $n_workers = 3;
plan tests => 6 * $n_workers;
my $port = 8147;

my %expected;
for ( 1 .. $n_workers ) {
    my $pid = fork;

    if ( !$pid ) {
	require TestTime;
	require Distributed::Process::Client;
	sleep 2;
	my $c = new Distributed::Process::Client
	    -worker_class => 'TestTime',
	    -host => 'localhost',
	    -port => $port,
            -id   => "wrk$_",
	;
	$c->run();
	exit 0;
    }
    else {
        no warnings 'uninitialized';
        my $o = 3 * ($_ - 1);
	$expected{"__test1 RESULT_" . ($o + 1)} = 1;
	$expected{"__test2 RESULT_" . ($o + 2) . " RESULT_1"} = 1;
	$expected{"__test3 RESULT_" . ($o + 3)} = 1;

        $o = 3 * ($n_workers + $_ - 1);
	$expected{"__test1 RESULT_" . ($o + 1)} = 1;
	$expected{"__test2 RESULT_" . ($o + 2) . " RESULT_2"} = 1;
	$expected{"__test3 RESULT_" . ($o + 3)} = 1;
    }
}

require TestTime;
require Distributed::Process::Master;
require Distributed::Process::Server;
my ($server, $parent) = IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $server_pid = fork;
if ( ! $server_pid ) {
    die "Cannot fork: $!" unless defined($server_pid);
    $server->close();
    my $m = new Distributed::Process::Master
        -worker_class => 'TestTime',
        -n_workers => $n_workers,
        -in_handle => $parent,
        -out_handle => $parent,
    ;
    my $s = new Distributed::Process::Server master => $m, port => $port;
    $s->listen();
    exit 0;
}
$parent->close();

while ( <$server> ) {
    last if /ready to run/;
}
print $server "/run" . CRLF;
$/ = CRLF;
while ( <$server> ) {
    chomp;
    /ok/ and print $server "/quit" . CRLF;
    /\t/ or next;
    my ($id, $date, $msg) = split /\t/;
    if ( my ($n, $t) = $msg =~ /Time for running __test(\d): ([\d.]+) seconds/ ) {
        is($n, sprintf("%.0f", $t));
    }
    else {
        ok($expected{$msg});
    }
}
