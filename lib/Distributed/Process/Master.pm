package Distributed::Process::Master;

use warnings;
use strict;

use threads;

use Carp;
use Distributed::Process;
use Distributed::Process::Worker;
use Distributed::Process::RemoteWorker;
use Distributed::Process::MasterWorker;

use Distributed::Process::Interface;
our @ISA = qw/ Distributed::Process::Interface /;
@Distributed::Process::Worker::ISA = qw/ Distributed::Process::RemoteWorker /;

our $SELF;
sub new {

    my $self = shift;
    $SELF ||= $self->SUPER::new(@_);
}

sub command_handlers {

    my $self = shift;
    return (
	$self->SUPER::command_handlers(),
	[ qr|^/run|,  sub { $self->run() } ],
	[ qr|^/freq|, sub { local $_ = (split ' ', $_[0])[1]; tr/0-9.//cd; $self->frequency($_) } ],
	[ qr|^/quit|, sub { $self->server()->quit() } ],
    );
}

sub add_worker {

    my $self = shift;
    my $worker = shift;
    if (!ref($worker) || !$worker->isa('Distributed::Process::Worker') ) {
	my $class = $self->worker_class();
	$worker = $class->new(-master => $self, $self->worker_args(), $worker, @_);
    }
    push @{$self->{_workers}}, $worker;
    DEBUG 'new worker arrived';
    $self->send('new worker arrived');
    $self->send('ready to run') if $self->n_workers() <= $self->workers();
    return $worker;
}

sub remove_worker {

    my ($self, $worker) = @_;
    my $i;
    for ( $i = 0; $i < @{$self->{_workers}}; $i++ ) {
	last if $self->{_workers}[$i] eq $worker;
    }
    my $removed = splice @{$self->{_workers}}, $i, 1;
    DEBUG 'worker departed, ' . ($self->workers() || 'none') . 'left';
    return $removed;
}

sub workers {

    my $self = shift;
    wantarray ? @{$self->{_workers}} : scalar @{$self->{_workers}};
}

sub close {

    my $self = shift;
    exit 0;
}

sub master_worker {

    my $self = shift;
    return $self->{_master_worker} if $self->{_master_worker};

    DEBUG 'creating master worker instance';
    croak "master_worker() must be called after worker_class is set" unless $self->worker_class();
    @Distributed::Process::MasterWorker::ISA = ($self->worker_class());
    my $package = $self->worker_class() . '::';
    no strict 'refs';
    foreach my $name ( keys %$package ) {
	local *symbol = eval "*$package$name";
	if ( $name =~ /^__/ && defined &symbol ) {
	    DEBUG "creating function $name in Distributed::Process::MasterWorker";
	    *{"Distributed::Process::MasterWorker::" . $name} = sub {
		my $s = shift;
		DEBUG $name;
		$_->$name(@_) foreach $s->master()->workers();
	    };
	}
    }
    $self->{_master_worker} = Distributed::Process::MasterWorker::->new(-master => $self);
    return $self->{_master_worker};
}

sub synchro_received {

    my $self = shift;
    $self->master_worker()->synchro_received(@_);
}

sub result_received {

    my $self = shift;
    DEBUG "received results from @_";
    $self->master_worker()->result_received(@_);
}

sub run {

    my $self = shift;
    return if @{$self->{_workers}} < $self->n_workers();
    my $master_worker = $self->master_worker();
    DEBUG 'spawning a thread';
    my $thread = async {
	DEBUG 'Spawning the workers';
	$master_worker->run();
	DEBUG 'fetching the results';
	my @result = $master_worker->result();
	DEBUG 'sending the results';
	$self->send(@result, 'ok');
	DEBUG 'Work done';
    };
    $thread->detach();
    DEBUG 'thread spawned';
}

sub worker_class {

    my $self = shift;
    my $old = $self->{_worker_class};
    if ( @_ ) {
	$self->{_worker_class} = $_[0];
	$_[0]->go_remote();
    }
    return $old;
}

sub worker_args {

    my $self = shift;
    my @old = @{$self->{_worker_args} || []};
    if ( @_ ) {
	$self->{_worker_args} = ref($_[0]) eq 'ARRAY' ? $_[0] : [ @_ ]
    }
    return @old;
}

foreach my $method ( qw/ n_workers frequency / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

1;
