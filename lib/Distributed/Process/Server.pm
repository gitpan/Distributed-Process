package Distributed::Process::Server;

use warnings;
use strict;

=head1 NAME

Distributed::Process::Server - a class to run the server of a Distributed::Process
cluster.

=cut

use Socket qw/ :crlf /;
use IO::Socket;
use IO::Select;

use Distributed::Process;
our @ISA = qw/ Distributed::Process /;

use Distributed::Process::Worker;

=head1 SYNOPSIS

    use Distributed::Process;
    use Distributed::Process::Master;
    use Distributed::Process::Server;
    use MyTest;

    $m = new Distributed::Process::Master ... ;
    $s = new Distributed::Process::Server -master => $m, -port => 8147;

    $s->listen();

=head1 DESCRIPTION

This class handles the server part of the cluster.

It maintains an internal list of Interface objects, one of which is the Master.
The Master object must be instanciated and declared with the Server before the
listen() method is invoked.

The listen() method will welcome incoming connections and declare them with the
Master as new Workers. Commands received on theses sockets will be handled by
the handle_line() method of the corresponding Interface, be it a Worker or the
Master.

=head2 Methods

=over 4

=cut

sub _add_interface {

    my ($self, $interface) = @_;
    $self->_select($interface->handle());

    $self->{_interfaces}{$interface->handle()} = $interface;
}

sub _deselect {

    my $self = shift;
    $self->{_select}->remove(@_);
}

sub _find_interface {

    my ($self, $handle) = @_;
    return $self->{_interfaces}{$handle} if exists $self->{_interfaces}{$handle};
}

sub _interfaces {

    my $self = shift;
    return values %{$self->{_interfaces}};
}

=item B<listen>

Starts listening on port(), waiting for incoming connections. If a new
connection is made, it is supposed to be from a Worker, and the handle is thus
passed on to the Master, by means of its add_worker() method.

If a line is read from an already open handle, it is passed to the
handle_line() method of its corresponding interface.

=cut

sub listen {

    my $self = shift;

    my $lsn = new IO::Socket::INET ReuseAddr => 1, Listen => 1, LocalPort => $self->port();
    #$lsn->autoflush(1);
    die $! unless $lsn;
    $self->_select($lsn);

    while ( my @ready = $self->_select()->can_read() ) {
	DEBUG 'waiting for connections';
	foreach my $fh ( @ready ) {
	    DEBUG "$fh is ready";
	    if ( $fh == $lsn ) {
		DEBUG 'new connection';
		my $new_fh = $lsn->accept();
		#$new_fh->autoflush(1);
		my $worker = $self->master()->add_worker(-server => $self, -handle => $new_fh);
		$self->_add_interface($worker);
		next;
	    }
	    else {
		my $interface = $self->_find_interface($fh);
		my $line = <$fh>;
		local $/ = CRLF;
		chomp $line;
		DEBUG "handling line '$line' via interface '$interface'";
		my @response = $interface->handle_line($line);
		$interface->send(@response) if @response;
	    }
	}
    }
}

=item B<master> I<MASTER>

=item B<master>

Sets or returns the current Distributed::Process::Master object for this server,
and adds it to the list of interfaces.

=cut
sub master {

    my $self = shift;
    my $old = $self->{_master};

    if ( @_ ) {
	my $master = $_[0];
	$self->{_master} = $master;
	$master->server($self);
	$self->_add_interface($master);
    }
    return $old;
}

=item B<quit>

Sends a C</quit> command to all interfaces and exits the program.

=cut

sub quit {

    my $self = shift;

    foreach ( $self->_interfaces() ) {
	$_->send('/quit') if $_->isa('Distributed::Process::RemoteWorker');
    }
    exit 0;
}

sub _remove_interface {

    my ($self, $interface) = @_;
    $self->_deselect($interface->handle());
    delete $self->{_interfaces}{$interface->handle()};
}

sub _select {

    my $self = shift;
    $self->{_select} ||= new IO::Select;

    $self->{_select}->add(@_) if @_;
    $self->{_select};
}

=back

=head2 Attributes

=over 4

=item B<port>

The port on which the server listens to incoming connections.

=cut

foreach my $method ( qw/ port / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

=back

=head1 SEE ALSO

L<Distributed::Process::Interface>,
L<Distributed::Process::Master>,

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

1; # End of Distributed::Process::Server
