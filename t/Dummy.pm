package Dummy;

use warnings;
use strict;

use Distributed::Process; # qw/ :debug /;
use Distributed::Process::Worker;
our @ISA = qw/ Distributed::Process::Worker /;

sub __test1 { DEBUG 'Dummy::__test1'; my $self = shift; $self->result("Running test1"); }
sub __test2 { DEBUG 'Dummy::__test2'; my $self = shift; $self->result("Running test2"); }
sub __test3 { DEBUG 'Dummy::__test3'; my $self = shift; $self->result("Running test3"); }

sub __sleep { my $s = 2+int(rand(5)); DEBUG "sleeping for $s seconds"; sleep $s; return }

sub run {

    DEBUG '';
    my $self = shift;

    $self->__sleep();
    DEBUG 'about to run __test1';
    $self->__test1();
    $self->__sleep();
    DEBUG 'about to run __test2';
    $self->__test2();
    DEBUG 'about to synchronise';
    $self->synchro('meeting');
    DEBUG 'about to run __test3';
    $self->__test3();
}

1;
