#! perl -I. -w
use t::Test::abeltje;
use lib 'local/lib/perl5';

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'test'; }

use Cwd qw( cwd );
use File::Temp qw( tempdir );
use File::Spec::Functions qw( catfile );
use Plack::Test;
use HTTP::Request;
use JSON;

use_ok('Perl5::CoreSmokeDB');

my $app = Perl5::CoreSmokeDB->to_app();
my $tester = Plack::Test->create($app);

{
    my $response = $tester->request(
        HTTP::Request->new(GET => '/api/version')
    );
    is($response->code, 200, "Response OK");
    is_deeply(
      from_json($response->content),
    {
        db_version     => 3,
        schema_version => 3,
        version        => $Perl5::CoreSmokeDB::VERSION,
    },
      "Found versions"
    ) or diag(explain($response));
}


abeltje_done_testing();
