package Path::Find::CommandLine::PanGenome;

# ABSTRACT: Create a pan genome from a set of lanes

=head1 NAME

bacteria_pan_genome

=head1 SYNOPSIS

bacteria_pan_genome -t lane -i 1234

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
use File::Path qw(make_path);
use Cwd;
use Path::Find;
use Path::Find::Lanes;
use Path::Find::Filter;
use Path::Find::Log;
use Path::Find::Linker;

has 'args'        => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'script_name' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'type'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'help'        => ( is => 'rw', isa => 'Str',      required => 0 );
has '_job_runner' =>
  ( is => 'rw', isa => 'Str', required => 0, default => 'LSF' );
has 'gff_files'   => ( is => 'rw', isa => 'ArrayRef',  default => sub {[]}  );


sub BUILD {
    my ($self) = @_;
    my ( $type, $id, $job_runner, $help );

    my @args = @{ $self->args };
    GetOptionsFromArray(
        \@args,
        't|type=s'       => \$type,
        'i|id=s'         => \$id,
        'j|job_runner=s' => \$job_runner,
        'h|help'         => \$help
    );

    $self->type($type)              if ( defined $type );
    $self->id($id)                  if ( defined $id );
    $self->_job_runner($job_runner) if ( defined $job_runner );
    $self->help($help)              if ( defined $help );

    my $invalid_file_found = 0;
    for my $filename ( @{ $self->args } ) {
        if ( -e $filename && $filename =~ /\.gff$/) {
          push(@{$self->gff_files}, $filename);
        }
        else
        {
          print "Invalid file: $filename\n";
          $invalid_file_found = 1;
        }
    }


    (
        $type && $id && $id ne '' && ( $type eq 'study'
            || $type eq 'lane'
            || $type eq 'file'
            || $type eq 'sample'
            || $type eq 'species'
            || $type eq 'database' )
    ) && ($invalid_file_found == 0) or die $self->usage_text;
}

sub run {
    my ($self) = @_;

    # assign variables
    my $type       = $self->type;
    my $id         = $self->id;
    my $job_runner = $self->_job_runner;

    eval {
        Path::Find::Log->new(
            logfile => '/nfs/pathnfs05/log/pathfindlog/bacteria_pan_genome.log',
            args    => $self->args
        )->commandline();
    };

    my @sub_directories =
      ( '/velvet_assembly/annotation', '/spades_assembly/annotation' );

    # set file type extension regular expressions
    my %type_extensions = ( gff => '*.gff' );
    my $filetype        = 'gff';
    my $symlink         = 1;

    my $lane_filter;
    my $output_directory = join( '_', ( 'output', $type, $id ) );
    $output_directory =~ s!\W!_!gi;

    print
"Creating pan genome. If you kill this process it will stop. How long it takes depends on how many samples there are and how busy the farm is.\n";

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
            processed_flag => 2048
        );
        my @lanes = @{ $find_lanes->lanes };

        unless (@lanes) {
            $dbh->disconnect();
            next;
        }

        # check directories exist, find & filter by file type
        $lane_filter = Path::Find::Filter->new(
            lanes           => \@lanes,
            filetype        => $filetype,
            type_extensions => \%type_extensions,
            root            => $root,
            pathtrack       => $pathtrack,
            subdirectories  => \@sub_directories
        );
        my @matching_lanes = $lane_filter->filter;
        unless ( $lane_filter->found ) {
            $dbh->disconnect();
            next;
        }

        my $cwd = getcwd();

        # symlink
        my %link_names = $self->link_rename_hash( \@matching_lanes );

        Path::Find::Linker->new(
            lanes            => \@matching_lanes,
            name             => $output_directory,
            use_default_type => 0,
            rename_links     => \%link_names
        )->sym_links;

        my $extra_gff_files = join(" ", $self->gff_files);
        `cd $output_directory; create_pan_genome --job_runner $job_runner *.gff $extra_gff_files`;

        chdir($cwd);
        $dbh->disconnect();

        #no need to look in the next database if relevant data has been found
        return 1 if ( $lane_filter->found );
    }

    unless ( $lane_filter->found ) {
        print "Could not find lanes or files for input data \n";
    }
}

sub link_rename_hash {
    my ( $self, $mlanes ) = @_;
    my @matching_lanes = @{$mlanes};
    my %link_names;
    foreach my $l (@matching_lanes) {
        my $p = $l->{path};
        $link_names{$p} = $self->get_lane_from_path($p);
    }
    return %link_names;
}

sub get_lane_from_path {
    my ( $self, $path ) = @_;
    $path =~ /([^\/]+)\/velvet/;
    return "$1.gff";
}

sub usage_text {
    print <<USAGE;
Create a pan genome from a set of lanes
Usage: bacteria_pan_genome
	-t|type		<study|lane|file|sample|species>
	-i|id		<study id|study name|lane name|file of lane names>
	-h|help		<this help message>

# On all lanes in a study
bacteria_pan_genome -t study -i 1234

# On all lanes in a file
bacteria_pan_genome -t file -i example.txt

# On all lanes in a multiplexed run
bacteria_pan_genome -t lane -i 1234_5

# On all lanes in a file plus other GFF files in the directory
bacteria_pan_genome -t file -i example.txt *.gff

USAGE
    exit;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
