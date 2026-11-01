#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

# Test 1: Verify that the script compiles successfully without syntax errors
my $output = `perl -c tispen.pl 2>&1`;
like($output, qr/syntax OK/, 'tispen syntax is OK');

# Test 2: Simulate execution with a mock session file in non-GUI test mode
$ENV{TISPEN_TEST_RUN} = 1;
my $run_output = `perl tispen.pl t/mock_session.in 2>&1`; 
is($?, 0, 'tispen executed successfully in test mode');

