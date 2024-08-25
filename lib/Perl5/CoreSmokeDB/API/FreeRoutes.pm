package Perl5::CoreSmokeDB::API::FreeRoutes;
use Moo;

our $VERSION = '0.02';

use Dancer2 appname => 'Perl5::CoreSmokeDB';

=head1 NAME

Perl5::CoreSmokeDB::API::FreeRoutes - insert non-RPC routes into the service.

=head1 SYNOPSIS

    my $free_rotes = Perl5::CoreSmokeDB::API::FreeRoutes->new();

=head1 DESCRIPTION

Provide extra routes that cannot be served by the RPC-services.

=head2 GET B</api/openapi/web.json>

Returns the processed Swagger document as C<application/json>

=cut

use Encode qw< encode decode >;
use File::Spec::Functions qw< catfile >;
use Time::HiRes qw< time >;
use YAML qw< LoadFile >;

get('/api/openapi/web.json' => sub {
    my $open_api = LoadFile(catfile(config->{openapidir}, 'Web.yml'));

    content_type('application/json');
    return to_json($open_api);
});

=head2 GET B</api/openapi/web.yaml>

Returns the processed Swagger document as C<application/x-yaml>

=cut

get('/api/openapi/web.yaml' => sub {
    my $open_api = LoadFile(catfile(config->{openapidir}, 'Web.yml'));

    content_type('application/x-yaml');
    return to_yaml($open_api);
});

=head2 GET B</api/openapi/web>

Returns the unprocessed Swagger document as is (C<text/plain>)

=cut

get '/api/openapi/web' => sub {
    my $yaml = 'Could not load yaml';
    if (open(my $fh, '<', catfile(config->{openapidir}, 'Web.yml'))) {
        $yaml = do { local $/; <$fh>};
    }
    else {
        $yaml .= ": $!";
    }
    content_type('text/plain');
    return $yaml;
};

=head2 POST B</api/old_format_reports>

This is a backward compatible endpoint that allows old clients to keep working.
It uses the global variable C<$::web_api> to access the new API.

Fastly CDN will redirect /report to /api/old_format_reports.

We need `/api` in the path so the k8 Ingest knows to sent to the correct
container.

=cut

post '/api/old_format_reports' => sub {
    my $start = time();
    my $data = from_json(encode('utf-8', params->{json}), { utf8 => 1 });

    # We need to extra encode() the bytea fields for this interface
    my @bytea = qw< compiler_msgs manifest_msgs nonfatal_msgs log_file out_file >;
    for my $fld (@bytea) {
        if (ref($data->{$fld}) eq 'ARRAY') {
            $_ = encode('utf-8', $_) for @{ $data->{$fld} };
        }
        else {
            defined($data->{$fld}) and $data->{$fld} = encode('utf-8', $data->{$fld});
        }
    }

    my $response = do {
        no warnings 'once';
        $::web_api->rpc_post_report({report_data => $data});
    };

    my $json = to_json($response);
    debug(sprintf("[MISC] POST to /report took %.3f sec.", time() - $start));
    debug("[MISC] POST to /report response: ", $response);

    content_type('application/json');
    return $json;
};

1;

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 COPYRIGHT

E<copy> MMXXII - Abe Timmerman <abeltje@cpan.org>

=cut
