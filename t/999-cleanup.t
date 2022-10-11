#! perl -I. -w
use t::Test::abeltje;
use lib 'local/lib/perl5';

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'test' }

pass("Nothing to see here...");

abeltje_done_testing();
