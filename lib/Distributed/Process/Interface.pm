package Distributed::Process::Interface;

use warnings;
use strict;

use IO::Socket;
use Socket qw/ :crlf /;
use Distributed::Process;
import Distributed::Process;
use Thread::Semaphore;
our @ISA = qw/ Distributed::Process /;

my $CAN_SEND = new Thread::Semaphore;

sub command_handlers {

    my $self = shift;
    DEBUG;
    return (
	[ qr|/ping|, 'pong' ],
    );
}

sub handle_line {

    my $self = shift;

    my @response;
    DEBUG "handling line '@_'";
    foreach ( $self->command_handlers() ) {
	DEBUG "Testing against $$_[2]" if $$_[2];
	next unless $_[0] =~ /$$_[0]/;
	DEBUG "  $$_[2] matched" if $$_[2];
	if ( ref($$_[1]) eq 'CODE' ) {
	    DEBUG "found a callback $$_[1]";
	    @response = ($$_[1]->(@_));
	}
	else {
	    @response = ($$_[1]);
	}
	last;
    }
    @response = () if @response == 1 && !defined($response[0]);
    DEBUG 'line handled';
    @response;
}

sub close {

    my $self = shift;
    DEBUG 'closing interface';
    $self->server()->remove_interface($self);
    $self->out_handle()->close() if $self->in_handle() != $self->out_handle();
    $self->in_handle()->close();
}

sub handle {
    goto &in_handle;
}

#sub send {
#
#    my $self = shift;
#    my $pid = fork;
#    die "Cannot fork: $!" unless defined $pid;
#
#    return 1 if $pid;
#    my $h = $self->out_handle();
#    foreach ( @_ ) {
#	DEBUG "sending: $_";
#	print $h "$_\n";
#    }
#    exit 0;
#}

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

foreach my $method ( qw/ server in_handle out_handle / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

1;
