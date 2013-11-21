package Path::Find::CommandLine::Path;

# ABSTRACT: Given a lane id, this script returns the location on disk of the relevant files

=head1 NAME

Path::Find::CommandLine::Path

=head1 SYNOPSIS

	use Path::Find::CommandLine::Path;
	my $pipeline = Path::Find::CommandLine::Path->new(
		script_name => 'pathfind',
		args        => \@ARGV
	)->run;

where \@ARGV follows the following parameters:

-t|type		<study|lane|file|sample|species>
-i|id		<study id|study name|lane name|file of lane names>
-h|help		<help message>
-f|filetype	<fastq|bam>
-l|symlink	<create sym links to the data and define output directory>
-a|archive	<name for archive containing the data>
-s|stats	<output statistics>
-q|qc		<passed|failed|pending>

=head1 CONTACT

path-help@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

use Data::Dumper;
use Cwd;
use lib "/software/pathogen/internal/pathdev/vr-codebase/modules"
  ;    #Change accordingly once we have a stable checkout

use lib "/software/pathogen/internal/prod/lib";
use lib "../lib";
use Getopt::Long qw(GetOptionsFromArray);

use Path::Find;
use Path::Find::Lanes;
use Path::Find::Filter;
use Path::Find::Log;
use Path::Find::Linker;
use Path::Find::Stats::Generator;

has 'args'        => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'script_name' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'type'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'qc'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'filetype'    => ( is => 'rw', isa => 'Str',      required => 0 );
has 'archive'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'stats'       => ( is => 'rw', isa => 'Str',      required => 0 );
has 'symlink'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'output'      => ( is => 'rw', isa => 'Str',      required => 0 );
has 'help'        => ( is => 'rw', isa => 'Str',      required => 0 );

sub BUILD {
    my ($self) = @_;

    my ( $type, $id, $qc, $filetype, $archive, $stats, $symlink, $output,
        $help );

    my @args = @{ $self->args };
	GetOptionsFromArray(
	    \@args,
        't|type=s'     => \$type,
        'i|id=s'       => \$id,
        'f|filetype=s' => \$filetype,
        'l|symlink:s'  => \$symlink,    # ':' means arg is optional
        'a|archive:s'  => \$archive,
        's|stats:s'    => \$stats,
        'q|qc=s'       => \$qc,
        'h|help'       => \$help
    );

    $self->type($type)         if ( defined $type );
    $self->id($id)             if ( defined $id );
    $self->qc($qc)             if ( defined $qc );
    $self->filetype($filetype) if ( defined $filetype );
    $self->archive($archive)   if ( defined $archive );
    $self->stats($stats)       if ( defined $stats );
    $self->symlink($symlink)   if ( defined $symlink );
    $self->output($output)     if ( defined $output );
    $self->help($help)         if ( defined $help );

    (
             $type
          && $id
          && $id ne ''
          && ( $type eq 'study'
            || $type eq 'lane'
            || $type eq 'file'
            || $type eq 'sample'
            || $type eq 'species'
            || $type eq 'database' )
          && (
            !$qc
            || ( $qc
                && ( $qc eq 'passed' || $qc eq 'failed' || $qc eq 'pending' ) )
          )
          && ( !$filetype
            || ( $filetype && ( $filetype eq 'bam' || $filetype eq 'fastq' ) ) )
    ) or die $self->usage_text;
}

sub run {
    my ($self) = @_;

    # assign variables
    my $type     = $self->type;
    my $id       = $self->id;
    my $qc       = $self->qc;
    my $filetype = $self->filetype;
    my $archive  = $self->archive;
    my $stats    = $self->stats;
    my $symlink  = $self->symlink;
    my $output   = $self->output;

    eval {
        Path::Find::Log->new(
            logfile => '/nfs/pathnfs05/log/pathfindlog/pathfind.log',
            args    => $self->args
        )->commandline();
    };

    die "The archive and symlink options cannot be used together\n"
      if ( defined $archive && defined $symlink );

    # set file type extension regular expressions
    my %type_extensions = (
        fastq => '*.fastq.gz',
        bam   => '*.bam'
    );

    my $lane_filter;
    my $found = 0;

    # Get databases and loop through
    my @pathogen_databases = Path::Find->pathogen_databases;
    for my $database (@pathogen_databases) {

        # Connect to database and get info
        my ( $pathtrack, $dbh, $root ) = Path::Find->get_db_info($database);

        # find matching lanes
        my $find_lanes = Path::Find::Lanes->new(
            search_type    => $type,
            search_id      => $id,
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 1
        );
        my @lanes = @{ $find_lanes->lanes };

        unless (@lanes) {
            $dbh->disconnect();
            next;
        }

        # filter lanes
        $lane_filter = Path::Find::Filter->new(
            lanes           => \@lanes,
            filetype        => $filetype,
            qc              => $qc,
            root            => $root,
            pathtrack       => $pathtrack,
            type_extensions => \%type_extensions
        );
        my @matching_lanes = $lane_filter->filter;

      # Set up to symlink/archive. Check whether default filetype should be used
        my $use_default = 0;
        $use_default = 1 if ( !defined $filetype );
        if ( $lane_filter->found && ( defined $symlink || defined $archive ) ) {
            my $name;
            if ( defined $symlink ) {
                $name = $symlink;
            }
            elsif ( defined $archive ) {
                $name = $archive;
            }
            $name = "pathfind_$id" if ( $name eq '' );

            my $linker = Path::Find::Linker->new(
                lanes            => \@matching_lanes,
                name             => $name,
                use_default_type => $use_default,
				script_name      => $self->script_name
            );

            $linker->sym_links if ( defined $symlink );
            $linker->archive   if ( defined $archive );
        }

	if(@matching_lanes){
	    foreach my $ml (@matching_lanes) {
		my $l = $ml->{path};
		print "$l\n";
	    }
	    $found = 1;
	}

        $dbh->disconnect();

        #no need to look in the next database if relevant data has been found
        if ( $lane_filter->found ) {
            if ( defined $stats ) {
                $stats = "$id.csv" if ( $stats eq '' );
                $stats =~ s/\s+/_/g;
                Path::Find::Stats::Generator->new(
                    lane_hashes => \@matching_lanes,
                    output      => $stats,
                    vrtrack     => $pathtrack
                )->pathfind;
            }
            return 1;
        }
    }
	
    unless ( $found ) {
        print "Could not find lanes or files for input data \n";
    }
}

sub usage_text {
    my ($self) = @_;
    my $script_name = $self->script_name;
    print <<USAGE;
Usage: $script_name
		-t|type		<study|lane|file|sample|species>
		-i|id		<study id|study name|lane name|file of lane names>
		-h|help		<this help message>
		-f|filetype	<fastq|bam>
		-l|symlink	<create sym links to the data and define output directory>
		-a|archive	<name for archive containing the data>
		-s|stats	<output statistics>
		-q|qc		<passed|failed|pending>    

	Given a study, lane or a file containing a list of lanes, this script will output the path (on pathogen disk) to the data associated with the specified study or lane. 
	Using the option -qc (passed|failed|pending) will limit the results to data of the specified qc status. 
	Using the option -filetype (fastq or bam) will return the path to the files of this type for the given data. 
	Using the option -symlink will create a symlink to the queried data in the current directory, alternativley an output directory can be specified in which the symlinks will be created.
	Similarly, the archive option will create and archive (.tar.gz) of the data under a default file name unless one is specified.
USAGE
    exit;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
