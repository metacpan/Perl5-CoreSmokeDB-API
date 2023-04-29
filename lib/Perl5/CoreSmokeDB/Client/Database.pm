package Perl5::CoreSmokeDB::Client::Database;
use Moo;

with(
    'Perl5::CoreSmokeDB::ValidationTemplates',
    'MooX::Params::CompiledValidators'
);

use version;
use DateTime;
use Date::Parse qw( str2time );

=head1 NAME

Perl5SmokeDB::Client::Database - A set of queries in DBIx::Class style

=head1 ATTRIBUTES

=head2 schema

An instance of L<Perl5::CoreSmokeDB::Schema>.

=cut

use Types::Standard qw( InstanceOf );
has schema => (
    is       => 'ro',
    isa      => InstanceOf["Perl5::CoreSmokeDB::Schema"],
    required => 1
);

my @_binary_data = qw/ log_file out_file manifest_msgs compiler_msgs nonfatal_msgs /;

=head1 DESCRIPTION

This is the interface between the database and the API, it executes queries and
returns (lists of) I<DBIx::Class::Result::*> objects.

=head2 get_dbversion

Retrieve the C<dbversion> from the C<tsgateway_config> table.

=cut

sub get_dbversion {
    my $self = shift;
    my $dbversion = $self->schema->resultset(
        'TsgatewayConfig'
    )->find({ name => 'dbversion' })->value;
    return $dbversion;
}

=head2 get_pverlist

Retrieve a list of C<Report> records for the given C<pversion>

=head3 Parameters

Positional:

=over

=item 1. pversion [Optional]

=back

=head3 Response

=cut

sub get_pverlist {
    my $self = shift;
    $self->validate_positional_parameters(
        [
            $self->parameter(
                pversion => $self->Optional,
                { store   => \my $pversion, default => '%' }
            ),
        ],
        \@_
    );

    my $result = $self->schema->resultset('Report')->search_rs(
        { perl_id => { LIKE => $pversion } },
        {
            columns  => ['perl_id'],
            group_by => ['perl_id'],
        }
    );
    return [
        sort {
            version->new($b->perl_id)->numify <=> version->new($a->perl_id)->numify
        } $result->all
    ];
}

=head2 $db->get_os_list

Return a list of I<*::Result::Report> objects with only the C<osname> field.

=cut

sub get_os_list {
    my $self = shift;

    my $result = $self->schema->resultset('Report')->search_rs(
        undef,
        {
            select   => ['osname'],
            group_by => ['osname'],
            order_by => { -asc => 'osname' },
        }
    );

    return [ $result->all ];
}

=head2 $db->get_arch_list

Return a list of I<*::Result::Report> objects with only the C<architecture> field.

=cut

sub get_arch_list {
    my $self = shift;

    my $result = $self->schema->resultset('Report')->search_rs(
        undef,
        {
            select   => ['architecture'],
            group_by => ['architecture'],
            order_by => { -asc => 'architecture' },
        }
    );

    return [ $result->all ];
}

=head2 $db->get_cc_list

Return a list of I<*::Result::Report> objects with only the C<cc> field.

=cut

sub get_cc_list {
    my $self = shift;

    my $result = $self->schema->resultset('Config')->search_rs(
        undef,
        {
            select   => ['cc'],
            group_by => ['cc'],
            order_by => { -asc => 'cc' },
        }
    );

    return [ $result->all ];
}

=head2 $db->get_plevel_list

Return a list of I<*::Result::Report> objects with only the C<plevel> field.

=cut

sub get_plevel_list {
    my $self = shift;

    my $result = $self->schema->resultset('Report')->search_rs(
        undef,
        {
            columns  => ['plevel'],
            group_by => ['plevel'],
            order_by => { -asc      => 'plevel' },
        }
    );

    return [ $result->all ];
}

=head2 $db->get_by_id($rid)

Return a C<_flatten_report> of I<*::Result::Report>.

=head3 Parameters

Positional

=over

=item B<$rid>

The id of the report in the database.

=back

=cut

sub get_by_id {
    my $self = shift;
    $self->validate_positional_parameters(
        [ $self->parameter(rid => $self->Required, {store => \my $rid}) ],
        \@_
    );

    my $result = $self->schema->resultset('Report')->find(
        { id => $rid },
    );

    return $result
        ? _flatten_report($result)
        : { };
}

=head2 $db->get_latest_reports

Returns a list of distinct records from the C<report> table with the latest
report per host.

=cut

sub get_latest_reports {
    my $self = shift;

    my $reports = $self->schema->resultset('Report');
    my $result = $reports->search(
        {
            plevel => {
                '=' => $reports->search(
                    {
                        hostname     => { '=' => \'me.hostname' },
                    },
                    { alias => 'rh' }
                )->get_column('plevel')->max_rs->as_query,
            },
            smoke_date => {
                '=' => $reports->search(
                    {
                        hostname => { '=' => \'me.hostname' },
                        plevel   => { '=' => \'me.plevel' },
                    },
                    { alias => 'rhp' }
                )->get_column('smoke_date')->max_rs->as_query,
            },
        },
        {
            columns => [qw/
                id architecture hostname osname osversion
                perl_id git_id git_describe plevel smoke_branch
                username smoke_date summary cpu_count cpu_description
            /],
            order_by => [
                { '-desc' => 'smoke_date' },
                { '-desc' => 'plevel' },
                qw/architecture osname osversion hostname/
            ],
        }
    );

    return [ $result->all ];
}

=head2 $db->get_latest_plevel

Returns the maximum C<plevel> in table C<report>.

=cut

sub get_latest_plevel {
    my $self = shift;

    return $self->schema->resultset(
        'Report'
    )->search()->get_column('plevel')->max();
}

=head2 $db->get_full_report

Returns a single record from the C<report> table.

=head3 Parameters

Positional:

=over

=item 1. $report_id

=back

=head3 Response

A single record from the C<report> table.

=cut

sub get_full_report {
    my $self = shift;
    $self->validate_positional_parameters(
        [ $self->parameter(rid => $self->Required, { store => \my $rid }) ],
        [ @_ ]
    );

    return $self->schema->resultset('Report')->find({ id => $rid });
}

=head2 $db->get_failures_by_version

Return a list of records filtered by the last 5 perl versions.

=head3 Response

Returns a list of HashRefs:

=over

=item B<test>

=item B<report_id>

=item B<perl_id>

=item B<git_id>

=item B<plevel>

=item B<os_name>

=item B<os_version>

=back

=cut

sub get_failures_by_version {
    my $self = shift;

    my $pverlist = $self->get_pverlist();
    my $pversion_in = [ map { $_->perl_id } grep {defined} @{$pverlist}[ 0 .. 4 ] ];

    my $failures = $self->schema->resultset('Failure')->search(
        {
            'status'         => { like => 'FAILED%' },
            'report.perl_id' => $pversion_in,
        },
        {
            join         => { failures_for_env => { result => { config => 'report' } } },
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            columns      => {
                test       => 'test',
                report_id  => 'report.id',
                perl_id    => 'report.perl_id',
                git_id     => 'report.git_describe',
                plevel     => 'report.plevel',
                os_name    => 'report.osname',
                os_version => 'report.osversion',
            },
            distinct => 1,
        }
    );

    return $failures;
}

=head2 $db->get_failures_for_pversion

Return a list of records filtered by perl version (C<report.perl_id>)

=head3 Response

Returns a list of HashRefs:

=over

=item B<test>

=item B<report_id>

=item B<perl_id>

=item B<git_id>

=item B<plevel>

=item B<os_name>

=item B<os_version>

=back

=cut

sub get_failures_for_pversion {
    my $self = shift;
    $self->validate_positional_parameters(
        [
            $self->parameter(test     => $self->Required, { store => \my $test }),
            $self->parameter(pversion => $self->Optional, { store => \my $pversion })
        ],
        [ @_ ]
    );

    my $pversion_in;
    if (!$pversion) {
        my $pverlist = $self->get_pverlist();
        $pversion_in = [ map { $_->perl_id } grep {defined} @{$pverlist}[ 0 .. 4 ] ];
    }

    my $failures = $self->schema->resultset('Failure')->search(
        {
            'status' => { like => 'FAILED%' },
            'test'   => $test,
            ($pversion
                ? ('report.perl_id' => $pversion)
                : ('report.perl_id' => $pversion_in)
            ),
        },
        {
            join         => { failures_for_env => { result => { config => 'report' } } },
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            columns      => {
                test       => 'test',
                report_id  => 'report.id',
                perl_id    => 'report.perl_id',
                git_id     => 'report.git_describe',
                plevel     => 'report.plevel',
                os_name    => 'report.osname',
                os_version => 'report.osversion',
            },
            distinct => 1,
        }
    );

    return $failures;
}

=head2 $db->failures_submatrix

=head3 Parameters

Positional:

=over

=item test     => [Required]

=item pversion => [Optional]

=back

=head3 Response

Returns a list of HashRefs:

=over

=item B<test>

=item B<report_id>

=item B<perl_id>

=item B<git_id>

=item B<plevel>

=item B<os_name>

=item B<os_version>

=item B<git_sha>

=back

=cut

sub failures_submatrix {
    my $self = shift;

    my $fails = $self->get_failures_for_pversion(@_);
    my @reports = map {
        my $copy = $_;
        $copy->{git_sha} = $copy->{git_id} =~ /-g(?<sha>[0-9a-f]+)$/
            ? $+{sha} : '';
        $copy
    } sort {
           version->new($b->{perl_id})->numify <=> version->new($a->{perl_id})->numify
        || $b->{plevel}                        cmp $a->{plevel}
        || $a->{report_id}                     <=> $b->{report_id}
    } $fails->all;

    return \@reports;
}

=head2 $db->get_search_results(\%parameters);

=cut

sub get_search_results {
    my $self = shift;
    my %data = $self->validate_parameters(
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

    my $page = $data{page} || 1;
    my $rpp = $data{reports_per_page} || 25;

    my $perlversion_list = [
        map {
            {label => $_->perl_id, value  => $_->perl_id }
        } @{ $self->get_pverlist }
    ];
    my $perl_latest      = $perlversion_list->[0]{value};
    my $pv_selected = $data{selected_perl} || "all";
    $pv_selected    = "%" if $pv_selected eq "all";
    $pv_selected    = $perl_latest if $pv_selected eq "latest";

    my %filter      = (
        report_architecture        => $data{selected_arch},
        report_architecture_andnot => $data{andnotsel_arch},
        report_osname              => $data{selected_osnm},
        report_osname_andnot       => $data{andnotsel_osnm},
        report_osversion           => $data{selected_osvs},
        report_osversion_andnot    => $data{andnotsel_osvs},
        report_hostname            => $data{selected_host},
        report_hostname_andnot     => $data{andnotsel_host},
        report_smoke_branch        => $data{selected_branch},
        config_cc                  => $data{selected_comp},
        config_cc_andnot           => $data{andnotsel_comp},
        config_ccversion           => $data{selected_cver},
        config_ccversion_andnot    => $data{andnotsel_cver},
    );

    while (my ($k, $v) = each %filter) {
        delete $filter{$k} if ! $v;
    }

    # If Perl version is 'latest' (or initial empty) and no other filter is used,
    # only show the latest smoke result per Arch/OS/OSVersion/...
    my ($reports, $count);
    if ((not $data{selected_perl} or $data{selected_perl} eq "latest")
        and not %filter) {
        $reports = $self->get_reports_by_perl_version($pv_selected,  \%filter);
    } else {
        $reports = $self->get_reports_by_filter($pv_selected, $page, \%filter, $rpp);
        $count   = $self->count_reports_by_filter($pv_selected,  \%filter);
    }

    $reports = [ map { $_->as_hashref } @$reports ];
    return {
        reports      => $reports,
        report_count => $count // scalar(@$reports),
        rpp          => $count ? $rpp : scalar(@$reports),
        page         => $count ? $page : 1,
    };
}

=head2 $db->get_filter_query_report

=cut

sub get_filter_query_report {
    my $self = shift;
    $self->validate_positional_parameters(
        [
            $self->parameter(
                filter => $self->Required, { store => \my $raw_filter, default => sub { {}  } }
            ),
        ],
        [ @_ ]
    );
    my %report_filter;

    for my $key (keys %$raw_filter) {
        next if $key =~ /_andnot$/;
        if ($raw_filter->{$key .'_andnot'}) {
            $key =~ /^report_(.+)/ and $report_filter{$1} = { '!=' => $raw_filter->{$key} };
        } else {
            $key =~ /^report_(.+)/ and $report_filter{$1} = $raw_filter->{$key};
        }
    }
    return %report_filter;
}

=head2 $db->get_filter_query_config

=cut

sub get_filter_query_config {
    my $self = shift;
    $self->validate_positional_parameters(
        [ $self->parameter(filter => $self->Required, { store => \my $raw_filter }) ],
        [ @_ ]
    );
    my %config_filter;

    for my $key (keys %$raw_filter) {
        next if $key =~ /_andnot$/;
        if ($raw_filter->{$key .'_andnot'}) {
            $key =~ /^config_(.+)/ and $config_filter{"configs.$1"} = { '!=' => $raw_filter->{$key} };
        } else {
            $key =~ /^config_(.+)/ and $config_filter{"configs.$1"} = $raw_filter->{$key};
        }
    }
    return %config_filter;
}

=head2 $db->get_reports_by_perl_version

=cut

sub get_reports_by_perl_version {
    my $self = shift;
    $self->validate_positional_parameters(
        [
            $self->parameter(
                plevel => $self->Optional, { store => \my $pattern, default => '%' }
            ),
            $self->parameter(
                filter => $self->Optional, { store => \my $raw_filter, default => sub { {} } }
            )
        ],
        [ @_ ]
    );
    ($pattern ||= '%') =~ s/\*/%/g;

    my $sr = $self->schema->resultset('Report');
    my $reports = $sr->search(
        {
            perl_id    => { -like => $pattern },
            smoke_date => {
                '=' => $sr->search(
                    {
                        architecture => {'=' => \'me.architecture'},
                        hostname     => {'=' => \'me.hostname'},
                        osname       => {'=' => \'me.osname'},
                        osversion    => {'=' => \'me.osversion'},
                        perl_id      => {'=' => \'me.perl_id'},
                    },
                    { alias => 'rr' }
                )->get_column('smoke_date')->max_rs->as_query
            },
            $self->get_filter_query_report(\%$raw_filter),
        },
        {
            columns => [qw/
                id architecture hostname osname osversion
                perl_id git_id git_describe plevel smoke_branch
                username smoke_date summary cpu_count cpu_description
            /],
            order_by => [qw/architecture hostname osname osversion/],
        }
    );
    return [ $reports->all() ];
}

=head2 $db->count_reports_by_filter

=cut

sub count_reports_by_filter {
    my $self = shift;
    $self->validate_positional_parameters(
        [
            $self->parameter(
                plevel => $self->Optional, { store => \my $pattern, default => '%' }
            ),
            $self->parameter(
                filter => $self->Optional, { store => \my $raw_filter, default => sub { {} } }
            )
        ],
        [ @_ ]
    );
    ($pattern ||= '%') =~ s/\*/%/g;

    return $self->schema->resultset('Report')->search(
        {
            perl_id  => { -like => $pattern },
            $self->get_filter_query_report(\%$raw_filter),
            $self->get_filter_query_config(\%$raw_filter),
        },
        {
            join     => 'configs',
            columns  => [qw/id/],
            distinct => 1,
        }
    )->count();
}

=head2 $db->get_reports_by_filter

=cut

sub get_reports_by_filter {
    my $self = shift;
    $self->validate_positional_parameters(
        [
            $self->parameter(
                plevel => $self->Required, { store => \my $pattern, default => '%' }
            ),
            $self->parameter( page => $self->Required, { store => \my $page } ),
            $self->parameter(
                filter => $self->Optional, { store => \my $raw_filter, default => sub { {} } }
            ),
            $self->parameter(
                reports_per_page => $self->Optional, { store => \my $reports_per_page }
            ),
        ],
        [ @_ ]
    );
    ($pattern ||= '%') =~ s/\*/%/g;

    my $reports = $self->schema->resultset('Report')->search(
        {
            perl_id  => { -like => $pattern },
            $self->get_filter_query_report($raw_filter),
            $self->get_filter_query_config($raw_filter),
        },
        {
            join     => 'configs',
            columns => [qw/
                id architecture hostname osname osversion
                perl_id git_id git_describe plevel smoke_branch
                username smoke_date summary cpu_count cpu_description
            /],
            distinct => 1,
            order_by => { -desc => 'smoke_date' },
            page     => $page,
            rows     => $reports_per_page,
        }
    );
    return [$reports->all()];
}

=head2 $db->get_architecture_host_os

Returns a list of (distinct) records from the C<report> table with only the
C<architecture>, C<hostname>, C<osname> and C<osversion> columns.

=cut

sub get_architecture_host_os {
    my $self = shift;
    my $architecture = $self->schema->resultset('Report')->search(
        undef,
        {
            columns  => [qw/architecture hostname osname osversion/],
            group_by => [qw/architecture hostname osname osversion/],
            order_by => [qw/architecture hostname osname osversion/],
        },
    );
    return [ $architecture->all() ];
}

=head2 $db->get_compilers

Returns a list of (distinct) from the C<report> table with only the C<cc> and
C<ccversion> columns.

=cut

sub get_compilers {
    my $self = shift;
    my $compilers = $self->schema->resultset('Config')->search(
        undef,
        {
            columns  => [qw/cc ccversion/],
            group_by => [qw/cc ccversion/],
            order_by => [qw/cc ccversion/],
        }
    );
    return [ $compilers->all() ];
}

=head2 $db->get_branches

Returns a list of  records from the C<report> table with only the C<smoke_branch> column.

=cut

sub get_branches {
    my $self = shift;
    my $branches = $self->schema->resultset('Report')->search_rs(
        { },
        {
            columns  => ['smoke_branch'],
            group_by => ['smoke_branch'],
            order_by => ['smoke_branch']
        }
    );
    return [ $branches->all ];
}

=head2 $db->post_report($data)

Post the report.

=cut

sub post_report {
    my $self = shift;
    $self->validate_positional_parameters(
        [ $self->parameter(report_data => $self->Required, { store => \my $data }) ],
        [ @_ ]
    );

    my $sconfig = $self->post_smoke_config(delete $data->{'_config'});

    my $report_data = {
        %{ delete $data->{'sysinfo'} },
        sconfig_id => $sconfig->id,
    };
    $report_data->{lc($_)} = delete $report_data->{$_} for keys %$report_data;
    $report_data->{smoke_date} = DateTime->from_epoch(
        epoch     => str2time($report_data->{smoke_date}),
        time_zone => 'UTC',
    );

    my @to_unarray = qw/
        skipped_tests applied_patches
        compiler_msgs manifest_msgs nonfatal_msgs
    /;
    $report_data->{$_} = join("\n", @{delete($data->{$_}) || []}) for @to_unarray;

    my @other_data = qw/harness_only harness3opts summary/;
    $report_data->{$_} = delete $data->{$_} for @other_data;

    my $configs = delete $data->{'configs'};
    return $self->schema->txn_do(
        sub {
            my $r = $self->schema->resultset('Report')->create($report_data);
            $r->discard_changes; # re-fetch for the generated plevel

            for my $config (@$configs) {
                my $results = delete $config->{'results'};
                for my $field (qw/cc ccversion/) {
                    $config->{$field} ||= '?';
                }
                $config->{started} = DateTime->from_epoch(
                    epoch     => str2time($config->{started}),
                    time_zone => 'UTC',
                );

                my $conf = $r->create_related('configs', $config);

                for my $result (@$results) {
                    my $failures = delete $result->{'failures'};
                    my $res = $conf->create_related('results', $result);

                    for my $failure (@$failures) {
                        $failure->{'extra'} = join("\n", @{$failure->{'extra'}});
                        my $db_failure = $self->schema->resultset(
                            'Failure'
                        )->find_or_create(
                            $failure,
                            {key => 'failure_test_status_extra_key'}
                        );
                        $self->schema->resultset('FailureForEnv')->create(
                            {
                                result_id  => $res->id,
                                failure_id => $db_failure->id,
                            }
                        );
                    }
                }
            }
            return $r;
        }
    );
}

=head2 $db->post_smoke_config($data)

Checks to see if this smoke_config is already in the database. If not,
insert it.

Returns the database object.

=cut

sub post_smoke_config {
    my $self = shift;
    my ($sconfig) = @_;

    my $all_data = "";
    for my $key ( sort keys %$sconfig ) {
        $all_data .= $sconfig->{$key} || "";
    }
    my $md5 = Digest::MD5::md5_hex($all_data);

    my $sc_data = $self->schema->resultset('SmokeConfig')->find(
        $md5,
        { key => 'smoke_config_md5_key' }
    );

    if ( ! $sc_data ) {
        $sc_data = $self->schema->txn_do(
            sub {
                my $json = JSON->new()->utf8(1)->encode($sconfig);
                return $self->schema->resultset('SmokeConfig')->create(
                    {
                        md5    => $md5,
                        config => $json,
                    }
                );
            }
        );
    }
    return $sc_data;
}

=head2 $db->get_reports_from_id(@paramaters)

=head3 Parameters

Positional:

=over

=item B<$rid> [Required]

=item B<$limit> [Required]

=back

=head3 Response

Returns a list of Report-records with only the C<id> field.

=cut

sub get_reports_from_id {
    my $self = shift;
    $self->validate_positional_parameters(
        [
            $self->parameter(rid => $self->Required, { store => \my $rid }),
            $self->parameter(limit => $self->Required, { store => \my $limit }),
        ],
        [ @_ ]
    );

    my $reports = $self->schema->resultset('Report')->search_rs(
        { id => { '>=' => $rid } },
        {
            columns  => ['id'],
            order_by => { -asc => 'id' },
            rows     => $limit,
        }
    );

    return [ $reports->all ];
}

=head2 $db->get_reports_from_epoch(@parameters)

=head3 Parameters

Positional:

=over

=item 1. B<$epoch> [Required]

A timestamp/epoch.

=back

=head3 Response

Returns a list of Report-records with only the C<id> field.

=cut

sub get_reports_from_epoch {
    my $self = shift;
    $self->validate_positional_parameters(
        [ $self->parameter(epoch => $self->Required, { store => \my $epoch }) ],
        [ @_ ]
    );

    my $from_time = DateTime->from_epoch(epoch => $epoch, time_zone => 'UTC');
    my $reports = $self->schema->resultset('Report')->search_rs(
        { smoke_date => { '>=' => $from_time->strftime("%F %T") } },
        {
            columns  => ['id'],
            order_by => { -asc => [ 'smoke_date', 'id' ] },
        }
    );

    return [ $reports->all ];
}

sub _flatten_report {
    my ($report) = @_;
    return {
        $report->get_inflated_columns,
        config => [
            map {
                {
                    $_->get_inflated_columns,
                    result => [
                        map { {$_->get_inflated_columns} } $_->results
                    ]
                }
            } $report->configs
        ]
    };
}

use namespace::autoclean;
1;

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See:

=over 4

=item * L<http://www.perl.com/perl/misc/Artistic.html>

=item * L<http://www.gnu.org/copyleft/gpl.html>

=back

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=head1 COPYRIGHT

E<copy> MMXXII - Abe Timmerman <abeltje@cpan.org>

=cut
