package Distributed::Process::Client;

use warnings;
use strict;

use Carp;
use IO::Socket;
use Distributed::Process;
use Distributed::Process::Interface;
our @ISA = qw/ Distributed::Process::Interface /;

sub command_handlers {

    my $self = shift;
    return (
	$self->SUPER::command_handlers(),
	[ qr|^/run|, sub { shift; my $cmd = shift; $self->worker()->$cmd(@_) } ],
	[ qr|^/time|, sub { shift; $self->worker()->time(@_) } ],
	[ qr|^/synchro|, sub { sleep 1; join ' ', @_ } ],
	[ qr|^/quit|, sub { exit 0; }, '/quit' ],
	[ qr|^/get_result|, sub {
            sleep 1;
            my $id = $self->id() || $$;
            return('/begin_results', (map "$id\t$_", $self->worker()->result()), 'ok');
        } ],
    );
}

sub connect {

    my $self = shift;
    DEBUG 'connecting';
    my $h = $self->handle();
    while ( <$h> ) {
	chomp;
	my @response = $self->handle_line(split /\s+/);
	@response = ('ok') unless @response;
	$self->send($_) for @response;
    }
}

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

sub run {

    my $self = shift;
    $self->connect();
}

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

sub worker_args {

    my $self = shift;
    my @old = @{$self->{_worker_args} || []};
    if ( @_ ) {
	$self->{_worker_args} = ref($_[0]) eq 'ARRAY' ? $_[0] : [ @_ ]
    }
    return @old;
}

foreach my $method ( qw/ id worker_class host port / ) {
    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

1;
