package Distributed::Process::LocalWorker;

use warnings;
use strict;

use POSIX qw/ strftime /;

use Time::HiRes qw/ gettimeofday tv_interval /;

use Distributed::Process;
use Distributed::Process::BaseWorker;
our @ISA = qw/ Distributed::Process::BaseWorker /;

sub time {

    my $self = shift;
    my $method = shift;

    my $t0 = [ gettimeofday ];
    my @result = ($self->$method(@_));
    my $elapsed = tv_interval $t0;
    $self->result("Time for running $method: $elapsed seconds");
    @result;
}

sub result {

    my $self = shift;

    DEBUG __PACKAGE__ . "::result(@_)";
    if ( @_ ) {
	DEBUG "adding '@_' to results";
        my $first = shift @_;
        my $time = strftime "%Y%m%d-%H%M%S", localtime;
	push @{$self->{_result}}, "$time\t$first", @_;
	return;
    }
    else {
	DEBUG "returning results";
	return @{$self->{_result} || []};
    }
}

1;