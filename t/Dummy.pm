package Dummy;

use warnings;
use strict;
use threads;
use threads::shared;

use Distributed::Process; # qw/ :debug /;
use Distributed::Process::Worker;
our @ISA = qw/ Distributed::Process::Worker /;

sub __test1 { DEBUG 'Dummy::__test1'; my $self = shift; $self->result('__test1 ' .uc $_[0]) }
sub __test2 { DEBUG 'Dummy::__test2'; my $self = shift; $self->result('__test2 ' .uc $_[0] . ' ' . $self->get_result_from_list()) }
sub __test3 { DEBUG 'Dummy::__test3'; my $self = shift; $self->result('__test3 ' .uc $_[0]) }

sub __sleep { my $s = 2+int(rand(5)); DEBUG "sleeping for $s seconds"; sleep $s; return }

{
    my $result : shared = 1;
    sub get_result_from_list {

	my $self = shift;
	INFO "get_result_from_list: yielding $result";
	'result_' . $result++;
    }
}

sub run {

    DEBUG '';
    my $self = shift;

    $self->__sleep();
    DEBUG 'about to run __test1';
    $self->__test1($self->get_result_from_list());
    $self->__sleep();
    DEBUG 'about to run __test2';
    $self->__test2($self->get_result_from_list());
    DEBUG 'about to synchronise';
    $self->synchro('meeting');
    DEBUG 'about to run __test3';
    $self->__test3($self->get_result_from_list());
}

1;
