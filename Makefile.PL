#! /usr/bin/env perl
use warnings;
use strict;

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
        'Dancer2::Plugin::RPC::RESTISH'    => '2.01_01',
        'Dancer2::Plugin::DBIC'            => '0.0100',
        'Perl5::CoreSmokeDB::Schema'       => '1.07',
        'Moo'                              => '2.00',
        'MooX::Params::CompiledValidators' => '0.05',
        'DateTime::Format::Pg'             => '0.16013',
        'Bread::Board'                     => '0',
        'namespace::autoclean'             => '0.16',
    },
);
