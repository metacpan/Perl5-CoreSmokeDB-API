package Perl5::CoreSmokeDB::ValidationTemplates;
use Moo::Role;

our $VERSION = '1.00';

=head1 NAME

Perl5::CoreSmokeDB::ValidationTemplates - Parameter validation templates for the project.

=head2 SYNOPSIS

    use Moo;
    with(
        'Perl5::CoreSmokeDB::ValidationTemplates',
        'MooX::Params::CompiledValidators',
    );

=head1 DESCRIPTION

This L<Moo::Role> provides the C<ValidationTemplates()> method a class needs
when using L<MooX::Params::CompiledValidators>. It uses L<Types::Standard> to do
validation of the parameters.

=cut

use Types::Standard qw( Enum HashRef Int Maybe Str );

=head2 ValidationTemplates

Specify the validation of parameters used in this project.

=cut

sub ValidationTemplates {
    return {
        andnotsel_arch   => { type => Enum [qw(0 1)] },
        andnotsel_comp   => { type => Enum [qw(0 1)] },
        andnotsel_cver   => { type => Enum [qw(0 1)] },
        andnotsel_host   => { type => Enum [qw(0 1)] },
        andnotsel_osnm   => { type => Enum [qw(0 1)] },
        andnotsel_osvs   => { type => Enum [qw(0 1)] },
        filetype         => { type => Enum [qw(outfile logfile)] },
        filter           => { type => HashRef, default => sub { {} } },
        page             => { type => Int, default =>  1 },
        pversion         => { type => Maybe [Str] },
        report_data      => { type => HashRef },
        reports_per_page => { type => Int, default => 25 },
        rid              => { type => Int },
        selected_arch    => { type => Str, default => "" },
        selected_branch  => { type => Str, default => "" },
        selected_comp    => { type => Str, default => "" },
        selected_cver    => { type => Str, default => "" },
        selected_host    => { type => Str, default => "" },
        selected_osnm    => { type => Str, default => "" },
        selected_osvs    => { type => Str, default => "" },
        selected_perl    => { type => Str, default => "" },
        test             => { type => Str },
    };
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
