#!/usr/bin/env perl
use Moose;
use Data::Dumper;
use File::Slurp;
use File::Path qw( remove_tree);
use Cwd;
use File::Temp;
no warnings qw{qw};

BEGIN { unshift( @INC, './lib' ) }
use Path::Find::Exception;

BEGIN {
	use Test::Most;
	use Test::Output;
	use Test::Exception;
	use Test::Files;
}

use_ok('Path::Find::CommandLine::Path');

my $script_name = 'pathfind';
my $cwd = getcwd();

my $temp_directory_obj = File::Temp->newdir(DIR => getcwd, CLEANUP => 1 );
my $tmp = $temp_directory_obj->dirname();

my (@args, $arg_str, $exp_out, $obj);

# test 1
@args =  ();
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 2
@args = ( "--test", "-h", "yes" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 3
@args = ( "--test", "-a" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 4
@args = ( "--test", "-f", "fastq" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 5
@args = ( "--test", "-f", "fastq", "-a" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 6
@args = ( "--test", "-f", "bam", "-a", "$tmp/valid_dest" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 7
@args = ( "--test", "-f", "bam", "-a", "invalid_dest" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 8
@args = ( "--test", "-i", "valid_value" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 9
@args = ( "--test", "-i", "invalid_value", "-f", "fastq" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 10
@args = ( "--test", "-t", "species" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 11
@args = ( "--test", "-t", "species", "-f", "fastq" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 12
@args = ( "--test", "-t", "species", "-f", "bam" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 13
@args = ( "--test", "-t", "species", "-i", "invalid_value" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::NoMatches', 'correct error thrown';

# test 14
@args = ( "--test", "-t", "species", "-i", "shigella" );
$exp_out = read_file('t/data/pathfind/14.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 15
@args = ( "--test", "-t", "species", "-i", "shigella", "-s", "$tmp/test.15.stats" );
$exp_out = read_file('t/data/pathfind/15.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

is(
	read_file('t/data/pathfind/15.stats'),
	read_file("$tmp/test.15.stats"),
	'stats file correct'
);

# test 16
@args = ( "--test", "-t", "species", "-i", "shigella", "-qc", "passed" );
$exp_out = read_file('t/data/pathfind/16.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 17
@args = ( "--test", "-t", "species", "-i", "shigella", "-qc", "failed" );
$exp_out = read_file('t/data/pathfind/17.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 18
@args = ( "--test", "-t", "species", "-i", "shigella", "-qc", "pending" );
$exp_out = read_file('t/data/pathfind/18.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 19
@args = ( "--test", "-t", "species", "-i", "shigella", "-a" );
$exp_out = read_file('t/data/pathfind/19.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok(-e "pathfind_shigella.tar.gz", 'archive exists');
ok(check_links('pathfind_shigella.tar.gz', $exp_out, 1), 'correct files present');

# test 20
@args = ( "--test", "-t", "species", "-i", "shigella", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/20.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 21
@args = ( "--test", "-t", "species", "-i", "shigella", "-l" );
$exp_out = read_file('t/data/pathfind/21.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok(-e "pathfind_shigella", 'archive exists');
ok(check_links('pathfind_shigella', $exp_out, 1), 'correct files present');


# test 22
@args = ( "--test", "-t", "species", "-i", "shigella", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/22.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 23
@args = ( "--test", "-t", "species", "-i", "shigella", "-f", "fastq" );
$exp_out = read_file('t/data/pathfind/23.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 24
@args = ( "--test", "-t", "species", "-i", "shigella", "-f", "fastq", "-a" );
$exp_out = read_file('t/data/pathfind/24.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "pathfind_shigella.tar.gz", 'archive exists');
ok(check_links('pathfind_shigella.tar.gz', $exp_out, 1), 'correct files present');

# test 25
@args = ( "--test", "-t", "species", "-i", "shigella", "-f", "fastq", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/25.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 26
@args = ( "--test", "-t", "species", "-i", "shigella", "-f", "fastq", "-l" );
$exp_out = read_file('t/data/pathfind/26.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok( -e "pathfind_shigella", 'symlink dir exists' );
ok( check_links('pathfind_shigella', $exp_out, 1), 'correct files symlinked' );

# test 27
@args = ( "--test", "-t", "species", "-i", "shigella", "-f", "fastq", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/27.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 28
@args = ( "--test", "-t", "file" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 29
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt" );
$exp_out = read_file('t/data/pathfind/29.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 30
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-s", "$tmp/test.30.stats" );
$exp_out = read_file('t/data/pathfind/30.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check  stats file
is(
	read_file('t/data/pathfind/30.stats'),
	read_file("$tmp/test.30.stats"),
	'stats file correct'
);

# test 31
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-qc", "passed" );
$exp_out = read_file('t/data/pathfind/31.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 32
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-qc", "failed" );
$exp_out = read_file('t/data/pathfind/32.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 33
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-qc", "pending" );
$exp_out = read_file('t/data/pathfind/33.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 34
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-a" );
$exp_out = read_file('t/data/pathfind/34.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "pathfind_path_lanes_txt.tar.gz", 'archive exists');
ok(check_links('pathfind_path_lanes_txt.tar.gz', $exp_out, 1), 'correct files present');

# test 35
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/35.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 36
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-l" );
$exp_out = read_file('t/data/pathfind/36.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "pathfind_path_lanes_txt", 'symlink dir exists' );
ok( check_links('pathfind_path_lanes_txt', $exp_out, 1), 'correct files symlinked' );

# test 37
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/37.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 38
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-f", "fastq" );
$exp_out = read_file('t/data/pathfind/38.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 39
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-f", "fastq", "-a" );
$exp_out = read_file('t/data/pathfind/39.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "pathfind_path_lanes_txt.tar.gz", 'archive exists');
ok(check_links('pathfind_path_lanes_txt.tar.gz', $exp_out, 1), 'correct files present');

# test 40
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-f", "fastq", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/40.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 41
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-f", "fastq", "-l" );
$exp_out = read_file('t/data/pathfind/41.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "pathfind_path_lanes_txt", 'symlink dir exists' );
ok( check_links('pathfind_path_lanes_txt', $exp_out, 1), 'correct files symlinked' );

# test 42
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-f", "fastq", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/42.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 43
@args = ( "--test", "-t", "file", "-i", "invalid_value" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::FileDoesNotExist', 'correct error thrown';

# test 44
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes_with_invalid.txt" );
$exp_out = read_file('t/data/pathfind/44.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 45
@args = ( "--test", "-t", "lane", "-f", "fastq", "-a", "empty_dest" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 46
@args = ( "--test", "-t", "lane", "-f", "bam" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 47
@args = ( "--test", "-t", "lane", "-i", "5477_6#1" );
$exp_out = read_file('t/data/pathfind/47.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 48
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-s", "$tmp/test.48.stats" );
$exp_out = read_file('t/data/pathfind/48.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check  stats file
is(
	read_file('t/data/pathfind/48.stats'),
	read_file("$tmp/test.48.stats"),
	'stats file correct'
);

# test 49
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-qc", "passed" );
$exp_out = read_file('t/data/pathfind/49.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 50
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-qc", "failed" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::NoMatches', 'correct error thrown';

# test 51
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-qc", "pending" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::NoMatches', 'correct error thrown';

# test 52
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-a" );
$exp_out = read_file('t/data/pathfind/52.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "pathfind_5477_6_1.tar.gz", 'archive exists');
ok(check_links("pathfind_5477_6_1.tar.gz", $exp_out, 1), 'correct files present');

# test 53
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/53.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 54
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-l" );
$exp_out = read_file('t/data/pathfind/54.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "pathfind_5477_6_1", 'symlink dir exists' );
ok( check_links('pathfind_5477_6_1', $exp_out, 1), 'correct files symlinked' );

# test 55
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/55.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 56
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-f", "fastq" );
$exp_out = read_file('t/data/pathfind/56.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 57
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-f", "fastq", "-a" );
$exp_out = read_file('t/data/pathfind/57.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "pathfind_5477_6_1.tar.gz", 'archive exists');
ok(check_links('pathfind_5477_6_1.tar.gz', $exp_out, 1), 'correct files present');

# test 58
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-f", "fastq", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/58.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 59
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-f", "fastq", "-l");
$exp_out = read_file('t/data/pathfind/59.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "pathfind_5477_6_1", 'symlink dir exists' );
ok( check_links('pathfind_5477_6_1', $exp_out, 1), 'correct files symlinked' );

# test 60
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-f", "fastq", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/60.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 61
@args = ( "--test", "-t", "lane", "-i", "invalid_value" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::NoMatches', 'correct error thrown';

# test 62
@args = ( "--test", "-t", "study" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 63
@args = ( "--test", "-t", "study", "-f", "bam", "-l", "$tmp/valid_dest" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 64
@args = ( "--test", "-t", "study", "-i", "3" );
$exp_out = read_file('t/data/pathfind/64.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 65
@args = ( "--test", "-t", "study", "-i", "3", "-s", "$tmp/test.65.stats" );
$exp_out = read_file('t/data/pathfind/65.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check  stats file
is(
	read_file('t/data/pathfind/65.stats'),
	read_file("$tmp/test.65.stats"),
	'stats file correct'
);

# test 66
@args = ( "--test", "-t", "study", "-i", "3", "-qc", "passed" );
$exp_out = read_file('t/data/pathfind/66.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 67
@args = ( "--test", "-t", "study", "-i", "3", "-qc", "failed" );
$exp_out = read_file('t/data/pathfind/67.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 68
@args = ( "--test", "-t", "study", "-i", "3", "-qc", "pending" );
$exp_out = read_file('t/data/pathfind/68.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 69
@args = ( "--test", "-t", "study", "-i", "3", "-a" );
$exp_out = read_file('t/data/pathfind/69.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "pathfind_3.tar.gz", 'archive exists');
ok(check_links('pathfind_3.tar.gz', $exp_out, 1), 'correct files present');

# test 70
@args = ( "--test", "-t", "study", "-i", "3", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/70.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 71
@args = ( "--test", "-t", "study", "-i", "3", "-l" );
$exp_out = read_file('t/data/pathfind/71.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "pathfind_3", 'symlink dir exists' );
ok( check_links('pathfind_3', $exp_out, 1), 'correct files symlinked' );

# test 72
@args = ( "--test", "-t", "study", "-i", "3", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/72.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
#my $ls = `ls $tmp/valid_dest/`;
#print STDERR $ls;
ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 73
@args = ( "--test", "-t", "study", "-i", "3", "-f", "fastq" );
$exp_out = read_file('t/data/pathfind/73.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# test 74
@args = ( "--test", "-t", "study", "-i", "3", "-f", "fastq", "-a" );
$exp_out = read_file('t/data/pathfind/74.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "pathfind_3.tar.gz", 'archive exists');
ok(check_links('pathfind_3.tar.gz', $exp_out, 1), 'correct files present');

# test 75
@args = ( "--test", "-t", "study", "-i", "3", "-f", "fastq", "-a", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/75.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check archive
ok(-e "$tmp/valid_dest.tar.gz", 'archive exists');
ok(check_links('valid_dest.tar.gz', $exp_out), 'correct files present');

# test 76
@args = ( "--test", "-t", "study", "-i", "3", "-f", "fastq", "-l" );
$exp_out = read_file('t/data/pathfind/76.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "pathfind_3", 'symlink dir exists' );
ok( check_links('pathfind_3', $exp_out, 1), 'correct files symlinked' );

# test 77
@args = ( "--test", "-t", "study", "-i", "3", "-f", "fastq", "-l", "$tmp/valid_dest" );
$exp_out = read_file('t/data/pathfind/77.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check symlinks
ok( -e "$tmp/valid_dest", 'symlink dir exists' );
ok( check_links('valid_dest', $exp_out), 'correct files symlinked' );

# test 78
@args = ( "--test", "-t", "study", "-i", "invalid_value" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::NoMatches', 'correct error thrown';

# test 79
@args = ( "--test", "-t", "invalid_value" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 80
@args = ( "--test", "-t", "species", "-i", "strep", "-f", "bam", "-l", "-a" );
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
throws_ok {$obj->run} 'Path::Find::Exception::InvalidInput', 'correct error thrown';

# test 81
@args = ( "--test", "-t", "study", "-i", "3", "-a", "$tmp/test_stats" );
$exp_out = read_file('t/data/pathfind/65.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check stats inside archive
ok( -e "$tmp/test_stats.tar.gz", 'archive exists');
my $owd = getcwd();
chdir($tmp);
system("tar xvfz test_stats.tar.gz");
chdir($owd);
ok( -e "$tmp/test_stats/stats.csv", 'stats file exists' );
compare_ok("$tmp/test_stats/stats.csv", "t/data/pathfind/65.stats", "archived stats correct");

# test 82 : test renaming of links
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-l", "$tmp/test82", "-r" );
$exp_out = read_file('t/data/pathfind/47.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

# check links
ok( -e "$tmp/test82/5477_6_1_1.fastq.gz", 'correct symlink name' );
ok( -e "$tmp/test82/5477_6_1_2.fastq.gz", 'correct symlink name' );

# test 83 : symlinks should be created to fastq.gz files if file type not specified for a lane
@args = ( "--test", "-t", "lane", "-i", "5477_6#1", "-symlink", "$tmp/test_83");
$exp_out = read_file('t/data/pathfind/47.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok(-l "$tmp/test_83/5477_6#1_1.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_83/5477_6#1_2.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(!(-l "$tmp/test_83/pool_1.fastq.gz"), 'symlink not created to pool file when no file type specified');


# test 84 : symlinks should be created to fastq.gz files if file type not specified for a study
@args = ( "--test", "-t", "study", "-i", "3", "-symlink", "$tmp/test_84");
$exp_out = read_file('t/data/pathfind/64.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok(-l "$tmp/test_84/5477_6#1_1.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_84/5477_6#1_2.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_84/5477_6#2_1.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_84/5477_6#2_2.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_84/5477_6#3_1.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_84/5477_6#3_2.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_84/5477_6#4_1.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_84/5477_6#4_2.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(!(-l "$tmp/test_84/pool_1.fastq.gz"), 'symlink not created to pool file when no file type specified');


# test 85 : symlinks should be created to fastq.gz files if file type not specified for a study
@args = ( "--test", "-t", "file", "-i", "t/data/pathfind/path_lanes.txt", "-l", "$tmp/test_85" );
$exp_out = read_file('t/data/pathfind/85.txt');
$obj = Path::Find::CommandLine::Path->new(args => \@args, script_name => $script_name);
$arg_str = join(" ", @args);
stdout_is { $obj->run } $exp_out, "Correct results for '$arg_str'";

ok(-l "$tmp/test_85/5477_6#1_1.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_85/5477_6#1_2.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_85/5477_6#2_1.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(-l "$tmp/test_85/5477_6#2_2.fastq.gz", 'symlinks created to fastq files when no file type specified');
ok(!(-l "$tmp/test_85/pool_1.fastq.gz"), 'symlink not created to pool file when no file type specified');

remove_tree($tmp);
done_testing();

sub check_links {
	my ($n, $fl, $cwd) = @_;

	my $tar = $n =~ /\.tar\.gz/ ? 1 : 0;
	my $owd = getcwd();
	chdir($tmp) unless($cwd);

	my $dir = $n;
	if($tar){
		system("tar xvfz $n");
		$dir =~ s/\.tar\.gz//;
	}

	my @exp_files = exp_files($fl);
	my $result = 1;
	foreach my $f (@exp_files){
		$result = 0 unless( -e "$dir/$f" );
	}
	chdir($owd) unless($cwd);

	# remove stuff
	unlink($n) if( $tar );
	remove_tree( $dir );

	return $result;
}

sub exp_files {
	my $fl = shift;
	
	my $default_type = "*.fastq.gz";
	my @ef;

	foreach my $f (split( "\n", $fl )){
		my @d = split("/", $f);
		my $e = pop @d;
		if( $e =~ /\./ ){
			#$e =~ s/[^\w\.]+/_/g;
			push(@ef, $e);
		}
		else{
			my @all = glob("$f/$default_type");
			foreach my $a ( @all ){
				my @dirs = split('/', $a);
				my $fn = pop @dirs;
				#$fn =~ s/[^\w\.]+/_/g;
				push( @ef, $fn );
			}
		}
	}



	return @ef;
}