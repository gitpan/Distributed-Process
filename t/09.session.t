use Test::More;
use strict;

use lib 't';

use Distributed::Process;

use Socket qw/ :crlf /;
use IO::Socket;
use IO::Select;
$/ = CRLF;

my $n_workers = 3;
plan tests => 6 * $n_workers;
my $port = 8147;

my @pid;
my %expected;
for ( 1 .. $n_workers ) {
    my $pid = fork;

    if ( !$pid ) {
	require Dummy;
	require Distributed::Process::Client;
	sleep 2;
	my $c = new Distributed::Process::Client
	    -worker_class => 'Dummy',
	    -host => 'localhost',
	    -port => 8147,
	;
	$c->run();
	exit 0;
    }
    else {
	push @pid, $pid;
	$expected{"$pid:Running test$_"} = 1 for 1 .. 3;
    }
}

require Dummy;
require Distributed::Process::Master;
require Distributed::Process::Server;
my ($server, $parent) = IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $server_pid = fork;
if ( ! $server_pid ) {
    die "Cannot fork: $!" unless defined($server_pid);
    $server->close();
    my $m = new Distributed::Process::Master
        -worker_class => 'Dummy',
        -n_workers => $n_workers,
        -in_handle => $parent,
        -out_handle => $parent,
    ;
    my $s = new Distributed::Process::Server master => $m, port => 8147;
    $s->listen();
    exit 0;
}
$parent->close();

DEBUG 'sleeping 5 secs';
sleep 5;
print $server "/run" . CRLF;
while ( <$server> ) {
    chomp;
    /ok/ and last;
    /\t/ or next;
    my ($pid, $date, $msg) = split /\t/;
    ok(exists $expected{"$pid:$msg"});
}

print $server "/reset" . CRLF;
sleep 1;
print $server "/run" . CRLF;
while ( <$server> ) {
    chomp;
    /ok/ and print $server "/quit" . CRLF;
    /\t/ or next;
    my ($pid, $date, $msg) = split /\t/;
    ok(exists $expected{"$pid:$msg"});
}
