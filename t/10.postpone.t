use Test::More;
use strict;

use lib 't';
use Time::Local;

use Distributed::Process;

use Socket qw/ :crlf /;
use IO::Socket;
use IO::Select;
$/ = CRLF;

my $n_workers = 5;
plan tests => 3 * ($n_workers - 1);
my $port = 8147;

my %expected;
for ( 1 .. $n_workers ) {
    my $pid = fork;

    if ( !$pid ) {
	require Postpone;
	require Distributed::Process::Client;
	sleep 2;
	my $c = new Distributed::Process::Client
	    -worker_class => 'Postpone',
	    -host => 'localhost',
	    -port => 8147,
            -id  => "wrk$_",
	;
	$c->run();
	exit 0;
    }
    else {
	$expected{"wrk$_:Running test$_"} = 1 for 1 .. 3;
    }
}

require Postpone;
require Distributed::Process::Master;
require Distributed::Process::Server;
my ($server, $parent) = IO::Socket->socketpair(AF_UNIX, SOCK_STREAM, PF_UNSPEC)
    or die "socketpair: $!";
my $server_pid = fork;
if ( ! $server_pid ) {
    die "Cannot fork: $!" unless defined($server_pid);
    $server->close();
    my $m = new Distributed::Process::Master
        -worker_class => 'Postpone',
        -n_workers => $n_workers,
        -in_handle => $parent,
        -out_handle => $parent,
	-frequency => .25,
    ;
    my $s = new Distributed::Process::Server master => $m, port => 8147;
    $s->listen();
    exit 0;
}
$parent->close();

my %result = ();
while ( <$server> ) {
    last if /ready to run/;
}

print $server "/run" . CRLF;
while ( <$server> ) {
    chomp;
    /^ok/ and print $server "/quit" . CRLF;
    /\t/ or next;
    my ($id, $date, $msg) = split /\t/;
    push @{$result{$msg} ||= []}, $date;
}

foreach ( values %result ) {
    for ( @$_ ) {
        my ($Y, $m, $d, $H, $M, $S) = /(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)/;
        $Y -= 1900;
        $m--;
        $_ = timelocal $S, $M, $H, $d, $m, $Y;
    }
    my $x = shift @$_;
    while ( @$_ ) {
        my $y = shift @$_;
        my $diff = abs($x - $y);
        ok($diff == 4 || $diff == 5);
        $x = $y;
    }
}
