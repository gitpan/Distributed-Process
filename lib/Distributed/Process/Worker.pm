package Distributed::Process::Worker;

use warnings;
use strict;

use Distributed::Process;
use Distributed::Process::LocalWorker;
our @ISA = qw/ Distributed::Process::LocalWorker /;

sub ancestors {

    my ($self, $seen) = @_;
    my $class = ref($self) || $self;
    $seen ||= {};

    no strict 'refs';
    my @isa = ();
    foreach ( @{$class . "::ISA"} ) {
	next if $seen->{$_};
	$seen->{$_} = 1;
	push @isa, $_, ancestors($_, $seen);
    }
    return @isa;
}

sub go_remote {

    my $self = shift;
    require Distributed::Process::RemoteWorker;
    @ISA = qw/ Distributed::Process::RemoteWorker /;
    $self->SUPER::go_remote();
}

1;
