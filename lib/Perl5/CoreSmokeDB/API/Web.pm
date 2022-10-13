package Perl5::CoreSmokeDB::API::Web;
use Moo;

with(
    'Perl5::CoreSmokeDB::ValidationTemplates',
    'MooX::Params::CompiledValidators'
);

our $VERSION = 1.00;

use Encode qw( encode decode );
use Dancer2;
use Digest::MD5;

=head1 NAME

Perl5::CoreSmokeDB::API::Web - Backend API for Perl5-CoreSmokeDB-Web

=head1 ATTRIBUTES

=head2 db_client

An instantiated L<Perl5::CoreSmokeDB::Client::Database>.

=head2 app_version

The version of L<Perl5::CoreSmokeDB> to pass in the C<rpc_version()> method.

=cut

use Types::Standard qw( InstanceOf Str );
has db_client => (
    is       => 'ro',
    isa      => InstanceOf ["Perl5::CoreSmokeDB::Client::Database"],
    required => 1
);

has app_version => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

=head1 DESCRIPTION

This API is solely written for the Vue.js app Perl5-CoreSmokeDB-Web.

There is also a Swagger version.

=head2 $api->rpc_version

Returns some versions.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"version"}'

=item B<RESTISH>

  curl -XGET http://p5sdb-api/api/version

=back

=head3 Parameters

None.

=head3 Response

A struct:

=over

=item version => C<$Perl5::CoreSmokeDB::VERSION>

=item schema_version => C<$Perl5::CoreSmokeDB::Schema::SCHEMAVERSION>

=item db_version => C<dbversion> from the C<tsgateway_config> table

=back

=cut

sub rpc_version {
    my $self = shift;

    my $schema_version = $Perl5::CoreSmokeDB::Schema::SCHEMAVERSION;
    my $db_version = $self->db_client->get_dbversion;
    return {
        schema_version => "$schema_version",
        db_version     => "$db_version",
        version        => $self->app_version,
    };
}

=head2 $api->rpc_latest

Returns a list of the latest reports per hostname.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"latest"}'

=item B<RESTISH>

  curl -XGET http://p5sdb-api/api/latest

=back

=head3 Parameters

None.

=head3 Response

A struct:

=over

=item B<reports> => A list of (abbreviated) reports

=item B<report_count> => the number of reports

=item B<latest_plevel> => the latest (highest) plevel in the database

=item B<rpp> => the number of reports per page (all of them)

=item B<page> => the current page (1)

=back

=cut

sub rpc_latest {
    my $self = shift;

    my $reports = [
        map {
            $_->as_hashref
        } @{ $self->db_client->get_latest_reports }
    ];

    return {
        reports       => $reports,
        report_count  => scalar(@$reports),
        latest_plevel => $self->db_client->get_latest_plevel,
        rpp           => scalar(@$reports),
        page          => 1,
    };
}

=head2 $api->rpc_full_report_data(\%parameters)

Returns a struct with I<all> the data from the database linked to this report.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
   -d'{"jsonrpc":"2.0", "id":"xx42", "method":"full_report_data", "params":{"rid":212}}'

=item B<RESTISH>

  curl -XGET http://p5sdb-api/api/full_report_data/1234

=back

=head3 Parameters

Named, hashref:

=over

=item B<rid> [Required]

The C<id> of the report from the database.

=back

=cut

sub rpc_full_report_data {
    my $self = shift;
    $self->validate_parameters(
        { $self->parameter(rid => $self->Required, { store => \my $report_id }) },
        $_[0]
    );

    my $db_report = $self->db_client->get_full_report($report_id);
    my $report = $db_report->as_hashref('full');

    $report->{matrix} = join("\n", $db_report->matrix);
    my @methods_to_call = qw/
        c_compilers
        test_failures test_todo_passed
        duration_in_hhmm average_in_hhmm
    /;
    for my $method (@methods_to_call) {
        $report->{ $method } = $db_report->$method;
    }
    return $report;
}

=head2 $api->rpc_get_search_parameters

Returns a set of possible search values from the database:

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"searchparameters"}'

=item B<RESTISH>

  curl -XGET http://p5sdb-api/api/searchparameters

=back

=head3 Parameters

None.

=head3 Response

A struct:

=over

=item B<sel_arch_os_ver>

This is a list of distinct structs with C<arch>, C<hostname>, C<os>, C<osversion>
combinations.

=item B<sel_comp_ver>

This is a list of distinct structs with C<comp>, C<compversion> combinations.

=item B<branches>

This is a plain list of distinct C<smoke_branch>es.

=item B<perl_versions>

This is a list of distinct C<perl_id> as C<label>/C<value> pair.

=back

=cut

sub rpc_get_search_parameters {
    my $self = shift;

    return {
        sel_arch_os_ver => [
            map {
                {
                    arch      => $_->architecture,
                    hostname  => $_->hostname,
                    os        => $_->osname,
                    osversion => $_->osversion,
                }
            } @{ $self->db_client->get_architecture_host_os }
        ],
        sel_comp_ver      => [
            map {
                {
                    comp => $_->cc,
                    compversion => $_->ccversion,
                }
            } @{$self->db_client->get_compilers}
        ],
        branches          => [
            map { $_->smoke_branch } @{$self->db_client->get_branches}
        ],
        perl_versions     => [
            map {
                { label => $_->perl_id, value => $_->perl_id }
            } @{ $self->db_client->get_pverlist }
        ],
    };
}

=head2 $api->rpc_get_search_results(\%parameters)

Returns a list of filtered reports.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"searchresults",
    "params":{"selected_perl":"all","selected_host":"bolt"}}'

=item B<RESTISH>

  curl -XGET 'http://p5sdb-api/api/searchresults?selected_perl=all&selected_host=bolt'

=back

=head3 Parameters

Named, hashref:

=over

=item B<selected_arch>    => [Optional]

=item B<andnotsel_arch>   => [Optional]

=item B<selected_osnm>    => [Optional]

=item B<andnotsel_osnm>   => [Optional]

=item B<selected_osvs>    => [Optional]

=item B<andnotsel_osvs>   => [Optional]

=item B<selected_host>    => [Optional]

=item B<andnotsel_host>   => [Optional]

=item B<selected_comp>    => [Optional]

=item B<andnotsel_comp>   => [Optional]

=item B<selected_cver>    => [Optional]

=item B<andnotsel_cver>   => [Optional]

=item B<selected_perl>    => [Optional]

=item B<selected_branch>  => [Optional]

=item B<page>             => [Optional]

=item B<reports_per_page> => [Optional]

=back

=head3 Response

A struct:

=over

=item B<reports> => A list of (abbreviated) reports

=item B<report_count> => the number of reports

=item B<latest_plevel> => the latest (highest) plevel in the database

=item B<rpp> => the number of reports per page (all of them)

=item B<page> => the current page (1)

=back

=cut

sub rpc_get_search_results {
    my $self = shift;
    my $args = $self->validate_parameters(
        {
            $self->parameter(selected_arch    => $self->Optional),
            $self->parameter(andnotsel_arch   => $self->Optional),
            $self->parameter(selected_osnm    => $self->Optional),
            $self->parameter(andnotsel_osnm   => $self->Optional),
            $self->parameter(selected_osvs    => $self->Optional),
            $self->parameter(andnotsel_osvs   => $self->Optional),
            $self->parameter(selected_host    => $self->Optional),
            $self->parameter(andnotsel_host   => $self->Optional),
            $self->parameter(selected_comp    => $self->Optional),
            $self->parameter(andnotsel_comp   => $self->Optional),
            $self->parameter(selected_cver    => $self->Optional),
            $self->parameter(andnotsel_cver   => $self->Optional),
            $self->parameter(selected_perl    => $self->Optional),
            $self->parameter(selected_branch  => $self->Optional),
            $self->parameter(page             => $self->Optional),
            $self->parameter(reports_per_page => $self->Optional),
        },
        $_[0]
    );

    my $reports = $self->db_client->get_search_results($args);
    return {
        reports       => $reports->{reports},
        report_count  => $reports->{report_count},
        latest_plevel => undef,
        rpp           => $reports->{rpp},
        page          => $reports->{page} // 1,
    };
}

=head2 $api->rpc_logfile

DEPRICATED, the C<log_file> field is part of C<rpc_full_report_data()>.

=cut

sub rpc_logfile {
    my $self = shift;
    $self->validate_parameters(
        {
            $self->parameter(rid      => $self->Required, { store => \my $report_id }),
        },
        $_[0]
    );

    my $db_report = $self->db_client->get_full_report($report_id);

    return { file => $db_report->log_file };
}

=head2 $api->rpc_outfile

DEPRICATED, the C<out_file> field is part of C<rpc_full_report_data()>.

=cut

sub rpc_outfile {
    my $self = shift;
    $self->validate_parameters(
        {
            $self->parameter(rid      => $self->Required, { store => \my $report_id }),
        },
        $_[0]
    );

    my $db_report = $self->db_client->get_full_report($report_id);

    return { file => $db_report->out_file };
}

=head2 $api->rpc_failures_matrix()

Returns a matrix of test-names and the number of smoke failures were reported
for each of the last 5 perl versions (C<perl_id>).

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"matrix"}'

=item B<RESTISH>

  curl -XGET http://p5sdb-api/api/matrix

=back

=head3 Parameters

None.

=head3 Response

A list of lists:

=over

=item B<header-row>

=item B<data-rows>

=over 8

=item B<test name>

The first column of the table is the test name.

=item B<data-struct>

The other columns are the number of failing reports and a description of the os
name/versions these reports were generated under in a struct:

=over 12

=item B<cnt>

The number of failing reports in the database.

=item B<alt>

The text to use as the C<title> attribute in the HTML, it contains a list of
os-name/versions.

=back

=back

=back

=cut

sub rpc_failures_matrix {
    my $self = shift;

    my $fails = $self->db_client->get_failures_by_version;

    # Create the matrix...
    my (%failing_test_count, %pversions);
    for my $fail ($fails->all) {
        $failing_test_count{ $fail->{test} }++;
        push @{
            $pversions{$fail->{perl_id}}{$fail->{test}}
        }, "$fail->{os_name} - $fail->{os_version}";
    }

    my %matrix = map {
        ( sprintf("%04d%s", $failing_test_count{$_}, $_) => [ $_ ] )
    } sort {
        $failing_test_count{$b} <=> $failing_test_count{$a}
    } keys %failing_test_count;
    $matrix{'?'} = [ '&nbsp;' ];

    my @reverse_sorted_pversion = sort {
        version->new($b)->numify <=> version->new($a)->numify
    } keys %pversions;
    for my $pversion (@reverse_sorted_pversion) {
        for my $index (keys %matrix) {
            if ($index eq '?') {
                push @{ $matrix{'?'} }, $pversion;
            }
            else {
                my $test = $matrix{$index}[0];
                my $count = exists $pversions{$pversion}{$test}
                    ? 0 + @{$pversions{$pversion}{$test}}
                    : '';
                my %oses = map { ($_ => undef) } @{$pversions{$pversion}{$test}};
                my $os = join(';', sort keys %oses);

                push @{$matrix{$index}}, {cnt => $count, alt => $os};
            }
        }
    }
    my @matrix;
    for my $index (sort {$b cmp $a} keys %matrix) { push @matrix, $matrix{$index} }

    return \@matrix;
}

=head2 $api->rpc_failures_submatrix(\%parameters)

Returns a list of (short) reports that reported this test failing.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"submatrix",
    "params":{"test":"../t/op/sprintf2.t"}'

=item B<RESTISH>

  curl -XGET 'http://p5sdb-api/api/submatrix?test=../t/op/sprintf2.t'

=back

=head3 Parameters

Named, hashref:

=over

=item B<test> [Required]

Test name as registered in C<failure.test>

=item B<pversion> [Optional]

Optional, C<perl_id> to filter the reports.

=back

=cut

sub rpc_failures_submatrix {
    my $self = shift;
    $self->validate_parameters(
        {
            $self->parameter(test     => $self->Required, { store => \my $test }),
            $self->parameter(pversion => $self->Optional, { store => \my $pversion }),
        },
        $_[0]
    );
    my $reports = $self->db_client->failures_submatrix(
        $test, ($pversion ? ($pversion) : ()),
    );
    return {
        reports => $reports,
        test    => $test,
        ($pversion ? (pversion => $pversion) : ()),
    };
}

=head2 $api->rpc_post_report

Add the report to the database.

=head3 Parameters

Named, hashref:

=over

=item B<report_data> [Required]

A hashref with the report-data as gathered by L<Test::Smoke::Reporter>.

=back

=cut

sub rpc_post_report {
    my $self = shift;
    $self->validate_parameters(
        { $self->parameter(report_data => $self->Required, { store => \my $data }) },
        $_[0]
    );

    my $report;
    eval {
        $report = $self->db_client->post_report($data);
        debug("Report was posted, returning id => ", $report->id);
    };
    if (my $error = $@) {
        if ("$error" =~ m{duplicate key}) {
            debug("Report is a duplicate: ", $error);
            return {
                error    => 'Report already posted.',
                db_error => "$error",
            };
        }
        debug("Report could not be stored in the database: ", $error);
        return {
            error    => 'Unexpected error.',
            db_error => "$error",
        };
    }
    return { id => $report->id };
}

=head2 $api->rpc_reports_from_id(\%parameters)

Returns a list of report-id's, starting with the one passed.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"reports_from_id",
    "params":{"rid":505042, "limit": 50}'

=item B<RESTISH>

  curl -XGET 'http://p5sdb-api/api/reports_from_id/505042?limit=50'

=back

=head3 Parameters

Named, hashref:

=over

=item B<rid> [Required]

The starting point for report-id's to return

=item B<limit> [Optional]

This is an optional limit, but will be set to C<100> if omitted.

=back

=head3 Response

A list of report-id's > C<$rid>.

=cut

sub rpc_reports_from_id {
    my $self = shift;
    $self->validate_parameters(
        {
            $self->parameter(rid => $self->Required, { store => \my $rid }),
            $self->parameter(limit => $self->Optional, { store => \my $limit }),
        },
        $_[0]
    );
    my $reports = $self->db_client->get_reports_from_id($rid, $limit//100);

    return [ map { $_->id } @$reports ];
}

=head2 $api->rpc_reports_from_epoch(\%dparameters)

Returns a list of report-id's, starting at the epoch passed.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"reports_from_id",
    "params":{"epoch":1665090188}'

=item B<RESTISH>

  curl -XGET 'http://p5sdb-api/api/reports_from_date/1665090188'

=back

=head3 Parameters

Named, hashref:

=over

=item B<epoch> [Required]

The starting point for report-id's to return

=back

=head3 Response

A list of report-id's > C<$rid>.

=cut

sub rpc_reports_from_epoch {
    my $self = shift;
    $self->validate_parameters(
        { $self->parameter(epoch => $self->Required, { store => \my $epoch }) },
        $_[0]
    );
    my $reports = $self->db_client->get_reports_from_epoch($epoch);

    return [ map { $_->id } @$reports ];
}

=head2 $api->rpc_report_data(\%parameters)

Returns the report as a datastructure.

=head3 Example calls

=over

=item B<JSONRPC>

  curl -XPOST http://p5sdb-api/api -H'Content-type: application/json' \
    -d'{"jsonrpc":"2.0", "id":"api42", "method":"report_data",
    "params":{"rid":505042}'

=item B<RESTISH>

  curl -XGET 'http://p5sdb-api/api/report_data/505042'

=back

=head3 Parameters

Named, hashref:

=over

=item B<rid> [Required]

The report-id.

=back

=head3 Response

A struct with the report and its relations.

=cut

sub rpc_report_data {
    my $self = shift;
    $self->validate_parameters(
        { $self->parameter(rid => $self->Required, { store => \my $report_id }) },
        $_[0]
    );

    my $db_report = $self->db_client->get_full_report($report_id);

    if (! $db_report) {
        status(404);
        return;
    }
    return $db_report->as_hashref('full');
}

use namespace::autoclean;
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
