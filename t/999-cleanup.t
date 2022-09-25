#! perl -I. -w
use t::Test::abeltje;

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'test' }

use Dancer2;
my $dsn = config->{plugins}{DBIC}{test}{dsn};
my $dbname = $dsn =~ m{ dbname = (?<dbname>[^;]+) }x ? $+{dbname} : "";

ok($dbname, "we have a database name: $dbname");
unlink($dbname);

abeltje_done_testing();
