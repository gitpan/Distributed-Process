package Distributed::Process;

use warnings;
use strict;

=head1 NAME

Distributed::Process - a framework for running a process simultaneously on several
machines.

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';

=head1 SYNOPSIS

First, write a subclass of Distributed::Process::Worker that will implement the
tasks to be run remotely in its run() method.

    package MyWorker;
    use Distributed::Process;
    use Distributed::Process::Worker;

    sub __task {
	my $self = shift;
	# do something
	$self->result('report on what happened');
    }

    sub run {
	my $self = shift;
	$self->__task();
    }

All methods whose names start with a double underscore will be run on the
remote machines (the clients).

Write a small server that uses this C<MyWorker> class.

    # Server
    use Distributed::Process;
    use Distributed::Process::Server;
    use Distributed::Process::Master;
    use MyWorker;

    $master = new Distributed::Process::Master -worker_class => 'MyWorker',
	-in_handle => \*STDIN, -out_handle => \*STDOUT,
	-n_workers => 2;
    $server = new Distributed::Process::Server -port => 8147, -master => $master;

    $server->listen();

Write a small client as well and install it on all the client machines:

    # Client
    use Distributed::Process;
    use Distributed::Process::Client;
    use MyWorker;

    $client = new Distributed::Process::Client -worker_class => 'MyWorker',
	-host => 'the-server', -port => 8147;
    $client->run();

=head1 DESCRIPTION

This modules distribution provides a framework to run tasks simultaneously on
several computers, while centrally keeping control from another machine.

=head2 Architecture Overview

The tasks to run are implemented in a "worker" class, that derives from
C<D::P::Worker>; let's call it C<MyWorker>. The subclass must overload the
run() method, but not to perform the tasks directly, only to give the
"schedule" of the sub-tasks to run. The sub-tasks themselves will be
implemented in other methods, whose names start with a double underscore,
and called from within the run() method.

=head3 Server Side

On the server side, a C<D::P::Server> object will handle the network
connections, i.e. sockets or handles. Each handle is associated with a
C<D::P::Interface> object. This object can be either be a C<D::P::Master>, or a
C<D::P::RemoteWorker>.

Instead of being bound to a network socket, the C<D::P::Master> object is
typically bound to the standard input and output, and can thus receive orders
from the user and give feedback on the terminal. It maintains a list of
C<D::P::RemoteWorker> objects, one for each network connection, and it also
maintains one C<D::P::MasterWorker>.

The C<D::P::RemoteWorker> objects are in fact instances of the C<MyWorker>
class, but with its inheritance changed so that it now derives from
C<D::P::RemoteWorker>.  Basically, invoking one of their methods that start
with a double underscore will in fact send a command on the network socket,
instead of running the real method.

The C<D::P::MasterWorker> is a subclass of the custom C<MyWorker>. It overrides
its double-underscore methods so that they call the method by the same name on
all connected C<D::P::RemoteWorker> objects, effectively resulting in
broadcasting the command.

When the C<D::P::Master> receives the C</run> command (on standard input), it
invokes the run() method of its C<D::P::MasterWorker> object. This method is
the same as the run() method of C<MyWorker>, except that any call to a
__method() will result in a command being broadcasted to the connected
C<D::P::RemoteWorker> objects.

After the run() is over, the C<D::P::MasterWorker> broadcasts the
C</get_result> command and gathers the results from all C<D::P::Worker>
objects. And the C<D::P::Master> prints out the results.

=head3 Client Side

On the client side, a C<D::P::Client> object manages to connection to the
server and instanciates the C<MyWorker> class, derived from C<D::P::Worker>.

When the client receives a command from the server, it executes it, i.e., it
invokes the requested method on its C<MyWorker> object, and keeps the
results in memory. The results will be sent later back to the server, when
receiving the C</get_result> command.

=cut

use threads;
use Thread::Semaphore;
my $CAN_PRINT = new Thread::Semaphore;

our $DEBUG_FLAG;

use Exporter;
our @ISA = qw/ Exporter /;

our @EXPORT = qw/ DEBUG /;

=head2 Constructor

=over 4

=item B<new> I<LIST>

Although this class is not supposed to be instanciated, it provides a
constructor for its subclasses to inherit from. This constructor takes a
I<LIST> of named arguments. The names will be converted to lowercase and
stripped off from their leading hyphens, if any. The constructor then calls the
method by the same name with the value as argument. These calls are the same:

    $obj = new Distributed::Process  method => $value;
    $obj = new Distributed::Process -method => $value;
    $obj = new Distributed::Process -METHOD => $value;

    $obj = new Distributed::Process;
    $obj->method($value);

=cut
sub new {

    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $self = bless {}, $class;
    while ( @_ ) {
	my ($attr, $value) = (lc shift, shift);
	$attr =~ s/^-+//;
	$self->$attr($value);
    }
    return $self;
}

=back

=head2 Exports

This module exports the DEBUG() function that is a no op by default. If you
import the C<:debug> special tag, the DEBUG() function is turned into one that
prints its arguments to standard error.

You need importing C<:debug> only once for this to take effect. For exemple the
main program can say:

    use Distributed::Process qw/ :debug /;

While all the other modules just say:

    use Distributed::Process;

Still, the C<DEBUG> will become active everywhere.

=head2 Functions

=over 4

=item B<DEBUG> I<LIST>

By default, this function does nothing. However, if at some point the C<:debug>
tag was imported, DEBUG() will print its arguments to standard error, prepended
with the Process ID, the fully qualified name of its caller, and the thread id,
e.g.:

    3147:Package::function(1): message

=cut
sub DEBUG;
sub _DEBUG_ON {
    my $sub = (caller(1))[3];
    my $tid = threads->self()->tid();
    $CAN_PRINT->down();
    print STDERR "$$:$sub($tid): @_\n";
    $CAN_PRINT->up();
}
sub _DEBUG_OFF { }
sub import {
    my $package = shift;
    my %arg = map { $_ => 1 } @_;
    if ( delete $arg{':debug'} ) {
	$DEBUG_FLAG = 1;
    }
    *DEBUG = $DEBUG_FLAG ? *_DEBUG_ON : *_DEBUG_OFF;
    @_ = ($package, keys %arg);
    goto &Exporter::import;
}

=back

=head1 AUTHOR

Cédric Bouvier, C<< <cbouvi@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-distributed-process@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.  I will be notified, and then you'll automatically
be notified of progress on your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright 2005 Cédric Bouvier, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Distributed::Process
