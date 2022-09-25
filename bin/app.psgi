#! /usr/bin/env perl -w
use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../local/lib/perl5";

use Perl5::CoreSmokeDB;

Perl5::CoreSmokeDB->to_app();
