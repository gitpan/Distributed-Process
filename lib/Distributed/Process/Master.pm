package Distributed::Process::Master;

use warnings;
use strict;

=head1 NAME

Distributed::Process::Master - a class to conduct the chorus of D::P::Workers,
under a D::P::Server.

=head1 SYNOPSIS

    use Distributed::Process::Master;
    use Distributed::Process::Server;

    use MyWorker; # subclass of Distributed::Process::Worker

    $m = new Distributed::Process::Master
	-in_handle    => \*STDIN,
	-out_handle   => \*STDOUT,
	-worker_class => 'MyWorker',
    ;
    $s = new Distributed::Process::Server
	-master => $m,
	-port   => 8147,
    ;
    $s->listen();

=head1 DESCRIPTION

A C<D::P::Server> manages a number of C<D::P::Interface> objects, one of which
is a C<Distributed::Process::Master>. The role of the Master is to handle
requests from the user, coming in on its in_handle() (usually, the standard
input), and act as an interface between the C<D::P::MasterWorker> and the
C<D::P::Worker> objects.

=cut

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

=head2 Commands

A C<D::P::Master> object will react on the following commands received on its in_handle():

=over 4

=item B</run>

Invokes the run() method (see below).

=item B</reset>

Invokes the reset_result() method on the MasterWorker object.

=item B</freq> I<NUMBER>

Sets the frequency() to a new value

=item B</quit>

Invokes the quit() method on the C<P::D::Server>, effectively shutting down the
server and the clients.

=back

=cut

sub command_handlers {

    my $self = shift;
    return (
	$self->SUPER::command_handlers(),
	[ qr|^/run|,  sub { $self->run() } ],
	[ qr|^/reset|, sub { $self->master_worker()->reset_result() } ],
	[ qr|^/freq|, sub { local $_ = (split ' ', $_[0])[1]; tr/0-9.//cd; $self->frequency($_) } ],
	[ qr|^/quit|, sub { $self->server()->quit() } ],
    );
}

=head2 Methods

=over 4

=item B<add_worker> I<WORKER>

=item B<add_worker> I<LIST>

Adds a Worker to the list of known workers. If the first argument is a
C<D::P::Worker>, use this as the new worker. Otherwise, create a new instance
of class worker_class(), passing I<LIST> as arguments to the constructor.

In any case, the new worker will be passed the parameters defined by
worker_args().

Returns the new worker object.

=cut

sub add_worker {

    my $self = shift;
    my $worker = shift;
    DEBUG 'Adding a worker';
    if (!ref($worker) || !$worker->isa('Distributed::Process::Worker') ) {
	my $class = $self->worker_class();
	$worker = $class->new(-master => $self, $worker, @_);
    }
    else {
	$worker->master($self);
    }
    my %attr = $self->worker_args();
    while ( my ($meth, $value) = each %attr ) {
	$worker->$meth($value);
    }
    push @{$self->{_workers}}, $worker;
    DEBUG 'new worker arrived';
    $self->send('new worker arrived');
    $self->send('ready to run') if $self->n_workers() <= $self->workers();
    return $worker;
}

=item B<remove_worker> I<WORKER>

Removes a I<WORKER> from the list of known C<P::D::Worker> objects. Returns the
worker object, or C<undef> if the worker was not part of the known workers.

=cut

sub remove_worker {

    my ($self, $worker) = @_;
    my $i;
    for ( $i = 0; $i < @{$self->{_workers}}; $i++ ) {
	last if $self->{_workers}[$i] eq $worker;
    }
    return if $i >= @{$self->{_workers}};

    my $removed = splice @{$self->{_workers}}, $i, 1;
    DEBUG 'worker departed, ' . ($self->workers() || 'none') . 'left';
    return $removed;
}

=item B<workers>

Returns the list of known C<P::D::Worker> objects. In scalar context, returns their number.

=cut

sub workers {

    my $self = shift;
    wantarray ? @{$self->{_workers}} : scalar @{$self->{_workers}};
}

=item B<master_worker>

Returns the C<P::D::MasterWorker> object. 

The first time this method gets called, the C<P::D::MasterWorker> class is
built as a subclass of the worker_class() and all its double-underscore methods
are overloaded, so that invoking such a __method() on the MasterWorker will
result in invoking the same method on all the known workers().

=cut

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
    $self->{_master_worker} = Distributed::Process::MasterWorker::->new(-master => $self, $self->worker_args());
    return $self->{_master_worker};
}

=item B<synchro_received> I<LIST>

=item B<result_received> I<LIST>

These methods simply invoke the methods by the same name on the
C<D::P::MasterWorker>. They are called by a C<D::P::Worker> that receives some
signal and must notify the MasterWorker, but can only do so through the Master
itself.

=cut

sub synchro_received {

    my $self = shift;
    $self->master_worker()->synchro_received(@_);
}

sub result_received {

    my $self = shift;
    DEBUG "received results from @_";
    $self->master_worker()->result_received(@_);
}

=item B<run>

Spawns a thread to run the work session. The thread will invoke the run()
method on the master_worker() object, get its result(), and print the results
to the out_handle().

=cut

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

=item B<worker_class> C<NAME>

=item B<worker_class>

Returns or sets the class to use when instanciating C<P::D::Worker> objects to
handle incoming connections.

When setting the worker_class(), this method will call the go_remote() method
on it to alter its inheritance, and make it a subclass of
C<Distributed::Process::RemoteWorker>.

=cut

sub worker_class {

    my $self = shift;
    my $old = $self->{_worker_class};
    if ( @_ ) {
	$self->{_worker_class} = $_[0];
	$_[0]->go_remote();
    }
    return $old;
}

=item B<worker_args> I<LIST>

=item B<worker_args> I<ARRAYREF>

=item B<worker_args>

The list of arguments to pass to the worker_class() constructor. If the first
argument is an array ref, it will be dereferenced.

Returns the former list of arguments or the current list when invoked without
arguments.

=cut

sub worker_args {

    my $self = shift;
    my @old = @{$self->{_worker_args} || []};
    if ( @_ ) {
	$self->{_worker_args} = ref($_[0]) eq 'ARRAY' ? $_[0] : [ @_ ]
    }
    return @old;
}

=back

=head2 Attributes

=over 4

=item B<n_workers>

The number of C<P::D::Worker> that are expected to connect on the server. When
enough connections are established, the Master will print a "ready to run"
message to warn the user.

=item B<frequency>

The frequency at which a method run by postpone() should be invoked, in Hz.

Suppose you want all the workers to run their __method() 0.25 seconds after one
another. You'd write your Worker run() method like this:

    sub run {
	my $self = shift;
	$self->postpone(__method => 'arguments to __method);
    }

You'd then set the Master's frequency() to 4, to have it launch 4 calls per
second, or 1 call every 0.25 second.

See L<Distributed::Process::Worker> for details.

=back

=cut

foreach my $method ( qw/ n_workers frequency / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

=head1 AUTHOR

Cédric Bouvier, C<< <cbouvi@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-distributed-process@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2005 Cédric Bouvier, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Distributed::Process::Master
