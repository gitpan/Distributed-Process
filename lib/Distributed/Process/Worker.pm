package Distributed::Process::Worker;

use warnings;
use strict;

use Distributed::Process;
use Distributed::Process::LocalWorker;
our @ISA = qw/ Distributed::Process::LocalWorker /;

sub go_remote {

    my $self = shift;
    require Distributed::Process::RemoteWorker;
    @ISA = qw/ Distributed::Process::RemoteWorker /;
    $self->SUPER::go_remote();
}

1;
