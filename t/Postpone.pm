package Postpone;

use Distributed::Process;
use Distributed::Process::Worker;

our @ISA = qw/ Distributed::Process::Worker /;

sub __test1 { DEBUG 'Dummy::__test1'; my $self = shift; $self->result("Running test1"); }
sub __test2 { DEBUG 'Dummy::__test2'; my $self = shift; $self->result("Running test2"); }
sub __test3 { DEBUG 'Dummy::__test3'; my $self = shift; $self->result("Running test3"); }

sub run {
    my $self = shift;
    $self->postpone('__test1');
    $self->synchro('test1');
    $self->postpone('__test2');
    $self->synchro('test2');
    $self->postpone('__test3');
}

1;
