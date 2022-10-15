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
    note("rpc_reports_from_epoch");
    my $response = $tester->request(
        HTTP::Request->new(
            GET => '/api/reports_from_date/1665090188'
        )
    );
    is($response->code, 200, "Request OK");
    my $reports = from_json($response->content);
    is_deeply(
        $reports,
        [26, 21, 1],
        "A list of reports from '2022-10-06T21:03:08Z'"
    ) or diag(explain($reports));

    $response = $tester->request(
        HTTP::Request->new(
            GET => '/api/reports_from_date/' . time()
        )
    );
    is($response->code, 200, "Request OK");
    $reports = from_json($response->content);
    is_deeply(
        $reports,
        [ ],
        "A list of reports from 'time()'"
    ) or diag(explain($reports));
}

{
    note("rpc_reports_from_id");
    my $response = $tester->request(
        HTTP::Request->new(
            GET => '/api/reports_from_id/26'
        )
    );
    is($response->code, 200, "Request OK");
    my $reports = from_json($response->content);
    is_deeply(
        $reports,
        [26, 27, 28, 29, 30],
        "A list of reports from 'id = 26'"
    ) or diag(explain($reports));

    $response = $tester->request(
        HTTP::Request->new(
            GET => '/api/reports_from_id/31'
        )
    );
    is($response->code, 200, "Request OK");
    $reports = from_json($response->content);
    is_deeply(
        $reports,
        [ ],
        "A list of reports from 'id = 31'"
    ) or diag(explain($reports));
}

{
    note("rpc_report_data");
    my $response = $tester->request(
        HTTP::Request->new(
            GET => '/api/report_data/1'
        )
    );
    is($response->code, 200, "Request OK");
    my $report = from_json($response->content);
    my $file_name = catfile('t', 'data', 'report1.pl');
    my $expected = do $file_name;
    is_deeply($report, $expected, "Report as expected (t/data/report1.pl)")
        or diag(explain($report));

    $response = $tester->request(
        HTTP::Request->new(
            GET => '/api/report_data/31'
        )
    );
    is($response->code, 404, "Not Found");
    $report = $response->content;
    $expected = '';
    is_deeply($report, $expected, "Report as expected (empty)")
        or diag(explain($report));
}

abeltje_done_testing();
