package Path::Find::CommandLine::Ref;

# ABSTRACT: Given a species return a the location of the references that match

=head1 NAME

Path::Find::CommandLine::Ref

=head1 SYNOPSIS

	use Path::Find::CommandLine::Ref;
	my $pipeline = Path::Find::CommandLine::Ref->new(
		script_name => 'reffind',
		args        => \@ARGV
	)->run;

where \@ARGV uses the following parameters:
-t|type            <species|file>
-i|id              <species name|species regex|file name>
-f|filetype        <fa|gff|embl|annotation>
-l|symlink         <create a symlink to the data>
-a|archive         <create an archive of the data>
-h|help            <print help message>

=head1 CONTACT

path-help@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
no warnings 'uninitialized';
use Moose;

use lib "/software/pathogen/internal/prod/lib";
use lib "../lib";

use Data::Dumper;

use Cwd;
use Cwd 'abs_path';
use Getopt::Long qw(GetOptionsFromArray);
use Path::Find::Linker;
use Path::Find::Log;

has 'args'        => ( is => 'ro', isa => 'ArrayRef', required => 1 );
has 'script_name' => ( is => 'ro', isa => 'Str',      required => 1 );
has 'type'        => ( is => 'rw', isa => 'Str',      required => 0 );
has 'id'          => ( is => 'rw', isa => 'Str',      required => 0 );
has 'filetype'    => ( is => 'rw', isa => 'Str',      required => 0 );
has 'symlink'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'archive'     => ( is => 'rw', isa => 'Str',      required => 0 );
has 'help'        => ( is => 'rw', isa => 'Str',      required => 0 );

sub BUILD {
    my ($self) = @_;

    my ( $type, $id, $filetype, $symlink, $archive, $help );

    my @args = @{ $self->args };
    GetOptionsFromArray(
        \@args,
        't|type=s'     => \$type,
        'i|id=s'       => \$id,
        'f|filetype=s' => \$filetype,
        'l|symlink:s'  => \$symlink,
        'a|archive:s'  => \$archive,
        'h|help'       => \$help,
    );

    $self->type($type)         if ( defined $type );
    $self->id($id)             if ( defined $id );
    $self->filetype($filetype) if ( defined $filetype );
    $self->symlink($symlink)   if ( defined $symlink );
    $self->archive($archive)   if ( defined $archive );
    $self->help($help)         if ( defined $help );

    (
    !$help &&
     $type &&
             ( $type eq 'species' || $type eq 'file' )
          && $id
          && (
            !$filetype
            || (
                $filetype
                && (   $filetype eq 'fa'
                    || $filetype eq 'gff'
                    || $filetype eq 'embl'
                    || $filetype eq 'annotation' )
            )
          )
    ) or die $self->usage_text;
}

sub run {
    my ($self) = @_;

    # assign variables
    my $type     = $self->type;
    my $id       = $self->id;
    my $filetype = $self->filetype;
    my $symlink  = $self->symlink;
    my $archive  = $self->archive;

    die "File $id does not exist.\n" if( $type eq 'file' && !-e $id );

    eval {
        Path::Find::Log->new(
            logfile => '/nfs/pathnfs05/log/pathfindlog/reffind.log',
            args    => $self->args
        )->commandline();
    };

    die "The archive and symlink options cannot be used together\n"
      if ( defined $archive && defined $symlink );

    my $found = 0;    #assume nothing found

    my $root       = '/lustre/scratch108/pathogen/pathpipe/refs/';
    my $index_file = '/lustre/scratch108/pathogen/pathpipe/refs/refs.index';

    my @species_to_find;
    if ( $type eq 'species' ) {
        push( @species_to_find, $id );
    }
    elsif ( $type eq 'file' ) {
        @species_to_find = $self->parse_species_from_file( $self->id );
    }

    foreach my $species (@species_to_find) {
        my $references = $self->search_index_file_for_directories_and_references( $index_file, $species );
        if ( keys %{$references} >= 1 ) {
            $found = 1;
            my @default_reference_paths = values %{$references};
            my $reference_paths = \@default_reference_paths;
            $reference_paths =  $self->find_files_of_given_type( $references, $filetype ) if ( defined $filetype );
            $reference_paths = $self->remove_duplicates( $reference_paths );
            $self->sym_archive( $reference_paths ) if (( defined $symlink || defined $archive) && defined($reference_paths) );
            $self->print_references( $reference_paths ) if(defined($reference_paths));
        }
    }

    unless ($found) {
        print "Could not find references\n";
    }
    else {
        return 1;
    }
}

sub parse_species_from_file {
    my ( $self, $file_name ) = @_;
    my @sp;
    open( SPECIES, "<", $file_name );
    while ( my $line = <SPECIES> ) {
        chomp $line;
        push( @sp, $line );
    }
    return @sp;
}

sub find_files_of_given_type {
    my ( $self, $references, $filetype ) = @_;
    my @found_files;

    my %exts = (
        fa         => '%p/%r.fa',
        gff        => '%p/%r.gff',
        embl       => '%p/%r.embl',
        annotation => '%p/annotation/%r.gff'
    );

    my $found = 0;
    
    for my $reference_name (keys %{$references})
    {
      my $reference_path = $references->{$reference_name};
      my $current_path_to_reference = $exts{$filetype}."";
      $current_path_to_reference =~ s!%p!$reference_path!i;
      $current_path_to_reference =~ s!%r!$reference_name!i;
      
      if(-e $current_path_to_reference)
      {
        push( @found_files, $current_path_to_reference );
        $found = 1;
      }
    }
    return \@found_files;
}

sub print_references {
    my ( $self, $references ) = @_;
    for my $reference ( @{$references}) {
        print $reference. "\n";
    }
}

sub sym_archive {
    my ( $self, $objects_to_link ) = @_;
    my $symlink = $self->symlink;
    my $archive = $self->archive;
    my $id      = $self->id;

    my $use_default = $self->filetype ? 1 : 0;

    my $name = $self->set_linker_name;

    my $links  = $self->format_for_links($objects_to_link);
    my $linker = Path::Find::Linker->new(
        lanes       => $links,
        name        => $name,
        use_default => $use_default,
		script_name => $self->script_name
    );

    $linker->sym_links if ( defined $symlink );
    $linker->archive   if ( defined $archive );
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

sub format_for_links {
    my ( $self, $objects_to_link ) = @_;

    my @refs;
    foreach my $r ( @{$objects_to_link} ) {
        push( @refs, { path => abs_path($r) } );
    }
    return \@refs;
}

sub search_index_file_for_directories_and_references {
    my ( $self, $index_file, $search_query ) = @_;
    my %search_results;
    $search_query =~ s! !|!gi;

    open( INDEX_FILE, $index_file ) or die 'Couldnt find the refs.index file';
    while (<INDEX_FILE>) {
        chomp;
        my $line = $_;
        if ( $line =~ m/$search_query/i ) {
            if ( $line =~ m!([^\t]+)\t(.+)/[^/]+fa$! ) {
                my $reference_name = $1;
                my $directory = $2;
                if ( -d $directory )
                {
                  $search_results{$reference_name} = $directory;
                }
            }
        }
    }
    close(INDEX_FILE);
    
    # If the reference is found with an exact match, only return that match.
    if(defined($search_results{$search_query}))
    {
      my %exact_match = ($search_query => $search_results{$search_query});
      return \%exact_match;
    }

    return \%search_results;
}

sub remove_duplicates {
    my ( $self, $file_list ) = @_;
    return unless(defined($file_list));
    my %dedup_file_list;

    foreach my $file ( sort @{$file_list} ) {
        $dedup_file_list{$file} = 1;
    }
    my @ks = sort keys %dedup_file_list;
    return \@ks;
}

sub usage_text {
    my ($self) = @_;
    my $script_name = $self->script_name;
    print <<USAGE;
Usage: $script_name
     -t|type            <species|file>
     -i|id              <species name|species regex|file name>
     -f|filetype        <fa|gff|embl|annotation>
     -l|symlink         <create a symlink to the data>
     -a|archive         <create an archive of the data>
     -h|help            <print this message>

Given a species or a partial name of a species, this script will output the path (on pathogen disk) to the reference. 
Using the option -filetype (fa, gff, or embl) will 
return the path to the files of this type for the given data. 
Using the option -l|symlink will create a symlink to the queried data. 
Using the option -a|archive will create an archive of the queried data.
For both -l and -a, a destination may be specified or a default will be created in the current directory.

Examples:
reffind -t species -i bongori -l bongori_links 
creates symlinks in a directory called bongori_links

reffind -t species -i bongori -a 
creates an archive with a default name in the current directory

USAGE
    exit;
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
