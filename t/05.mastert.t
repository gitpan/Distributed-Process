use Test::More tests => 4;

use Distributed::Process::Master;
my $m = new Distributed::Process::Master -worker_class => 'Distributed::Process::Worker';

my $mt = $m->master_worker();
isa_ok($mt, 'Distributed::Process::MasterWorker');
isa_ok($mt, 'Distributed::Process::Worker');
isa_ok($mt, 'Distributed::Process::RemoteWorker');
can_ok($mt, 'run');
