use Test::More tests => 6;

use Distributed::Process::Master;
my $m = new Distributed::Process::Master
    -worker_class => 'Distributed::Process::Worker',
    -n_workers => 1,
;

isa_ok($m, 'Distributed::Process::Master');
isa_ok($m, 'Distributed::Process::Interface');
is($m->worker_class(), 'Distributed::Process::Worker', 'attribute correctly set by constructor');
is($m->n_workers(), 1, 'attribute correctly set by constructor');
$m->handle_line("/frequency 0.5");
is($m->frequency(), 0.5, '/frequency callback works');
$m->handle_line("/frequency\t0.25");
is($m->frequency(), 0.25, '/frequency callback splits on tabs also');
