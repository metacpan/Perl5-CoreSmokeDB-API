#! /usr/bin/env perl
use v5.10.1;
use warnings;
use strict;
use lib 'local/lib/perl5';

use ExtUtils::MakeMaker 6.55_02;

WriteMakefile(
    NAME          => 'Perl5::CoreSmokeDB',
    VERSION_FROM  => 'lib/Perl5/CoreSmokeDB.pm',
    ABSTRACT_FROM => 'lib/Perl5/CoreSmokeDB.pm',

    BUILD_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.55_02',
    },
    TEST_REQUIRES => {
        'Test::Simple'   => '0.88',
        'Test::Fatal'    => '0',
        'Test::Warnings' => '0',
    },
    PREREQ_PM => {
        'Dancer2::Plugin::RPC::RESTISH'    => '2.02',
        'Dancer2::Plugin::DBIC'            => '0.0100',
        'Perl5::CoreSmokeDB::Schema'       => '1.07',
        'Moo'                              => '2.00',
        'MooX::Params::CompiledValidators' => '0.05',
        'DateTime::Format::Pg'             => '0.16013',
        'DateTime::Format::SQLite'         => '0.11',
        'Bread::Board'                     => '0.37',
        'namespace::autoclean'             => '0.16',
    },
);

{
    package MY;

    sub test {
        my $self = shift;
        my $orig = $self->SUPER::test(@_);
        $orig = "DANCER_ENVIRONMENT=test\n$orig";

        $orig .= <<"EOM";

XTEST_FILES = xt/*.t
xtest ::
EOM

        my $varpfx = $^O eq 'MSWin32' ? '$$' : '\$$';
        $orig .= "\t"
            . qq{PERL5LIB="local/lib/perl5" DANCER_ENVIRONMENT=test }
            . qq{\$(FULLPERLRUN) "-e" "my ${varpfx}sw=q[-wl]; }
            . qq{${varpfx}sw .= q[v] if \$(TEST_VERBOSE); }
            . qq{system qq[prove ${varpfx}sw \$(XTEST_FILES)]"};

        return $orig;
    }

    1;
}

