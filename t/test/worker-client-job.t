package test::Test::Worker::Client::Job;
use strict;
use warnings;
use Path::Class;
use lib file(__FILE__)->dir->parent->parent->subdir('lib')->stringify;
use lib file(__FILE__)->dir->parent->parent->subdir('modules', 'perl-test-moremore', 'lib')->stringify;
use base qw(Test::Class);
use Test::MoreMore;
use Test::Worker::Client::Job;

sub _priority_specified : Test(1) {
    my $f = file('test');
    my $job = Test::Worker::Client::Job->new($f, [
        'TestJobClass',
        {},
        {priority => 45},
    ]);
    is $job->priority, 45;
}

sub _complete : Test(1) {
    my $f = file('test');
    my $job = Test::Worker::Client::Job->new($f, ['TestJobClass', {}]);
    dies_ok { $job->complete };
}

sub _as_testable_hash : Test(1) {
    my $f = file('test');
    my $job = Test::Worker::Client::Job->new($f, [
        'TestJobClass',
        {a => 1, b => 2},
    ]);
    eq_or_diff $job->as_testable_hash, {
        class => 'TestJobClass',
        arg => {a => 1, b => 2},
        run_after => undef,
    };
}

sub _as_testable_hash_with_priority : Test(1) {
    my $f = file('test');
    my $job = Test::Worker::Client::Job->new($f, [
        'TestJobClass',
        {a => 1, b => 2},
        {priority => 0},
    ]);
    eq_or_diff $job->as_testable_hash, {
        class => 'TestJobClass',
        arg => {a => 1, b => 2},
        run_after => undef,
        priority => 0,
    };
}

__PACKAGE__->runtests;

1;
