package Distributed::Process::BaseWorker;

use warnings;
use strict;

=head1 NAME

Distributed::Process::BaseWorker - base class for all workers, both local and
remote

=head1 SYNOPSIS

=cut

use Distributed::Process;
our @ISA = qw/ Distributed::Process /;

=head1 DESCRIPTION

=head2 Methods

None of these methods are actually implemented in this base class. There all
implement in either Distributed::Process::LocalWorker,
Distributed::Process::RemoteWorker or Distributed::Process::MasterWorker.

Methods in Distributed::Process::MasterWorker will invoke the methods by the same
name on all the Distributed::Process::RemoteWorker subscribed with the server.

Methods in Distributed::Process::RemoteWorker will simply send a command to their
connected client, asking it to run the same method locally.

Methods in Distributed::Process::LocalWorker will do the actual job.

=over 4

=item B<synchro> I<TOKEN>

Waits for all the connected clients to reach this synchronisation point.
I<TOKEN> is a message, mostly used to identify which synchronisation point is
being reached when reading the debug output.

=cut

sub synchro {}

=item B<run>

This must must be overloaded in subclasses to actually implement the task that
is to be run remotely. Calls to methods whose name starts with a double
underscore (as in C<__example>) will be run remotely, while all the others will
be run locally.

=cut

sub run {}

=item B<postpone> I<NAME>, I<LIST>

Runs the method I<NAME> with the given I<LIST> of arguments after a short
delay. The delay will change with each Worker in a session, so that the Master
can arrange to have the Workers run their tasks a few moments after one another
instead of running them all at one. See L<Distributed::Process::Master> for
details.

=cut

sub postpone {

    my $self = shift;
    my $method = shift;

    $self->$method(@_);
}

=item B<time> I<NAME>, I<LIST>

Runs the method I<NAME> with the given I<LIST> of arguments and reports the
time it took by means of the result() method.

=cut

sub time {

    my $self = shift;
    my $method = shift;

    $self->$method(@_);
}

=item B<result> I<STRING>

=item B<result>

When called with an argument, adds the I<STRING> to the queue of messages to
send back to the server.

When called without arguments, returns the list of queued messages.

=cut

sub result {}

=back

=head1 SEE ALSO

L<Distributed::Process::LocalWorker>,
L<Distributed::Process::MasterWorker>,
L<Distributed::Process::RemoteWorker>,
L<Distributed::Process::Worker>.

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

1; # End of Distributed::Process::BaseWorker
