#!perl -T
use Test::More tests => 4;

use Distributed::Process::Worker;
use Distributed::Process::RemoteWorker;
my $t = new Distributed::Process::RemoteWorker;

isa_ok($t, 'Distributed::Process::RemoteWorker');

@Test::A::ISA = qw/ Distributed::Process::Worker /;
Test::A::->go_remote();
@Test::B::ISA = qw/ Test::A /;
@Test::C::ISA = qw/ Test::B Test::A /;

is_deeply([Test::A->ancestors()], [ qw/ Distributed::Process::Worker Distributed::Process::RemoteWorker Distributed::Process::BaseWorker Distributed::Process Exporter Distributed::Process::Interface / ]);
is_deeply([Test::B->ancestors()], [ qw/ Test::A Distributed::Process::Worker Distributed::Process::RemoteWorker Distributed::Process::BaseWorker Distributed::Process Exporter Distributed::Process::Interface / ]);
is_deeply([Test::C->ancestors()], [ qw/ Test::B Test::A Distributed::Process::Worker Distributed::Process::RemoteWorker Distributed::Process::BaseWorker Distributed::Process Exporter Distributed::Process::Interface / ]);
