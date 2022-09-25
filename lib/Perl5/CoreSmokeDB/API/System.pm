package Perl5::CoreSmokeDB::API::System;
use Moo;

with 'MooX::Params::CompiledValidators';

our $VERSION = '0.01';

use Dancer2::Plugin::RPC;
use Dancer2::RPCPlugin::DispatchMethodList;
use Dancer2::RPCPlugin::ErrorResponse;
use Dancer2::RPCPlugin::PluginNames;

use DateTime;
use POSIX ();
use version;

use Types::Standard qw( Str Num StrMatch );
has app_version => (
    is       => 'ro',
    isa      => Str,
    required => 1
);
has app_name => (
    is       => 'ro',
    isa      => Str,
    required => 1
);
has active_since => (
    is       => 'ro',
    isa      => Num,
    required => 1
);

sub rpc_version {
    my $self = shift;
    return { software_version => $self->app_version };
}

sub rpc_ping { return "pong"; }

sub rpc_status {
    my $self = shift;
    my $dt   = DateTime->from_epoch(
        epoch     => $self->active_since,
        time_zone => 'Europe/Amsterdam',
    );

    return {
        app_version  => "v" . version->parse($self->app_version)->numify,
        app_name     => $self->app_name,
        active_since => $dt->rfc3339,
        hostname     => (POSIX::uname)[1],
        running_pid  => $$,
        dancer2      => "v" . $Dancer2::VERSION,
        rpc_plugin   => "v" . $Dancer2::Plugin::RPC::VERSION,
    };
}

sub rpc_list_methods {
    my $self = shift;
    $self->validate_parameters(
        { $self->parameter(plugin => $self->Optional, { store => \my $plugin }) },
        $_[0]
    );

    my $dispatch =  Dancer2::RPCPlugin::DispatchMethodList->new;
    return $dispatch->list_methods($plugin//'any');
}

sub ValidationTemplates {
    my $pn = Dancer2::RPCPlugin::PluginNames->new;
    my $any_plugin = sprintf("(?:%s|any)", $pn->regex);
    return {
        plugin => { type => StrMatch[ qr{$any_plugin} ], default => 'any' },
    };
}

use namespace::autoclean;
1;

=head1 NAME

System - Interface to basic system function.

=head1 SYNOPSIS

    my $system = System->new();

    my $pong = $system->rpc_ping();
    my $version = $system->rpc_version();
    my $methods = $system->rpc_list_methods();

=head1 ATTRIBUTES

=head2 active_since

Unix timestamp for when the object was instatiated.

=head2 app_name

The name of the app we are serving

=head2 app_version

The version of the app we are serving

=head1 DESCRIPTION

=head2 rpc_ping()

=for jsonrpc ping rpc_ping /system

=for restrpc ping rpc_ping /system

=for xmlrpc ping rpc_ping  /system

Returns the string 'pong'.

=head2 rpc_version()

=for jsonrpc version rpc_version /system

=for restrpc version rpc_version /system

=for xmlrpc version rpc_version  /system

Returns a struct:

    {software_version => 'X.YZ'}

=head2 rpc_status

=for jsonrpc status rpc_status /system

=for restrpc status rpc_status /system

=for xmlrpc status rpc_status  /system

Returns:

    {
        app_version => ...,
        app_name    => ...,
        active_since => ...,
    }

=head2 rpc_list_methods()

=for jsonrpc list_methods rpc_list_methods /system

=for restrpc list_methods rpc_list_methods /system

=for xmlrpc list_methods rpc_list_methods  /system

Returns a struct for all protocols with all endpoints and functions for that endpoint.

=head2 ValidationTemplates

Make sure we have an up-to-date definition of C<any-plugin> (the only argument we need).

=head1 COPYRIGHT

E<copy> MMXXI - Abe Timmerman <abeltje@cpan.org>

=cut
