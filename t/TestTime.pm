package TestTime;

use Distributed::Process;
use Distributed::Process::Worker;

our @ISA = qw/ Distributed::Process::Worker /;

sub __test1 { DEBUG 'Dummy::__test1'; my $self = shift; sleep 1; $self->result('__test1 ' .uc $_[0]) }
sub __test2 { DEBUG 'Dummy::__test2'; my $self = shift; sleep 2; $self->result('__test2 ' .uc $_[0] . ' ' . $self->get_result_from_list()) }
sub __test3 { DEBUG 'Dummy::__test3'; my $self = shift; sleep 3; $self->result('__test3 ' .uc $_[0]) }

sub get_result_from_list {

    my $self = shift;
    $self->{_result_list} ||= [ map "result_$_", 1 .. 100 ];
    shift @{$self->{_result_list}};
}
sub run {
    my $self = shift;
    $self->time('__test1', $self->get_result_from_list());
    $self->time('__test2', $self->get_result_from_list());
    $self->time('__test3', sub { $self->get_result_from_list() } );
}

1;
