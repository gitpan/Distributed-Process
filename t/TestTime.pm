package TestTime;

use Distributed::Process;
use Distributed::Process::Worker;

our @ISA = qw/ Distributed::Process::Worker /;

sub __test1 { DEBUG 'Dummy::__test1'; my $self = shift; sleep 1; }
sub __test2 { DEBUG 'Dummy::__test2'; my $self = shift; sleep 2; }
sub __test3 { DEBUG 'Dummy::__test3'; my $self = shift; sleep 3; }

sub run {
    my $self = shift;
    $self->time('__test1');
    $self->time('__test2');
    $self->time('__test3');
}

1;
