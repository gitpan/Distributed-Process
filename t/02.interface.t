use Test::More;

use IO::Socket;
use Distributed::Process::Interface;

my @test = ( 'line 1', "line\t2", '/line 3', 'fourth line' );
plan tests => 2 + @test;

my ($child, $parent) = IO::Socket->socketpair(PF_UNIX, SOCK_STREAM, PF_UNSPEC);
my $i = new Distributed::Process::Interface
    -in_handle => $parent,
    -out_handle => $parent,
;
isa_ok($i, 'Distributed::Process::Interface');
is_deeply([$i->handle_line('/ping')], ['pong']);
my $pid = fork;
die $! unless defined($pid);

if ($pid) {
    $parent->close();
    while ( <$child> ) {
        is($_, (shift @test) . "\015\012");
    }
}
else {
    $child->close();
    $i->send(@test);
}
