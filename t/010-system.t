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
        HTTP::Request->new(GET => '/system/ping')
    );
    is($response->code, 200, "Response OK");
    is_deeply(
        $response->content,
        "pong",
        "system/ping"
    ) or diag(explain($response));

    $response = $tester->request(
        HTTP::Request->new(GET => '/system/version')
    );
    is($response->code, 200, "Response OK");
    is_deeply(
        from_json($response->content),
        {
            software_version => Perl5::CoreSmokeDB->VERSION,
        },
        "system/version"
    ) or diag(explain($response));

    my $warnings = [ warnings {
        $response = $tester->request(
            HTTP::Request->new(GET => '/system/status')
        );
    }];
    SKIP: {
        skip("Production version is ok!", 1) if !@$warnings;
        like($warnings->[0], qr{alpha->numify\(\) is lossy}, "Lossy warning from version");
    }
    is($response->code, 200, "Response OK");
    my $status = from_json($response->content);
    my $started = delete($status->{active_since});
    $warnings = [ warnings {
        is_deeply(
            $status,
            {
                app_version => "v" . version->parse(Perl5::CoreSmokeDB->VERSION)->numify,
                app_name    => 'Perl5::CoreSmokeDB',
                dancer2     => "v" . Dancer2->VERSION,
                rpc_plugin  => "v" . Dancer2::Plugin::RPC->VERSION,
                hostname    => (POSIX::uname)[1],
                running_pid => $$,
            },
            "system/status"
        ) or diag(explain($status));
    }];
    SKIP: {
        skip("Production version is ok!", 1) if !@$warnings;
        like($warnings->[0], qr{alpha->numify\(\) is lossy}, "Lossy warning from version");
    }
}

{
    my $dispatch = Perl5::CoreSmokeDB::config()->{plugins}{'RPC::RESTISH'};
    my $restish_list = {
        map {
            my $path = $_;
            ( $path => [
                sort map { # Modules with the routes
                    keys %{ $dispatch->{$path}{$_} }
                } keys %{ $dispatch->{$path} }
            ] )
        } keys %$dispatch
    };
    $dispatch = Perl5::CoreSmokeDB::config()->{plugins}{'RPC::JSONRPC'};
    my $jsonrpc_list = {
        map {
            my $path = $_;
            ( $path => [
                sort map { # Modules with the routes
                    keys %{ $dispatch->{$path}{$_} }
                } keys %{ $dispatch->{$path} }
            ] )
        } keys %$dispatch
    };

    my $response = $tester->request(
        HTTP::Request->new(GET => '/system/methods')
    );
    is($response->code, 200, "Response OK");
    my $methods = from_json($response->content);
    is_deeply(
        $methods->{restish},
        $restish_list,
        "Dispatch/Methodlist (restish)"
    ) or diag(explain($restish_list), explain($methods));

    is_deeply(
        $methods->{jsonrpc},
        $jsonrpc_list,
        "Dispatch/Methodlist (jsonrpc)"
    ) or diag(explain($jsonrpc_list), explain($methods));

    $response = $tester->request(
        HTTP::Request->new(GET => '/system/methods/jsonrpc')
    );
    is($response->code, 200, "Response OK");
    $methods = from_json($response->content);
    is_deeply(
        $methods,
        $jsonrpc_list,
        "Dispatch/Methodlist (jsonrpc-only)"
    ) or diag(explain($jsonrpc_list));

    $response = $tester->request(
        HTTP::Request->new(GET => '/system/methods/restish')
    );
    is($response->code, 200, "Response OK");
    $methods = from_json($response->content);
    is_deeply(
        $methods,
        $restish_list,
        "Dispatch/Methodlist (restish-only)"
    ) or diag(explain($restish_list));
}


abeltje_done_testing();
