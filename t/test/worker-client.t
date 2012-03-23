package test::Test::Worker::Client;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->parent->subdir('modules', 'perl-test-moremore', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Worker::Client;
use Carp; local $SIG{__DIE__} = \&Carp::confess;

sub _no_use_worker_client : Test(1) {
    eval q{
        use WorkerManager::Client::TheSchwartz;
        ng 1;
    } or do {
        ok 1;
    };
}

sub _no_use_job : Test(1) {
    eval q{
        use TheSchwartz::Job;
        ng 1;
    } or do {
        ok 1;
    };
}

sub _worker_client : Test(2) {
    Test::Worker::Client->set_test_root_directory;

    Test::Worker::Client->new->insert(
        'test::worker::package',
        {
            arg1 => 'value1',
            arg2 => 'value2',
        },
    );

    my $job = Test::Worker::Client->new->get_next_job;
    is_deeply($job->as_testable_hash, {
        class => 'test::worker::package',
        arg => {
            arg1 => 'value1',
            arg2 => 'value2',
        },
        run_after => undef,
    });
    is $job->failures, 0;
}

sub _worker_client_multiple : Test(1) {
    Test::Worker::Client->set_test_root_directory;

    Test::Worker::Client->new->insert(
        'test::worker::package',
        {
            arg1 => 'value1',
            arg2 => 'value2',
        },
    );
    Test::Worker::Client->new->insert(
        'test::worker::package2',
        {
            arg2 => 'value2',
        },
    );

    my @job;
    while (my $job = Test::Worker::Client->new->get_next_job) {
        push @job, $job->as_testable_hash;
        $job->completed;
    }
    @job = sort { $a->{class} cmp $b->{class} } @job;

    is_deeply \@job, [{
        class => 'test::worker::package',
        arg => {
            arg1 => 'value1',
            arg2 => 'value2',
        },
        run_after => undef,
    }, {
        class => 'test::worker::package2',
        arg => {
            arg2 => 'value2',
        },
        run_after => undef,
    }];
}

sub _run_after : Test(2) {
    Test::Worker::Client->set_test_root_directory;

    Test::Worker::Client->new->insert(
        'test::worker::package',
        {
            arg1 => 'value1',
            arg2 => 'value2',
        },
        {
            run_after => 123,
        },
    );

    my $job = Test::Worker::Client->new->get_next_job;
    is_deeply($job->as_testable_hash, {
        class => 'test::worker::package',
        arg => {
            arg1 => 'value1',
            arg2 => 'value2',
        },
        run_after => 123,
    });
    is $job->failures, 0;
}

sub _uniqkey : Test(5) {
    Test::Worker::Client->set_test_root_directory;

    Test::Worker::Client->new->insert(
        'test::worker::uniqkey',
        {
            key => 1,
        },
        {
            uniqkey => 'abc @1',
        },
    );

    eval {
        Test::Worker::Client->new->insert(
            'test::worker::uniqkey',
            {
                key => 2,
            },
            {
                uniqkey => 'abc @1',
            },
        );
        ok 1;
    } or do {
        ng 1;
    };

    my $job1 = Test::Worker::Client->new->get_next_job;
    is $job1->arg->{key}, 1;
    eq_or_diff $job1->as_testable_hash, {
        class => 'test::worker::uniqkey',
        arg => {
            key => 1,
        },
        run_after => undef,
        uniqkey => 'abc @1',
    };
    $job1->completed;

    my $job2 = Test::Worker::Client->new->get_next_job;
    ng $job2;

    Test::Worker::Client->new->insert(
        'test::worker::uniqkey',
        {
            key => 3,
        },
        {
            uniqkey => 'abc @1',
        },
    );

    Test::Worker::Client->new->insert(
        'test::worker::uniqkey::2',
        {
            key => 4,
        },
        {
            uniqkey => 'abc @1',
        },
    );

    eval {
        Test::Worker::Client->new->insert(
            'test::worker::uniqkey',
            {
                key => 5,
            },
            {
                uniqkey => 'abc @1',
            },
        );
        ok 1;
    } or do {
        ng 1;
    };
}

sub _insert_time : Test(2) {
    Test::Worker::Client->set_test_root_directory;

    Test::Worker::Client->new->insert(
        'test::worker::package',
        {
            arg1 => 'value1',
            arg2 => 'value2',
        },
        {
            run_after => 1000,
            insert_time => 2000,
        },
    );

    my $job = Test::Worker::Client->new->get_next_job;
    is_deeply($job->as_testable_hash, {
        class => 'test::worker::package',
        arg => {
            arg1 => 'value1',
            arg2 => 'value2',
        },
        run_after => 1000,
        insert_time => 2000,
    });
    is $job->failures, 0;
}

sub _worker_client_ignore_job : Test(1) {
    Test::Worker::Client->set_test_root_directory;

    local $Test::Worker::Client::IgnoreJob = 1;
    Test::Worker::Client->new->insert(
        'test::worker::package',
        {
            arg1 => 'value1',
            arg2 => 'value2',
        },
    );

    my $job = Test::Worker::Client->new->get_next_job;
    ng $job;
}

sub _complete_jobs_unless : Test(4) {
    Test::Worker::Client->set_test_root_directory;

    Test::Worker::Client->new->insert('test::worker::class1');
    Test::Worker::Client->new->insert('test::worker::class2');
    Test::Worker::Client->new->insert('test::worker::class3');
    Test::Worker::Client->new->insert('test::worker::class4');

    my $j1 = Test::Worker::Client->new->get_job_after_complete_jobs_unless(qr/class[23]/);
    like $j1->class, qr/^test::worker::class[23]$/;
    $j1->completed;

    my $j2 = Test::Worker::Client->new->get_job_after_complete_jobs_unless(qr/class[23]/);
    like $j2->class, qr/^test::worker::class[23]$/;
    $j2->completed;

    my $j3 = Test::Worker::Client->new->get_job_after_complete_jobs_unless(qr/class[23]/);
    ng $j3;

    my $j4 = Test::Worker::Client->new->get_job_after_complete_jobs_unless(qr/class[23]/);
    ng $j4;
}

sub _get_all_jobs : Test(3) {
    Test::Worker::Client->set_test_root_directory;

    my $wc = Test::Worker::Client->new;
    $wc->insert('test::worker::class',{arg => 1});
    $wc->insert('test::worker::class',{arg => 2});

    my $jobs = $wc->get_all_jobs;
    is @$jobs, 2;
    is $jobs->[0]->class, 'test::worker::class';
    is $jobs->[1]->class, 'test::worker::class';
}

sub _get_all_jobs_no_job : Test(1) {
    Test::Worker::Client->set_test_root_directory;

    my $wc = Test::Worker::Client->new;
    my $jobs = $wc->get_all_jobs;
    is @$jobs, 0;
}

sub _get_sorted_jobs : Test(4) {
    Test::Worker::Client->set_test_root_directory;

    my $wc = Test::Worker::Client->new;
    $wc->insert('test::worker::class',{arg => 1});
    $wc->insert('test::worker::class',{arg => 5});
    $wc->insert('test::worker::class',{arg => 2});

    my $jobs = $wc->get_sorted_jobs(sub {$_[0]->arg->{arg} <=> $_[1]->arg->{arg}});
    is @$jobs, 3;
    is $jobs->[0]->arg->{arg}, 1;
    is $jobs->[1]->arg->{arg}, 2;
    is $jobs->[2]->arg->{arg}, 5;
}

sub _get_sorted_jobs_no_job : Test(1) {
    Test::Worker::Client->set_test_root_directory;

    my $wc = Test::Worker::Client->new;
    my $jobs = $wc->get_sorted_jobs(sub {$_[0]->arg->{arg} <=> $_[1]->arg->{arg}});
    is @$jobs, 0;
}

__PACKAGE__->runtests;

1;
