package Distributed::Process::MasterWorker;

use warnings;
use strict;

use Distributed::Process;
import Distributed::Process;

use threads;
use Thread::Queue;
use Thread::Semaphore;

my $SELF;
my $SYNCHRO_SEMAPHORE = new Thread::Semaphore 0;
my $RESULT_SEMAPHORE = new Thread::Semaphore 0;
my $RESULT_QUEUE = new Thread::Queue;


sub new {

    my $self = shift;
    $SELF ||= $self->SUPER::new(@_);
}

sub result {

    my $self = shift;

    DEBUG 'gathering results';

    foreach ( $self->master()->workers() ) {
	$_->get_result();
    }
    my $down = $self->master()->workers();
    DEBUG "downing semaphore by $down";
    $RESULT_SEMAPHORE->down($down);
    DEBUG "semaphore released";
    my @result;
    DEBUG 'dequeuing the results';
    DEBUG $RESULT_QUEUE->pending() . ' items in the queue';
    while ( my $line = $RESULT_QUEUE->dequeue_nb() ) {
	push @result, $line;
    }
    DEBUG 'results dequeued';
    return @result;
}

sub result_received {

    my $self = shift;
    my $worker = shift;

    DEBUG "received results from '$worker'";
    my @result = $worker->result();
    DEBUG map "  $_", @result;
    $RESULT_QUEUE->enqueue(@result);
    DEBUG 'queued them';
    DEBUG $RESULT_QUEUE->pending() . ' items in the queue';
    DEBUG 'upping the semaphore';
    $RESULT_SEMAPHORE->up();
}

sub reset_result {

    my $self = shift;
    foreach ( $self->master()->workers() ) {
	$_->reset_result();
    }
}

sub synchro {

    my $self = shift;
    my $token = shift;

    DEBUG "requesting synchro for '$token'";

    foreach ( $self->master()->workers() ) {
	$_->synchro($token);
    }
    my $down = $self->master()->workers();
    DEBUG "downing semaphore by $down";
    $SYNCHRO_SEMAPHORE->down($down);
    DEBUG "semaphore released";
    DEBUG "synchro for '$token' done";
}

sub synchro_received {

    my $self = shift;
    my ($worker, $token) = @_;
    DEBUG "received synchro signal for '$token'";
    #lock($COUNT_SYNCHRO);
    #$COUNT_SYNCHRO--;
    #cond_signal $COUNT_SYNCHRO;
    DEBUG 'upping semaphore by 1';
    $SYNCHRO_SEMAPHORE->up();
}

sub run {

    my $self = shift;
    $self->synchro('ready');
    $self->SUPER::run(@_);
    $self->synchro('finished');
}

sub postpone {

    my $self = shift;
    my $method = shift;
    my $period = 1 / ($self->frequency() || 1);

    foreach ( $self->master()->workers() ) {
	select undef, undef, undef, $period;
	$_->$method(@_);
    }
}

sub frequency {

    my $self = shift;
    $self->master()->frequency(@_);
}

sub time {

    my $self = shift;
    foreach ( $self->master()->workers() ) {
	$_->time(@_);
    }
}

foreach my $method ( qw/ master / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

1;
