use Test::More tests => 1;

use Distributed::Process::RemoteWorker;
my $t = new Distributed::Process::RemoteWorker;

isa_ok($t, 'Distributed::Process::RemoteWorker');

