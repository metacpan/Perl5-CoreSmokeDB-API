#! perl -I. -w
use t::Test::abeltje;

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'test'; }

{
    use Dancer2;
    use Dancer2::Plugin::DBIC;
    diag(explain(config->{plugins}{DBIC}{init}));
    unlink('t/p5sdb.sqlite');
    my $schema = schema('init');
    $schema->deploy;
}

use_ok('Perl5::CoreSmokeDB');

abeltje_done_testing();
