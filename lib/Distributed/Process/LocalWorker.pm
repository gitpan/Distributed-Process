package Distributed::Process::LocalWorker;

use warnings;
use strict;

=head1 NAME

Distributed::Process::LocalWorker - a base class for
Distributed::Process::Worker when running on the client side.

=head1 DESCRIPTION

This class implements the methods declared in C<D::P::BaseWorker> as they
should work on the client side, i.e., they actually do some really work (as
opposed to sending a command on the network, as is the case in its server-side
counterpart C<D::P::RemoteWorker>.

=cut

use POSIX qw/ strftime /;

use Time::HiRes qw/ gettimeofday tv_interval /;

use Distributed::Process;
use Distributed::Process::BaseWorker;
our @ISA = qw/ Distributed::Process::BaseWorker /;

=head2 Methods

=over 4

=item B<time> I<NAME>, I<LIST>

Runs the method I<NAME> with I<LIST> as arguments, while measuring its run
time. Returns whatever the I<NAME> method returns and appends to the result() a
string of the form:

    Time for running NAME: n.nnnnn seconds

=cut

sub time {

    my $self = shift;
    my $method = shift;

    my $t0 = [ gettimeofday ];
    my @result = ($self->$method(@_));
    my $elapsed = tv_interval $t0;
    $self->result(sprintf "Time for running $method: %.5f seconds", $elapsed);
    @result;
}

=item B<reset_result>

Empties the stack of results.

=cut

sub reset_result {

    my $self = shift;
    $self->{_result} = [];
}

=item B<result> I<LIST>

=item B<result>

When called with a non-empty I<LIST> of arguments, pushes I<LIST> onto the
stack of results. These results are meant to be sent back when the server
requests them.

When called without any arguments, returns the list of results.

=cut

sub result {

    my $self = shift;

    if ( @_ ) {
	INFO "adding '@_' to results";
        my $first = shift @_;
        my $time = strftime "%Y%m%d-%H%M%S", localtime;
	push @{$self->{_result}}, "$time\t$first", @_;
	return;
    }
    else {
	INFO "returning results";
	return @{$self->{_result} || []};
    }
}

=back

=head1 SEE ALSO

L<Distributed::Process::BaseWorker>,
L<Distributed::Process::RemoteWorker>,
L<Distributed::Process::Worker>

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

1; # End of Distributed::Process::LocalWorker
