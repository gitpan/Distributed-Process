package Distributed::Process::Interface;

use warnings;
use strict;

=head1 NAME

Distributed::Process::Interface - a base class for handling a network
connection and the commands received from it.

=head1 DESCRIPTION

=cut

use IO::Socket;
use Socket qw/ :crlf /;
use Distributed::Process;
import Distributed::Process;
use Thread::Semaphore;
our @ISA = qw/ Distributed::Process /;

my $CAN_SEND = new Thread::Semaphore;

=head2 Methods

=over 4

=item B<command_handlers>

Returns a list of lists defining patterns against which to try and match a
line, and what to do if a line matches it.

Subclasses may overload this class to enable other commands:

    sub command_handlers {
	my $self = shift;
	my @c = $self->SUPER::command_handlers();
	push @c, [ qr/regex/, sub { 'what to do with line' . $_[0] }, 'test' ];
	push @c, [ qr/^another/i, sub { $self->do_something(@_) }, 'another test' ];
    }

The first item in each array ref is a regular expression, against which the
lines coming in through the input stream will be matched. When a match is
found, the second item is used.

If the second item is a string, it is sent back, i.e., printed to the output
stream. If is a coderef, that coderef is executed, passing it the incoming
line. The list of values returned by the coderef are sent to the output stream.

The third item is optional and will be used in debugging messages to identify
which regular expression is being used.

=cut

sub command_handlers {

    my $self = shift;
    DEBUG;
    return (
	[ qr|/ping|, 'pong' ],
    );
}

=item B<handle_line> I<LIST>

Compares a line with the patterns returned by command_handlers() and, if the
pattern matches, run the corresponding callback or returns the corresponding
string. Once a pattern has matched, handle_line() returns and the remaining
patterns are not checked.

The callbacks are invoked with the full I<LIST> of arguments to handle_line(),
although only the first argument is matched against the regular expression.

Returns C<undef> if no pattern could match.

=cut

sub handle_line {

    my $self = shift;

    my @response;
    DEBUG "handling line '@_'";
    foreach ( $self->command_handlers() ) {
	next unless $_[0] =~ /$$_[0]/;
	DEBUG "  $$_[2] matched" if $$_[2];
	if ( ref($$_[1]) eq 'CODE' ) {
	    @response = ($$_[1]->(@_));
	}
	else {
	    @response = ($$_[1]);
	}
	last;
    }
    @response = () if @response == 1 && !defined($response[0]);
    @response;
}

sub handle {
    goto &in_handle;
}

=item B<send> I<LIST>

Prints each string in I<LIST> with a CR+LF sequence to the output stream.

=cut

sub send {

    my $self = shift;
    my $fh = $self->out_handle();
    foreach ( @_ ) {
    $CAN_SEND->down();
	DEBUG "sending: $_";
	print $fh $_ . CRLF;
	select undef, undef, undef, 0.05;
    $CAN_SEND->up();
    }
    #$self->out_handle()->flush();
}

=back

=head2 Attributes

=over 4

=item B<server>

The C<P::D::Server> under which the Interface is running.

=item B<handle>

=item B<in_handle>

The C<IO::Handle> object that represents the input stream.

=item B<out_handle>

The C<IO::Handle> object that represents the output stream.

=back

=cut

foreach my $method ( qw/ server in_handle out_handle / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

=head1 SEE ALSO

L<Distributed::Process::Server>,
L<Distributed::Process::Client>,
L<Distributed::Process::Master>,
L<Distributed::Process::RemoteWorker>

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

1; # End of Distributed::Process::Interface
