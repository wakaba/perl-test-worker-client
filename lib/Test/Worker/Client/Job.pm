package Test::Worker::Client::Job;
use strict;
use warnings;
our $VERSION = '1.0';
use base qw(Test::MoreMore::Mock);

__PACKAGE__->mk_accessors(qw(
    class f arg is_completed failures run_after uniqkey priority insert_time
));

sub new {
    my ($class, $f, $obj) = @_;
    my $self = bless {
        f => $f,
        class => $obj->[0],
        arg => $obj->[1],
        run_after => $obj->[2]->{run_after},
        uniqkey => $obj->[2]->{uniqkey},
        priority => $obj->[2]->{priority},
        failures => 0,
        insert_time => $obj->[2]->{insert_time},
    }, $class;
    defined $obj->[2]->{$_} || delete $self->{$_} for qw(uniqkey priority insert_time);
    return $self;
}

sub complete {
    die "Method |complete| is not supported";
}

sub completed {
    my $self = shift;
    warn "Job @{[$self->f]} completed!\n";
    $self->f->remove;
    $self->is_completed(1);
    die "Maybe you don't want to get return value of \$job->completed; use \$job->is_completed instead"
        if defined wantarray;
}

sub as_testable_hash {
    my $self = shift;
    my $obj = {%$self};
    delete $obj->{f};
    delete $obj->{failures};
    delete $obj->{is_completed};
    return $obj;
}

1;
