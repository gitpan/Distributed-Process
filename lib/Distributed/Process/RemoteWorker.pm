package Distributed::Process::RemoteWorker;

use warnings;
use strict;

use Distributed::Process;
import Distributed::Process;

use Distributed::Process::Interface;
use Distributed::Process::BaseWorker;
our @ISA = qw/ Distributed::Process::BaseWorker Distributed::Process::Interface /;

sub command_handlers {

    my $self = shift;
    DEBUG;
    return @{$self->{_command_handlers} ||= [
	$self->SUPER::command_handlers(),
	[ qr|/synchro|, sub { my $tok = (split /\s+/, $_[0])[1]; chomp $tok; $self->synchro_received($tok) } ],
	[ qr|/begin_results|, sub { $self->begin_results() }, 'begin_results' ],
    ]};
}

sub out_handle {

    my $self = shift;
    $self->in_handle(@_);
}

sub synchro {

    my $self = shift;
    my $token = shift;

    $self->send("/synchro $token");
}

sub synchro_received {

    my $self = shift;
    my $token = shift;
    $self->master()->synchro_received($self, $token);
}

sub go_remote {

    my $self = shift;
    no strict 'refs';

    my $package = (ref($self) || $self) . '::';
    DEBUG "package $package is going remote";
    foreach my $name ( keys %$package ) {
	local *symbol = eval "*$package$name";
        no warnings 'redefine';
	if ( $name =~ /^__/ && defined &symbol ) {
	    *symbol = sub {
		my $s = shift;
		local $" = " ";
		if ( ref($_[0]) eq 'CODE' ) {
		    my $cref = shift;
		    unshift @_, $cref->($self);
		}
		$s->send("/run $name @_");
	    };
	}
	if ( $name =~ /::$/ ) {
	    # TODO: handle subclasses ?
	}
    }
}

sub reset_result {

    my $self = shift;
    $self->send('/reset_result');
}

sub result {

    my $self = shift;
    DEBUG;
    my @r = @{$self->{_result}};
    DEBUG @r;
    return @r;
}

sub get_result {

    my $self = shift;
    $self->send("/get_result");
}

sub begin_results {

    my $self = shift;

    $self->{_result} = [];
    $self->command_handlers();
    unshift @{$self->{_command_handlers}}, [
	qr/.*/,
	sub { $self->handle_result(@_) },
	'.*',
    ];
    return;
}

sub handle_result {

    my $self = shift;
    DEBUG "Handling result '@_'";
    if ( $_[0] =~ /^ok/ ) {
	DEBUG "Sending results to master";
	shift @{$self->{_command_handlers}};
	$self->master()->result_received($self);
    }
    else {
	DEBUG 'appending result line';
	push @{$self->{_result}}, @_;
    }
    return;
}

sub time {

    my $self = shift;
    local $" = ' ';
    $self->send("/time @_");
}

foreach my $method ( qw/ master / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

1;
1;
