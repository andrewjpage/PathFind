#!/usr/bin/env perl
use strict;
use warnings;

BEGIN { unshift(@INC, './lib') }
BEGIN { unshift(@INC, '/software/pathogen/internal/pathdev/vr-codebase/modules') }
BEGIN {
    use Test::Most;
	use Test::Exception;
}

use_ok('Path::Find');

my $obj = Path::Find->new;
# Check hierarchy template
is $obj->hierarchy_template, 'genus:species-subspecies:TRACKING:projectssid:sample:technology:library:lane', 'hierarchy ok';

my $db_file = '/lustre/scratch118/infgen/'; # Database filesystem
my $db_root = $db_file.'pathogen/pathpipe/'; # Database root directory
my $database_A = 'pathogen_prok_track'; # existing database
my $location_A = $db_root.'prokaryotes/seq-pipelines';
my $database_B = 'pathogen_trex_track'; # unknown database

# Find existing database
my ($vrtrack_A, $dbi_A, $root_A) = $obj->get_db_info($database_A);

isa_ok $vrtrack_A, 'VRTrack::VRTrack';
isa_ok $dbi_A, 'DBI::db';
is $root_A, $location_A, 'found known directory ok';

# Fail to find non-existing database
dies_ok {$obj->get_db_info($database_B)} 'DB info dies for unknown DB';

# Check pathogen databases list
my $databases = scalar $obj->pathogen_databases;
my $db_list_ok = $databases ? 1:0;
is $db_list_ok, 1, "$databases pathogen databases listed";

done_testing();
exit;
