package Path::Find::CommandLine::Assembly;

# ABSTRACT: Given a lane id, this script returns the location on disk of the requested assembly files

=head1 NAME

Path::Find::CommandLine::Assembly

=head1 SYNOPSIS

	use Path::Find::CommandLine::Assembly;
	my $pipeline = Path::Find::CommandLine::Assembly->new(
		script_name => 'assemblyfind',
		args        => \@ARGV
	)->run;
	
where \@ARGV follows the following parameters:

-t|type            <study|lane|file|sample|species>
-i|id              <study id|study name|lane name|file of lane names>
-f|filetype        <contigs|scaffold>
-l|symlink         <create a symlink to the data>
-a|archive         <create archive of the data>
-s|stats           <create a CSV file containing assembly stats>
-h|help            <print help message>

=head1 METHODS



=head1 CONTACT

path-help@sanger.ac.uk

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

use Cwd;
use Data::Dumper;

#Change accordingly once we have a stable checkout
use lib "/software/pathogen/internal/pathdev/vr-codebase/modules";

#use lib "/software/pathogen/internal/prod/lib";
use lib "../lib";

use Getopt::Long qw(GetOptionsFromArray);

use Bio::MLST::Databases;
use File::Temp;
use File::chdir;
use File::Copy qw(move);

use Path::Find;
use Path::Find::Lanes;
use Path::Find::Filter;
use Path::Find::Linker;
use Path::Find::Log;
use Path::Find::Stats::Generator;
use Path::Find::Sort;
use Path::Find::Exception;

has 'args'        => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'script_name' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'type'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'symlink'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'stats'       => ( is => 'rw', isa => 'Str',      required => 0 );
has 'filetype'    => ( is => 'rw', isa => 'Str',      required => 0 );
has 'archive'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'help'        => ( is => 'rw', isa => 'Str',      required => 0 );
has '_environment' => ( is => 'rw', isa => 'Str',     required => 0, default => 'prod' );

sub BUILD {
    my ($self) = @_;

    my ( $type, $id, $symlink, $stats, $filetype, $archive, $help, $test );

    my @args = @{ $self->args };
    GetOptionsFromArray(
        \@args,
        't|type=s'     => \$type,
        'i|id=s'       => \$id,
        'h|help'       => \$help,
        'f|filetype=s' => \$filetype,
        'l|symlink:s'  => \$symlink,
        'a|archive:s'  => \$archive,
        's|stats:s'    => \$stats,
        'test'         => \$test,
    );

    $self->type($type)         if ( defined $type );
    $self->id($id)             if ( defined $id );
    $self->symlink($symlink)   if ( defined $symlink );
    $self->stats($stats)       if ( defined $stats );
    $self->filetype($filetype) if ( defined $filetype );
    $self->archive($archive)   if ( defined $archive );
    $self->help($help)         if ( defined $help );
    $self->_environment('test') if ( defined $test );
}

sub check_inputs{
    my $self = shift;
    return(
             $self->type
          && $self->id
          && $self->id ne ''
          && !$self->help
          && ( $self->type eq 'study'
            || $self->type eq 'lane'
            || $self->type eq 'file'
            || $self->type eq 'sample'
            || $self->type eq 'species'
            || $self->type eq 'database' )
          && (
            !$self->filetype
            || (
                $self->filetype
                && (   $self->filetype eq 'contigs'
                    || $self->filetype eq 'scaffold' )
            )
          )
          && ( !defined($self->archive)
            || $self->archive eq ''
            || ( $self->archive && !( $self->stats || $self->symlink ) ) )
    );
}

sub run {
    my ($self) = @_;
    $self->check_inputs or Path::Find::Exception::InvalidInput->throw( error => $self->usage_text);

    my ( $qc, $destination, $tmpdirectory_name, $archive_name,
        $all_stats, $archive_path, $archive_suffix );

    # assign variables
    my $type     = $self->type;
    my $id       = $self->id;
    my $symlink  = $self->symlink;
    my $stats    = $self->stats;
    my $filetype = $self->filetype;
    my $archive  = $self->archive;

    Path::Find::Exception::FileDoesNotExist->throw( error => "File $id does not exist.\n") if( $type eq 'file' && !-e $id );
    my $found = 0;

    my $logfile = $self->_environment eq 'test' ? '/nfs/pathnfs05/log/pathfindlog/test/assemblyfind.log' : '/nfs/pathnfs05/log/pathfindlog/assemblyfind.log';
    eval {
        Path::Find::Log->new(
            logfile => $logfile,
            args    => $self->args
        )->commandline();
    };


    # Set assembly subdirectories
    my @sub_directories;
    if ($filetype) {
        @sub_directories = (
            '/velvet_assembly', '/velvet_assembly_with_reference',
            '/spades_assembly'
        );
    }
    else {
        $filetype        = 'scaffold';
        @sub_directories = (
            '/velvet_assembly', '/velvet_assembly_with_reference',
            '/spades_assembly'
        );
    }

    # set file type extension wildcard
    my %type_extensions = (
        contigs  => 'unscaffolded_contigs.fa',
        scaffold => 'contigs.fa',
    );

    my $lane_filter;

    # Get databases
    my $find = Path::Find->new( environment => $self->_environment );
    my @pathogen_databases = $find->pathogen_databases;
    for my $database (@pathogen_databases) {

        # Connect to database and get info
        my ( $pathtrack, $dbh, $root ) = $find->get_db_info($database);

        my $find_lanes = Path::Find::Lanes->new(
            search_type    => $type,
            search_id      => $id,
            pathtrack      => $pathtrack,
            dbh            => $dbh,
            processed_flag => 1024
        );
        my @lanes = @{ $find_lanes->lanes };

        unless (@lanes) {
            $dbh->disconnect();
            next;
        }

        # check directories exist, find & filter by file type
        if ( ( defined $symlink || defined $archive ) && !defined $filetype ) {
            $filetype = "contigs";
        }
        my @req_stats;
        @req_stats = ( 'contigs.fa.stats', 'contigs.mapped.sorted.bam.bc' )
          if ( defined $stats );
        $lane_filter = Path::Find::Filter->new(
            lanes           => \@lanes,
            filetype        => $filetype,
            type_extensions => \%type_extensions,
            root            => $root,
            pathtrack       => $pathtrack,
            subdirectories  => \@sub_directories,
            stats           => \@req_stats
        );
        my @matching_lanes = $lane_filter->filter;

        my $sorted_ml = Path::Find::Sort->new(lanes => \@matching_lanes)->sort_lanes;
        @matching_lanes = @{ $sorted_ml };

      # symlink or archive
      # Set up to symlink/archive. Check whether default filetype should be used
        my $use_default = 0;
        $use_default = 1 if ( !defined $filetype );
        if ( $lane_filter->found && ( defined $symlink || defined $archive ) ) {
            my $name = $self->set_linker_name;

            my %link_names = $self->link_rename_hash( \@matching_lanes );

            my $linker = Path::Find::Linker->new(
                lanes            => \@matching_lanes,
                name             => $name,
                use_default_type => $use_default,
                rename_links     => \%link_names
            );

            $linker->sym_links if ( defined $symlink );
            $linker->archive   if ( defined $archive );
        }

        # print out the paths
        foreach my $ml (@matching_lanes) {
            my $l = $ml->{path};
            print "$l\n";
        }

        $dbh->disconnect();

        #no need to look in the next database if relevant data has been found
        if ( $lane_filter->found ) {
	    $found = 1;
            if ( defined $stats ) {
                $stats = "$id.assembly_stats.csv" if ( $stats eq '' );
                $stats =~ s/\s+/_/g;
                Path::Find::Stats::Generator->new(
                    lane_hashes => \@matching_lanes,
                    output      => $stats,
                    vrtrack     => $pathtrack
                )->assemblyfind;

            }
            return 1;
        }
    }

    unless ( $found ) {
        Path::Find::Exception::NoMatches->throw( error => "Could not find lanes or files for input data\n");
    }
}

sub set_linker_name {
    my  ($self) = @_;
    my $archive = $self->archive;
    my $symlink = $self->symlink;
    my $id = $self->id;
    my $script_path = $self->script_name;
    $script_path =~ /([^\/]+$)/;
    my $script_name = $1;

    my $name;
    if ( defined $symlink ) {
        $name = $symlink;
    }
    elsif ( defined $archive ) {
        $name = $archive;
    }

    if( $name eq '' ){
        $id =~ /([^\/]+$)/;
        $name = $script_name . "_" . $1;
    }
    my $cwd = getcwd;
    if($name =~ /^\//){
        return $name;
    }
    else{
        return "$cwd/$name";
    }
}

sub link_rename_hash {
    my ( $self, $mlanes) = @_;
    my @matching_lanes = @{$mlanes};

    my %suffixes = (
        'velvet_assembly'                => '_velvet.fa',
        'velvet_assembly_with_reference' => '_columbus.fa',
        'spades_assembly'                => '_spades.fa',
        'scaffolding_results'            => '_scaffolded.fa'
    );

    my %link_names;
    foreach my $mf (@matching_lanes) {
        my $lane      = $mf->{path};
        my @dirs      = split( "/", $lane );
        my $filename  = pop @dirs;
        my $subdir    = pop @dirs;
        my $lane_name = pop @dirs;
        my $suffix    = $suffixes{$subdir};

        $filename =~ s/\.fa/$suffix/;
        my $sf = $link_names{$lane} = "$lane_name.$filename";
    }

    return %link_names;
}

sub usage_text {
    my ($self) = @_;
    my $script_name = $self->script_name;
    print <<USAGE;
Usage: $script_name
     -t|type            <study|lane|file|sample|species>
     -i|id              <study id|study name|lane name|file of lane names>
     -f|filetype        <contigs|scaffold>
     -l|symlink         <create a symlink to the data>
     -a|archive         <create archive of the data>
     -s|stats           <create a CSV file containing assembly stats>
     -h|help            <print this message>

Given a study, lane or a file containing a list of lanes, this script will output the path (on pathogen disk) to the data associated with the specified study or lane. 
Using the option -l|symlink will create a symlink to the queried data in a default directory created in the current directory, alternativley an output directory can be specified in which the symlinks will be created.
Using the option -a|archive will create an archive (.tar.gz) containing the selected assemblies. The -archive option will automatically name the archive file if a name is not supplied.

Note: scaffolds are returned as default. -f contigs will return all unscaffolded contigs.

# find an assembly for a given lane
assemblyfind -t lane -i 1234_5#6

# find contigs for a given lane
assemblyfind -t lane -i 1234_5#6 -f contigs

# create a CSV file of assembly statistics for all assemblies in the given study
assemblyfind -t study -i 123 -s my_assembly_stats.csv

# create symlinks to all the final assemblies in the given study
assemblyfind -t study -i "My study" -l
assemblyfind -t study -i "My study" -l my_symlinks

# create a compressed archive containing all assemblies for a study and a CSV file of assembly statistics
assemblyfind -t study -i 123 -a 
assemblyfind -t study -i 123 -a study_123_assemblies.tgz


USAGE
    exit;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

