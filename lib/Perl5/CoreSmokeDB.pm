package Perl5::CoreSmokeDB;
use warnings;
use strict;
use lib 'lib';

our $VERSION = '1.01';

use Dancer2;
use Dancer2::Plugin::DBIC;
use Dancer2::Plugin::RPC::JSONRPC;
use Dancer2::Plugin::RPC::RESTISH;

use Dancer2::RPCPlugin::DefaultRoute;
use Dancer2::RPCPlugin::EndpointConfigFactory;

use Perl5::CoreSmokeDB::Client::Database;
use Perl5::CoreSmokeDB::API::System;
#use Perl5SmokeDB::API::Query;
#use Perl5SmokeDB::API::Smoquel;
use Perl5::CoreSmokeDB::API::Web;
use Perl5::CoreSmokeDB::API::FreeRoutes; # set some extra routes...

use Bread::Board;
my $system_api = container 'SystemAPI' => as {
    container 'apis' => as {
        service 'Perl5::CoreSmokeDB::API::System' => (
            class => 'Perl5::CoreSmokeDB::API::System',
            dependencies => {
                app_version  => literal($VERSION),
                app_name     => literal(__PACKAGE__),
                active_since => literal(time()),
            },
        );
    };
};

my $default_schema = schema('default');
my $db_api = container 'Perl5SmokeDBAPI' => as {
    container 'clients' => as {
        service 'Perl5::CoreSmokeDB::Client::Database' => (
            class        => 'Perl5::CoreSmokeDB::Client::Database',
            lifecycle    => 'Singleton',
            dependencies => { schema => literal($default_schema) },
        );
#        service 'Perl5SmokeDB::Client::SmoquelParser' => (
#            class     => 'Perl5SmokeDB::Client::SmoquelParser',
#            lifecycle => 'Singleton',
#        );
    };
    container 'apis' => as {
#        service 'Perl5SmokeDB::API::Query' => (
#            class        => 'Perl5SmokeDB::API::Query',
#            lifecycle    => 'Singleton',
#            dependencies => {
#                db_client => '../clients/Perl5::CoreSmokeDB::Client::Database',
#            },
#        );
#        service 'Perl5SmokeDB::API::Smoquel' => (
#            class        => 'Perl5SmokeDB::API::Smoquel',
#            lifecycle    => 'Singleton',
#            dependencies => {
#                query_api => '../apis/Perl5SmokeDB::API::Query',
#                parser    => '../clients/Perl5SmokeDB::Client::SmoquelParser',
#            },
#        );
        service 'Perl5::CoreSmokeDB::API::Web' => (
            class        => 'Perl5::CoreSmokeDB::API::Web',
            lifecycle    => 'Singleton',
            dependencies => {
                db_client   => '../clients/Perl5::CoreSmokeDB::Client::Database',
                app_version => literal($VERSION),
            },
        );
        service 'Perl5::CoreSmokeDB::API::FreeRoutes' => (
            class        => 'Perl5::CoreSmokeDB::API::FreeRoutes',
            lifecycle    => 'Singleton',
        );
    };
};
no Bread::Board;

{
    my $system_config = Dancer2::RPCPlugin::EndpointConfigFactory->new(
        publish     => 'config',
        bread_board => $system_api,
    );
    for my $plugin (qw/RPC::JSONRPC RPC::RESTISH/) {
        $system_config->register_endpoint($plugin, '/system');
    }
}
{
    my $app_config = Dancer2::RPCPlugin::EndpointConfigFactory->new(
        publish     => 'config',
        bread_board => $db_api,
        (exists(config->{cors_allow_origin})
            ? (plugin_arguments => {
                plugin_args => { cors_allow_origin => config->{cors_allow_origin} }
            })
            : ()
        ),
    );
    my $plugins = config->{plugins};
    for my $plugin (keys %$plugins) {
        next if $plugin !~ m{^ RPC:: }x;
        for my $path (keys %{$plugins->{$plugin}}) {
            $app_config->register_endpoint($plugin, $path);
        }
    }

    # Helps to provide wrappers for backward compatibility
    my $extra_routes = $db_api->resolve(
        service => 'apis/Perl5::CoreSmokeDB::API::FreeRoutes'
    );
    $::web_api = $db_api->resolve(
        service => 'apis/Perl5::CoreSmokeDB::API::Web'
    );
}

setup_default_route();

1;

=head1 NAME

Perl5::CoreSmokeDB - API Service (jsonrpc/rest) to the Perl5 CoreSmoke Database

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 COPYRIGHT

E<copy> MMXXII - Abe Timmerman <abeltje@cpan.org>

=cut
