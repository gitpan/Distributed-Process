package Distributed::Process::RemoteWorker;

use strict;

use Distributed::Process;
import Distributed::Process;

use Thread::Queue;
use Distributed::Process::Interface;
use Distributed::Process::BaseWorker;
our @ISA = qw/ Distributed::Process::BaseWorker Distributed::Process::Interface /;

sub new {

    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->message_queue();

    $self;
}

sub command_handlers {

    my $self = shift;
    return @{$self->{_command_handlers} ||= [
	$self->SUPER::command_handlers(),
	[ qr|^/synchro|, sub { my $tok = (split /\s+/, $_[0])[1]; chomp $tok; $self->synchro_received($tok) } ],
	[ qr|^/begin_return|, sub { $self->begin_return() }, 'begin_return' ],
	[ qr|^/begin_results|, sub { $self->begin_results() }, 'begin_results' ],
        [ qr|^/worker|, sub { $self->id((split /\s+/, $_[0])[1]); $self->master()->worker_ready($self) } ],
    ]};
}

sub out_handle {

    my $self = shift;
    $self->in_handle(@_);
}

sub synchro {

    my $self = shift;
    my $token = shift;

    INFO "synchro $token";
    $self->send("/synchro $token");
    $self->master()->master_worker()->synchro($token);
}

sub synchro_received {

    my $self = shift;
    my $token = shift;
    $self->master()->synchro_received($self, $token);
    return;
}

sub _run_code_in_args {

    my $self = shift;
    my @arg = ();
    foreach ( @_ ) {
	if ( ref($_) eq 'CODE' ) {
	    push @arg, $_->($self);
	}
	else {
	    push @arg, $_;
	}
    }
    @arg;
}

sub message_queue {

    my $self = shift;
    $self->{_message_queue} ||= new Thread::Queue;
}

sub go_remote {

    my $self = shift;
    no strict 'refs';

    foreach my $package ( ref($self) || $self, $self->ancestors() ) {
	next if $package =~ /Distributed::Process/ || $package eq 'Exporter';
	DEBUG "package $package is going remote";
	$package .= '::';
	foreach my $name ( keys %$package ) {
	    local *symbol = eval "*$package$name";
	    no warnings 'redefine';
	    if ( $name =~ /^__/ && defined &symbol ) {
		*symbol = sub {
		    my $s = shift;
		    local $" = " ";
		    my @arg = $s->_run_code_in_args(@_);
		    if ( !defined(wantarray) ) {
			DEBUG "running $name in void context";
			$s->send("/run $name @arg");
			return '';
		    }
		    else {
			DEBUG "running $name in non void context";
			my $q = $s->message_queue();
			$s->send("/run_with_return $name @arg");
			my @res;
			while ( my $v = $q->dequeue() ) {
			    last if $v eq '/end_return';
			    push @res, $v;
			}
			return wantarray ? @res : $res[0];
		    }
		};
	    }
	    if ( $name =~ /::$/ ) {
		# TODO: handle subclasses ?
	    }
	}
    }
}

sub reset_result {

    my $self = shift;
    $self->send('/reset_result');
}

sub result {

    my $self = shift;
    my @r = @{$self->{_result}};
    return @r;
}

sub get_result {

    my $self = shift;
    $self->send("/get_result");
}

sub begin_return {

    my $self = shift;

    $self->command_handlers();
    unshift @{$self->{_command_handlers}}, [
	qr/.*/,
	sub { $self->handle_return(@_) },
	'return_value',
    ];
    return;
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
	INFO "Sending results to master";
	shift @{$self->{_command_handlers}};
	$self->master()->result_received($self);
    }
    else {
	INFO 'appending result line';
	push @{$self->{_result}}, @_;
    }
    return;
}

sub handle_return {

    my $self = shift;
    DEBUG "Handling returned value '@_'";
    $self->message_queue()->enqueue(@_);
    if ( $_[0] =~ m|^/end_return| ) {
	shift @{$self->{_command_handlers}};
    }
    return;
}

sub time {

    my $self = shift;
    local $" = ' ';
    my @arg = $self->_run_code_in_args(@_);
    $self->send("/time @arg");
}

sub is_ready {

    my $self = shift;
    return defined($self->id());
}

sub worker_index {

    my $self = shift;
    $self->master()->worker_index($self);
}
sub postpone {

    my $self = shift;
    my $method = shift;

    select undef, undef, undef, $self->worker_index() * 1 / ($self->master()->frequency() || 1);
    $self->$method(@_);
}

foreach my $method ( qw/ id master / ) {

    no strict 'refs';
    *$method = sub {
	my $self = shift;
	my $old = $self->{"_$method"};
	$self->{"_$method"} = $_[0] if @_;
	return $old;
    };
}

1;
