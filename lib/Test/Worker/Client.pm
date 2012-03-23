package Test::Worker::Client;
use strict;
use warnings;
our $VERSION = '1.0';
use base qw(Class::Data::Inheritable Class::Accessor::Fast);
use Test::Worker::Client::Job;
use Test::MoreMore::Mock;
use Carp;
use Data::Dumper;
use Path::Class;
use File::Temp qw(tempdir);
use UNIVERSAL::require;

our $DEBUG ||= $ENV{WORKER_CLIENT_DEBUG};

sub _percent_encode_c ($) {
    my $s = shift;
    $s =~ s/([^0-9A-Za-z._~-])/sprintf '%%%02X', ord $1/ge;
    return $s;
} # percent_encode_c

sub new {
    my $class = shift;
    if (ref $_[0] eq 'HASH') {
        return $class->SUPER::new(@_);
    } else {
        return $class->SUPER::new({@_});
    }
}

sub disable_real_worker {
    no warnings 'redefine';

    for my $class (qw(
        WorkerManager::Client::TheSchwartz
        TheSchwartz::Job
    )) {
        my $file = $class;
        $file =~ s[::][/]g;
        $file .= '.pm';
        if ($INC{$file} and $INC{$file} ne '1') {
            die "Module $class ($INC{$file}) has been loaded", Carp::longmess;
        }
        $INC{$file} = 1;
        no strict 'refs';
        *{$class . '::new'} = sub {
            die "An attempt is made to instantiate class $class", Carp::longmess;
        };
        *{$class . '::import'} = sub {
            die "An attempt is made to import class $class", Carp::longmess;
        };
    }

    @Hatena::WorkerClient::ISA = qw(Test::Worker::Client);
    *Hatena::WorkerClient::can_use = sub { 1 };
    $INC{'Hatena/WorkerClient.pm'} = 1;
}

BEGIN {
    __PACKAGE__->disable_real_worker;
}

our $PreserveTempDirectory;

my $t_d = file(__FILE__)->dir->parent->parent->parent->subdir('t');
my $tmp_d = dir(tempdir('Test-Worker-Client-XXXXXXXX', TMPDIR => 1, CLEANUP => not $PreserveTempDirectory));

__PACKAGE__->mk_classdata('root');

__PACKAGE__->root($tmp_d->subdir('worker'));

my $garbage_d = __PACKAGE__->root->subdir('garbage');
our $IgnoreJob;

sub set_test_root_directory {
    my $class = shift;
    $class->root($tmp_d->subdir('worker')->subdir(time . rand));
    warn sprintf "Worker job directory: %s\n", $class->root if $DEBUG;
}

sub get_new_f {
    my ($self, $class, $uniqkey) = @_;

    my $file_name;
    if (defined $uniqkey) {
        $file_name = _percent_encode_c $class;
        $file_name .= '.';
        $file_name .= _percent_encode_c $uniqkey;
    } else {
        $file_name = time . rand;
    }

    my $d = $IgnoreJob ? $garbage_d : $self->root;
    
    my $f = $d->file($file_name . '.txt');
    if (-f $f) {
        warn "DBD::mysql::st execute failed: Duplicate entry '$file_name' for key 2";
        return;
    }

    $d->mkpath;

    return $f;
}

sub insert {
    my ($self, $class, $job, $opts) = @_;
    UNIVERSAL::isa(ref $self, __PACKAGE__) or die;

    my $f = $self->get_new_f($class, $opts->{uniqkey}) or return;
    my $file = $f->openw or die "$0: $f: $!";
    print $file Dumper [$class, $job, $opts];
    if ($DEBUG) {
        warn "====== Test::Worker::Client ======\n";
        warn "Job inserted:\n";
        warn Dumper [$class, $job, $opts];
    }

    return {
        job_id => (int rand 2147483647)
    };
}

sub get_next_job {
    my $self = shift;
    
    my $d = $self->root;
    return undef unless -d $d;
    
    while (my $f = $d->next) {
        if (-f $f) {
            my $obj = do "$f" or die "$0: $f: $@";
            return Test::Worker::Client::Job->new($f, $obj);
        }
    }

    $d = dir($d);
    $self->root($d);
    while (my $f = $d->next) {
        if (-f $f) {
            my $obj = do "$f" or die "$0: $f: $@";
            return Test::Worker::Client::Job->new($f, $obj);
        }
    }

    return undef;
}

sub execute_job {
    my ($self, $job) = @_;

    warn "Job @{[$job->f]}...\n" if $DEBUG;

    my $class = $job->class;
    $class->require or die "$class: $@";

    $class->work($job);
}

sub get_job_after_complete_jobs_unless {
    my ($self, $pattern) = @_;
    {
        my $job = $self->get_next_job or last;
        if ($job->class =~ /$pattern/) {
            return $job;
        }
        $job->completed;
        redo;
    }

    return undef;
}

sub get_sorted_jobs {
    my ($self, $code) = @_;

    die "you need to specify coderef for sort", Carp::longmess if !$code;

    my $jobs = $self->get_all_jobs;

    @$jobs = sort { $code->($a, $b) } @$jobs;

    return $jobs;
}

sub get_all_jobs {
    my ($self) = @_;

    my $d = $self->root;
    return [] unless -d $d;

    my $job_count = scalar $d->children;

    my $jobs = [];
    for (1..$job_count) {
        my $job = $self->get_next_job;
        push @$jobs, $job;
    }

    return $jobs;
}

sub dsn { }

1;
