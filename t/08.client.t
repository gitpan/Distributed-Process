use Test::More tests => 7;

use lib 't';
#use Distributed::Process qw/ :debug /;
use Distributed::Process::Client;
use Dummy;


my $c = new Distributed::Process::Client
    -host => 'localhost',
    -port => 8147,
    -worker_class => 'Dummy'
;
isa_ok($c, 'Distributed::Process::Client');
isa_ok($c->worker(), 'Dummy');
is(($c->handle_line(qw{ /run __test1 testing}))[0], undef);
my @expected = ( '/begin_results', '__test1 TESTING', 'ok' ); 
foreach ( $c->handle_line(qw{ /get_results }) ) {
    my $e = shift @expected;
    like($_, qr/\E$e$/);
}
is(($c->handle_line(qw{ /synchro something }))[0], '/synchro something');

