package Distributed::Process::MasterWorker;

use warnings;
use strict;

use Distributed::Process;
import Distributed::Process;

use threads;
use threads::shared qw/ cond_wait cond_broadcast /;
use Thread::Queue;
use Thread::Semaphore;

my $SELF;
my $SYNCHRO_SEMAPHORE = new Thread::Semaphore 0;
my $SYNCHRO_SEMAPHORE_2 = new Thread::Semaphore 0;
my $SYNCHRO_TOKEN : shared = '';
my $SYNCHRO_COUNTER : shared = 0;
my $RESULT_SEMAPHORE = new Thread::Semaphore 0;
my $RESULT_QUEUE = new Thread::Queue;


sub new {

    my $self = shift;
    $SELF ||= $self->SUPER::new(@_);
}

sub result {

    my $self = shift;

    INFO 'gathering results';

    foreach ( $self->master()->workers() ) {
	$_->get_result();
    }
    my $down = $self->master()->workers();
    DEBUG "downing semaphore by $down";
    $RESULT_SEMAPHORE->down($down);
    DEBUG "semaphore released";
    my @result;
    DEBUG $RESULT_QUEUE->pending() . ' items in the queue';
    while ( my $line = $RESULT_QUEUE->dequeue_nb() ) {
	push @result, $line;
    }
    return @result;
}

sub result_received {

    my $self = shift;
    my $worker = shift;

    DEBUG "received results from '$worker'";
    my @result = $worker->result();
    $RESULT_QUEUE->enqueue(@result);
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

    lock $SYNCHRO_COUNTER;
    $SYNCHRO_COUNTER ||= $self->master()->workers();
    cond_wait $SYNCHRO_COUNTER until $SYNCHRO_COUNTER == 0;
}

sub synchro_received {

    my $self = shift;
    my ($worker, $token) = @_;
    DEBUG "received synchro signal for '$token'";
    lock $SYNCHRO_COUNTER;
    $SYNCHRO_COUNTER --;
    cond_broadcast $SYNCHRO_COUNTER if $SYNCHRO_COUNTER == 0;
}

sub run {

    my $self = shift;
    my @tid;
    foreach my $w ( $self->master()->workers() ) {
	push @tid, async { $w->run(@_); 1; };
    }
    $_->join() foreach @tid;
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
