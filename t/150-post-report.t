#! perl -I. -w
use t::Test::abeltje;
use lib 'local/lib/perl5';

BEGIN { $ENV{DANCER_ENVIRONMENT} = 'test'; }

use File::Temp            qw( tempdir );
use File::Spec::Functions qw( catfile );
use Plack::Test;
use HTTP::Request;
use JSON;
use URI::Escape;

use_ok('Perl5::CoreSmokeDB');

my $app = Perl5::CoreSmokeDB->to_app();
my $tester = Plack::Test->create($app);

my $jsn_file = catfile('t', 'data', 'idefix-gff5bbe677.jsn');
my $jsn_rpt  = do { local (@ARGV, $/) = ($jsn_file); <ARGV> };

# We don't want to make changes to the database at this point!
my $schema = Perl5::CoreSmokeDB::schema('default');
$schema->txn_do(
    sub {
        note("POST /api/report");
        my $response = $tester->request(
            HTTP::Request->new(
                POST => '/api/report',
                [ 'Content-type' => 'application/json' ],
                to_json({ report_data => from_json($jsn_rpt) })
            )
        );
        is($response->code, 200, "Request OK");
        my $report_id = from_json($response->content);
        is_deeply(
            $report_id,
            { id => 31 },
            "We have a new report in the database (/api/post)"
        ) or diag(explain($report_id));

        $response = $tester->request(
            HTTP::Request->new(
                POST => '/api/report',
                [ 'Content-type' => 'application/json' ],
                to_json({ report_data => from_json($jsn_rpt) })
            )
        );
        is($response->code, 200, "Request OK");
        my $error = from_json($response->content);
        is($error->{error}, "Report already posted.", "Report already posted")
            or diag(explain($error));

        $schema->txn_rollback;
    }
);

$schema->txn_do(
    sub {
        note("Backward compatibility: POST /report");
        my $response = $tester->request(
            HTTP::Request->new(
                POST => '/report',
                [ 'Content-type' => 'application/x-www-form-urlencoded' ],
                join("=", map {uri_escape($_) } "json", $jsn_rpt)
            )
        );
        is($response->code, 200, "Request OK");
        my $report_id = from_json($response->content);
        is_deeply(
            $report_id,
            { id => 31 },
            "We have a new report in the database (/post)"
        ) or diag(explain($report_id));

        $schema->txn_rollback;
    }
);

abeltje_done_testing();
