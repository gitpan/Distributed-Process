package Distributed::Process::Client;

use warnings;
use strict;

=head1 NAME

Distributed::Process::Client - a class to run a client in a Distributed::Process cluster.

=cut

use Carp;
use IO::Socket;
use Distributed::Process;
use Distributed::Process::Interface;
our @ISA = qw/ Distributed::Process::Interface /;

=head1 SYNOPSIS

    use Distributed::Process;
    use Distributed::Process::Client;
    use MyTest;

    $c = new Distributed::Process::Client
	-worker_class => 'MyTest',
	-port         => 8147,
	-host         => 'localhost',
    ;
    $c->run();

=head1 DESCRIPTION

This class handles the client part of the cluster. It derives its handling of
the network connection from C<Distributed::Process::Interface>, simply
overloading command_handlers() to handle more commands.

A C<D::P::Worker> object must be associated to the Client, by means of the
worker() or worker_class() methods, so that the client can run methods from it
when requested to do so by the server.

=head2 Commands

A C<D::P::Client> object will react on the following commands received on its
in_handle(). They are implemented as callbacks returned by the
command_handlers() method (see L<Distributed::Process::Interface>). The
callbacks are given the full command as a list of words, i.e., the original
command string is splitted on whitespace.

=over 4

=item B</run> I<NAME>, I<LIST>

Calls the worker's method called I<NAME> with I<LIST> as arguments.

=item B</run_with_return> I<NAME>, I<LIST>

Same as C</run> but sends the return values from method I<NAME> back to the
server. The list of return values are sent one by line, preceded by
C</begin_return> and followed by C</end_return>.

=item B</reset>

Calls the worker's reset_result() method to flush its list of results.

=item B</time> I<NAME>, I<LIST>

Calls the worker's time() method, resulting in calling the worker's method
called I<NAME> with I<LIST> as arguments while measuring its run time. The time
is appended to the result() (see L<Distributed::Process::BaseWorker>).

=item B</synchro> I<TOKEN>

Returns the same line as the one received (i.e., C</run TOKEN>) after a small
delay. The delay seems necessary to avoid the server receiving replies to a
C</synchro> message before it starts expecting them.

=item B</quit>

Exits the program.

=item B</get_result>

Returns the results from the worker. The results are preceded with the line
C</begin_results> and followed by the word C<ok>. Each result line gets
prefixed with the client's id() and a tab character (0x09).

The worker itself returns its result line prefixed with a timestamp. An example
of output could thus be (for a method invoked under C</time>):

    /begin_results
    client1	20050316-152519	Running method __test1
    client1	20050316-152522	Time for running __test1: 2.1234 seconds
    ok

=back

=cut
sub command_handlers {

    my $self = shift;
    return (
	$self->SUPER::command_handlers(),
	[ qr|^/run_with_return|, sub { shift; my $cmd = shift; return('/begin_return', $self->worker()->$cmd(@_), '/end_return') } ],
	[ qr|^/run|, sub { shift; my $cmd = shift; $self->worker()->$cmd(@_) } ],
	[ qr|^/reset|, sub { $self->worker()->reset_result() } ],
	[ qr|^/time|, sub { shift; $self->worker()->time(@_) } ],
	[ qr|^/synchro|, sub { sleep 1; join ' ', @_ } ],
	[ qr|^/quit|, sub { exit 0; }, '/quit' ],
	[ qr|^/get_result|, sub {
            sleep 1;
            my $id = $self->id();
            return('/begin_results', (map "$id\t$_", $self->worker()->result()), 'ok');
        } ],
    );
}

=head2 Methods

=over 4

=cut

=item B<run>

Reads line coming in from handle() and processes them using the handle_line()
method inherited from C<D::P::Interface>.

Each line is first C<chomp>ed and C<split> on whitespace. The words are sent as
a list to handle_line(). When a regular expression from the list returned by
command_handlers() matches the first word, the corresponding callback is
invoked with the full list of words as arguments.

The callbacks are expected to return a list of strings, which will be
immediately sent back to the server. If they return an empty list, the single
line "ok" is sent instead.

Normally, callbacks should return an empty list and store their results using
the result() method, which makes it possible for the server to retrieve the
results later, when the work is done.

=cut

sub run {

    my $self = shift;
    DEBUG 'connecting';
    my $h = $self->handle();
    $self->send("/worker " . $self->id());
    while ( <$h> ) {
	chomp;
	my @response = $self->handle_line(split /\s+/);
	@response = ('ok') unless @response;
	$self->send($_) for @response;
    }
}

=item B<handle>

=item B<in_handle>

=item B<out_handle>

These three are synonyms for the handle() method that returns the
C<IO::Socket::INET> object implementing the connection to the server.

The first call to handle() creates this object, effectively establishing the
connection to port port() on host host().

=cut

sub handle {

    my $self = shift;

    return $self->{_handle} if $self->{_handle};
    $self->{_handle} = new IO::Socket::INET
	PeerAddr => $self->host(),
	PeerPort => $self->port(),
	Proto    => 'tcp',
	    or croak "Cannot connect to server: $!";
    $self->{_handle};
}

*in_handle = *out_handle = *handle;

=item B<worker> I<OBJECT>

=item B<worker>

Sets or returns the current worker object. I<OBJECT> should be an instance of
C<Distributed::Process::Worker> or, most probably, of a subclass of it. If
I<OBJECT> is not provided, the fist call to worker() will instanciate an object
of the class returned by worker_class(), passing to its constructor the
arguments returned by worker_args().

=cut

sub worker {
    
    my $self = shift;

    if ( @_ ) {
	$self->{_worker} = $_[0];
    }
    else {
	$self->{_worker} ||= do {
	    my $class = $self->worker_class();
	    $class->new($self->worker_args());
	};
    }
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

The following list describes the attributes of this class. They must only be
accessed through their accessors.  When called with an argument, the accessor
methods set their attribute's value to that argument and return its former
value. When called without arguments, they return the current value.

=over 4

=item B<id>

A unique identifier for the client. This will be prepended to the lines sent
back to the server as a response to the C</get_result> command. The process id
(C<$$>) is returned if id() is not set.

=item B<worker_class>

The name of the class to use when instanciating a C<D::P::Worker> object.

=item B<host>

=item B<port>

The host and port where to connect to the server.

=back

=cut

sub id {

    my $self = shift;
    my $old = defined($self->{_id}) ? $self->{_id} : $$;
    $self->{_id} = $_[0] if @_;
    return $old;
}

foreach my $method ( qw/ worker_class host port / ) {
    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

=head1 SEE ALSO

L<Distributed::Process::Interface>,
L<Distributed::Process::Worker>,

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

1; # End of Distributed::Process::Client
