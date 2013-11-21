# ABSTRACT: Generate cells for statistics spreadsheets

=head1 NAME

Path::Find::Stats::Row;

=head1 SYNOPSIS

	use Path::Find::Stats::Row;
	my $row = Path::Find::Stats::Row->new(
		vrtrack => $vrtrack,
		lane    => $vrtrack_lane,
		bamcheck => '/path/to/bamcheck/file.bc'
	);
   
	print $row->reads_mapped;
	print $row->bases_mapped;

=head1 CONTACT

path-help@sanger.ac.uk

=head1 METHODS

=cut

package Path::Find::Stats::Row;

use Moose;
use VRTrack::VRTrack;    # Includes Lane, Mapstats, Etc.
use VertRes::Parser::bamcheck;

has 'vrtrack'    => ( is => 'ro', isa => 'VRTrack::VRTrack',         required => 1 );    # database
has 'lane'       => ( is => 'ro', isa => 'VRTrack::Lane',            required => 1 );    # lane
has 'mapstats'   => ( is => 'ro', isa => 'Maybe[VRTrack::Mapstats]', required => 0 );    # mapstats
has 'stats_file' => ( is => 'ro', isa => 'Str',                      required => 0 );    # assembly stats file
has 'bamcheck'   => ( is => 'ro', isa => 'Str',                      required => 0 );    # assembly bamcheck file
has 'gff_file'	 => ( is => 'ro', isa => 'Str',                      required => 0 );

# Checks
has 'is_qc_mapstats'      => ( is => 'ro', isa => 'Bool',        lazy_build => 1 );    # qc or mapping mapstats.
has 'is_mapping_complete' => ( is => 'ro', isa => 'Maybe[Bool]', lazy_build => 1 );    # Mapping completed

# Internals
has '_vrtrack_project'      => ( is => 'ro', isa => 'VRTrack::Project',          lazy_build => 1 );    # Assembly - from mapststs
has '_vrtrack_sample'       => ( is => 'ro', isa => 'VRTrack::Sample',           lazy_build => 1 );    # Mapper - from mapstats
has '_vrtrack_assembly'     => ( is => 'ro', isa => 'VRTrack::Assembly',         lazy_build => 1 );    # Assembly - from mapststs
has '_vrtrack_mapper'       => ( is => 'ro', isa => 'VRTrack::Mapper',           lazy_build => 1 );    # Mapper - from mapstats
has '_bamcheck_obj'         => ( is => 'ro', isa => 'Maybe[VertRes::Parser::bamcheck]', lazy_build => 1 );    # Bamcheck - for assemblies
has '_basic_assembly_stats' => ( is => 'ro', isa => 'HashRef',                   lazy_build => 1 );

# Cells
# Mapping
# REQUIRES: VRTrack::Mapstats object
has 'study_id'             => ( is => 'ro', isa => 'Int',        lazy_build => 1 );    # study ssid
has 'sample'               => ( is => 'ro', isa => 'Str',        lazy_build => 1 );    # sample name
has 'lanename'             => ( is => 'ro', isa => 'Str',        lazy_build => 1 );    # lane name
has 'cycles'               => ( is => 'ro', isa => 'Int',        lazy_build => 1 );    # cycles/readlength
has 'reads'                => ( is => 'ro', isa => 'Int',        lazy_build => 1 );    # lane yield (reads)
has 'bases'                => ( is => 'ro', isa => 'Int',        lazy_build => 1 );    # lane yield (bases)
has 'map_type'             => ( is => 'ro', isa => 'Str',        lazy_build => 1 );    # qc or mapping reported value
has 'reference'            => ( is => 'ro', isa => 'Str',        lazy_build => 1 );    # reference name
has 'reference_size'       => ( is => 'ro', isa => 'Int',        lazy_build => 1 );    # reference size
has 'mapper'               => ( is => 'ro', isa => 'Str',        lazy_build => 1 );    # mapper name
has 'mapstats_id'          => ( is => 'ro', isa => 'Int',        lazy_build => 1 );    # mapstats id
has 'adapter_perc'         => ( is => 'rw', isa => 'Maybe[Num]', lazy_build => 1 );    # percent adaptor reads
has 'transposon_perc'      => ( is => 'rw', isa => 'Maybe[Num]', lazy_build => 1 );    # percent transposon reads
has 'mapped_perc'          => ( is => 'ro', isa => 'Num',        lazy_build => 1 );    # percent mapped reads
has 'paired_perc'          => ( is => 'ro', isa => 'Num',        lazy_build => 1 );    # percent paired reads
has 'mean_insert_size'     => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # mean insert size
has 'genome_covered'       => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # genome covered QC
has 'genome_covered_1x'    => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # genome covered Mapping
has 'genome_covered_5x'    => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # ditto
has 'genome_covered_10x'   => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # ditto
has 'genome_covered_50x'   => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # ditto
has 'genome_covered_100x'  => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # ditto
has 'depth_of_coverage'    => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # mean depth of coverage
has 'depth_of_coverage_sd' => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # mean depth of coverage sd
has 'duplication_rate'     => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # duplication rate qc
has 'error_rate'           => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );    # error rate qc
has 'npg_qc'               => ( is => 'ro', isa => 'Maybe[Str]', lazy_build => 1 );    # npg qc
has 'manual_qc'            => ( is => 'ro', isa => 'Maybe[Str]', lazy_build => 1 );    # manual qc
# END: VRTrack::Mapstats object

# Assembly
# REQUIRES: assembly stats file
has 'assembly_type'         => ( is => 'ro', isa => 'Maybe[Str]', lazy_build => 1 );
has 'total_length'          => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'num_contigs'           => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'average_contig_length' => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'largest_contig'        => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n50'                   => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n50_n'                 => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n60'                   => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n60_n'                 => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n70'                   => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n70_n'                 => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n80'                   => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n80_n'                 => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n90'                   => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n90_n'                 => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n100'                  => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n100_n'                => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'n_count'               => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
# END: assembly stats file

# REQUIRES: bamcheck file
has 'sequences'          => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'reads_mapped'       => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'reads_unmapped'     => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'reads_paired'       => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'reads_unpaired'     => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'raw_bases'          => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'bases_mapped'       => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'bases_mapped_cigar' => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'avg_length'         => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'max_length'         => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'avg_qual'           => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'avg_insert_size'    => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'sd_insert_size'     => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
# END: bamcheck file

# Annotation
# REQUIRES: GFF file
has 'gene_n' => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
has 'cds_n'  => ( is => 'ro', isa => 'Maybe[Num]', lazy_build => 1 );
# END: GFF file

# Is mapstats entry from QC or Mapping
sub _build_is_qc_mapstats {
    my ($self) = @_;
    return $self->{mapstats}->is_qc();
}

sub _build_is_mapping_complete {
    my ($self) = @_;
    return undef
      unless
      defined $self->mapstats->bases_mapped;   # Mapping not complete or failed;
    return $self->mapstats->bases_mapped
      ? 1
      : 0;    # Mapping complete and bases found;
}

# Build Internals
{

    sub _build__vrtrack_project {
        my ($self) = @_;
        my $project;
        eval {
            $project = VRTrack::Project->new( $self->vrtrack,
                $self->_vrtrack_sample->project_id );
        };
        return $project;
    }

    sub _build__vrtrack_sample {
        my ($self) = @_;
        my $sample;
        eval {
            my $library =
              VRTrack::Library->new( $self->vrtrack, $self->lane->library_id );
            $sample =
              VRTrack::Sample->new( $self->vrtrack, $library->sample_id )
              if defined $library;
        };
        return $sample;
    }

    sub _build__vrtrack_assembly {
        my ($self) = @_;
        my $assembly = $self->mapstats->assembly()
          or die "debug: build assembly failed\n";
        return $assembly;
    }

    sub _build__vrtrack_mapper {
        my ($self) = @_;
        my $mapper = $self->mapstats->mapper()
          or die "debug: build mapper failed\n";
        return $mapper;
    }

    sub _build__bamcheck_obj {
        my ($self) = @_;
        my $path_to_file = $self->bamcheck;

        return undef if ( !-e $path_to_file || !-s $path_to_file );
        return VertRes::Parser::bamcheck->new( file => $path_to_file );
    }

    sub _build__basic_assembly_stats {
        my ($self) = @_;
        my $path_to_file = $self->stats_file;

        return if ( !-e $path_to_file );
        my %assembly_stats;

        open( INPUT, $path_to_file ) or die "Couldnt open file $path_to_file\n";
        while (<INPUT>) {
            my $line = $_;
            if ( $line =~
                /sum = ([\d]+), n = ([\d]+), ave = ([\d\.]+), largest = ([\d]+)/
              )
            {
                $assembly_stats{total_length}          = $1;
                $assembly_stats{num_contigs}           = $2;
                $assembly_stats{average_contig_length} = $3;
                $assembly_stats{largest_contig}        = $4;
            }
            if ( $line =~ /N50 = ([\d]+), n = ([\d]+)/ ) {
                $assembly_stats{n50}   = $1;
                $assembly_stats{n50_n} = $2;
            }
            if ( $line =~ /N60 = ([\d]+), n = ([\d]+)/ ) {
                $assembly_stats{n60}   = $1;
                $assembly_stats{n60_n} = $2;
            }
            if ( $line =~ /N70 = ([\d]+), n = ([\d]+)/ ) {
                $assembly_stats{n70}   = $1;
                $assembly_stats{n70_n} = $2;
            }
            if ( $line =~ /N80 = ([\d]+), n = ([\d]+)/ ) {
                $assembly_stats{n80}   = $1;
                $assembly_stats{n80_n} = $2;
            }
            if ( $line =~ /N90 = ([\d]+), n = ([\d]+)/ ) {
                $assembly_stats{n90}   = $1;
                $assembly_stats{n90_n} = $2;
            }
            if ( $line =~ /N100 = ([\d]+), n = ([\d]+)/ ) {
                $assembly_stats{n100}   = $1;
                $assembly_stats{n100_n} = $2;
            }
            if ( $line =~ /N_count = ([\d]+)/ ) {
                $assembly_stats{n_count} = $1;
            }
        }
        return \%assembly_stats;
    }

}

# End Build Internals

# Build Cells
{
    # Mapping Cells
    {

        sub _build_study_id {
            my ($self) = @_;
            return $self->_vrtrack_project->ssid();
        }

        sub _build_sample {
            my ($self) = @_;
            return $self->_vrtrack_sample->name();
        }

        sub _build_lanename {
            my ($self) = @_;
            return $self->lane->name();
        }

        sub _build_cycles {
            my ($self) = @_;
            return $self->lane->read_len();
        }

        sub _build_reads {
            my ($self) = @_;
            return $self->lane->raw_reads();
        }

        sub _build_bases {
            my ($self) = @_;
            return $self->lane->raw_bases();
        }

        sub _build_map_type {
            my ($self) = @_;
            return $self->is_qc_mapstats() ? 'QC' : 'Mapping';
        }

        sub _build_reference {
            my ($self) = @_;
            return $self->_vrtrack_assembly->name();
        }

        sub _build_reference_size {
            my ($self) = @_;
            return $self->_vrtrack_assembly->reference_size();
        }

        sub _build_mapper {
            my ($self) = @_;
            return $self->mapstats->mapper->name();
        }

        sub _build_mapstats_id {
            my ($self) = @_;
            return $self->mapstats->id();
        }

        sub _build_adapter_perc {
            my ($self) = @_;
            return undef
              unless $self->is_qc_mapstats;    # not defined for mapping.

            my $adapter_perc;
            if ( defined $self->mapstats->adapter_reads
                && $self->mapstats->raw_reads )
            {
                my $adapter_reads = $self->mapstats->adapter_reads;
                $adapter_perc = sprintf( "%.1f",
                    ( $adapter_reads / $self->mapstats->raw_reads ) * 100 );
            }
            return $adapter_perc;
        }

        sub _build_transposon_perc {
            my ($self) = @_;
            return undef
              unless $self->is_qc_mapstats;    # not defined for mapping.

            my $transposon_perc;
            if ( defined $self->mapstats->percentage_reads_with_transposon ) {
                $transposon_perc = sprintf( "%.1f",
                    $self->mapstats->percentage_reads_with_transposon );
            }
            return $transposon_perc;
        }

        sub _build_mapped_perc {
            my ($self) = @_;
            my $reads_mapped_perc = '0.0';
            if ( $self->is_mapping_complete ) {
                my $reads_mapped = $self->mapstats->reads_mapped;
                my $raw_reads    = $self->mapstats->raw_reads;
                $reads_mapped_perc =
                  sprintf( "%.1f", ( $reads_mapped / $raw_reads ) * 100 );
            }
            return $reads_mapped_perc;
        }

        sub _build_paired_perc {
            my ($self) = @_;
            my $reads_paired_perc = '0.0';
            if ( $self->is_mapping_complete ) {
                my $reads_paired = $self->mapstats->reads_paired;
                my $raw_reads    = $self->mapstats->raw_reads;
                $reads_paired_perc =
                  sprintf( "%.1f", ( $reads_paired / $raw_reads ) * 100 );
            }
            return $reads_paired_perc;
        }

        sub _build_mean_insert_size {
            my ($self) = @_;
            return $self->mapstats->mean_insert;
        }

        sub _build_genome_covered {
            my ($self) = @_;
            return undef
              unless $self->is_qc_mapstats;    # Not calculated for mapping

            my $genome_cover_perc;
            if ( $self->is_mapping_complete ) {
                my $target_bases_mapped = $self->mapstats->target_bases_mapped;
                if ($target_bases_mapped) {
                    my $genome_covered =
                      $self->reference_size
                      ? ( $target_bases_mapped / $self->reference_size ) * 100
                      : undef;
                    $genome_cover_perc = sprintf( "%5.2f", $genome_covered )
                      if defined $genome_covered;
                }
            }
            return $genome_cover_perc;
        }

        sub _build_genome_covered_1x {
            my ($self) = @_;
            return undef if $self->is_qc_mapstats;
            return $self->_target_bases_X_perc(1);
        }

        sub _build_genome_covered_5x {
            my ($self) = @_;
            return undef if $self->is_qc_mapstats;
            return $self->_target_bases_X_perc(5);
        }

        sub _build_genome_covered_10x {
            my ($self) = @_;
            return undef if $self->is_qc_mapstats;
            return $self->_target_bases_X_perc(10);
        }

        sub _build_genome_covered_50x {
            my ($self) = @_;
            return undef if $self->is_qc_mapstats;
            return $self->_target_bases_X_perc(50);
        }

        sub _build_genome_covered_100x {
            my ($self) = @_;
            return undef if $self->is_qc_mapstats;
            return $self->_target_bases_X_perc(100);
        }

        sub _build_depth_of_coverage {
            my ($self) = @_;

            # Get value from mapstats
            my $depth = $self->mapstats->mean_target_coverage;

            # QC
            if ( $self->is_qc_mapstats && $self->is_mapping_complete ) {
                my $genome_size        = $self->reference_size;
                my $rmdup_bases_mapped = $self->mapstats->rmdup_bases_mapped;
                my $qc_bases           = $self->mapstats->raw_bases;
                my $bases              = $self->bases;

          # if no mapstats value then calculate from mapped bases / genome size.
                $depth =
                  ( $genome_size ? $rmdup_bases_mapped / $genome_size : undef )
                  unless defined $depth;

                # scale by lane bases / sample bases
                $depth = $depth * $bases / $qc_bases if defined $depth;
            }

            # Format and return
            $depth = sprintf( "%.2f", $depth ) if defined $depth;
            return $depth;
        }

        sub _build_depth_of_coverage_sd {
            my ($self) = @_;

            # Get value from mapstats
            my $depth_sd = $self->mapstats->target_coverage_sd;

            # QC
            if ( $self->is_qc_mapstats && $self->is_mapping_complete ) {
                my $qc_bases = $self->mapstats->raw_bases;
                my $bases    = $self->bases;

                # scale by lane bases / sample bases
                $depth_sd = $depth_sd * $bases / $qc_bases if defined $depth_sd;
            }

            # Format and return
            $depth_sd = sprintf( "%.2f", $depth_sd ) if defined $depth_sd;
            return $depth_sd;
        }

        sub _build_duplication_rate {
            my ($self) = @_;
            return undef unless $self->is_qc_mapstats;

            my $dupe_rate;
            if ( $self->is_mapping_complete ) {
                my $rmdup_reads_mapped = $self->mapstats->rmdup_reads_mapped;
                my $reads_mapped       = $self->mapstats->reads_mapped;
                $dupe_rate = sprintf( "%.4f",
                    ( 1 - $rmdup_reads_mapped / $reads_mapped ) );
            }
            return $dupe_rate;
        }

        sub _build_error_rate {
            my ($self) = @_;
            return undef unless $self->is_qc_mapstats;
            return $self->is_mapping_complete
              ? sprintf( "%.3f", $self->mapstats->error_rate )
              : undef;
        }

        sub _build_npg_qc {
            my ($self) = @_;
            return $self->lane->npg_qc_status();
        }

        sub _build_manual_qc {
            my ($self) = @_;
            return $self->lane->qc_status();
        }

    }

    # End Mapping Cells

    # Assembly Cells
    {
		sub _build_assembly_type {
			my ($self) = @_;
			my $sf = $self->stats_file;
			$sf =~ /([^\/]+_assembly[^\/]*)/;
			my %types = (
				'velvet_assembly' => 'Velvet',
				'spades_assembly' => 'SPAdes',
				'velvet_assembly_with_reference' => 'Columbus'
			);
			return $types{$1};
		}

        sub _build_sequences {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('sequences');
            }
	    else{
		return undef;
	    }
        }

        sub _build_reads_mapped {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('reads_mapped');
            }
	    else{
		return undef;
	    }
        }

        sub _build_reads_unmapped {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('reads_unmapped');
            }
	    else{
		return undef;
	    }
        }

		sub _build_reads_paired {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('reads_paired');
            }
	    else{
		return undef;
	    }
        }

		sub _build_reads_unpaired {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('reads_unpaired');
            }
	    else{
		return undef;
	    }
        }

		sub _build_raw_bases {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('total_length');
            }
	    else{
		return undef;
	    }
        }

		sub _build_bases_mapped {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('bases_mapped');
            }
	    else{
		return undef;
	    }
        }

		sub _build_bases_mapped_cigar {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('bases_mapped_cigar');
            }
	    else{
		return undef;
	    }
        }

		sub _build_avg_length {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('avg_length');
            }
	    else{
		return undef;
	    }
        }

		sub _build_max_length {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('max_length');
            }
	    else{
		return undef;
	    }
        }

		sub _build_avg_qual {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('avg_qual');
            }
	    else{
		return undef;
	    }
        }

		sub _build_avg_insert_size {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('avg_insert_size');
            }
	    else{
		return undef;
	    }
        }

		sub _build_sd_insert_size {
            my ($self) = @_;
            my $bc = $self->_bamcheck_obj;
            if ( defined($bc) ) {
                return $self->_bamcheck_obj->get('sd_insert_size');
            }
	    else{
		return undef;
	    }
        }

		sub _build_total_length{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{total_length} : undef;
		} 

		sub _build_num_contigs{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{num_contigs} : undef;
		}

		sub _build_average_contig_length{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{average_contig_length} : undef;
		}

		sub _build_largest_contig{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{largest_contig} : undef;
		}

		sub _build_n50{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n50} : undef;
		}

		sub _build_n50_n{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n50_n} : undef;
		}

		sub _build_n60{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n60} : undef;
		}

		sub _build_n60_n{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n60_n} : undef;
		}

		sub _build_n70{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n70} : undef;
		}

		sub _build_n70_n{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n70_n} : undef;
		}

		sub _build_n80{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n80} : undef;
		}

		sub _build_n80_n{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n80_n} : undef;
		}

		sub _build_n90{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n90} : undef;
		}

		sub _build_n90_n{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n90_n} : undef;
		}

		sub _build_n100{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n100} : undef;
		}

		sub _build_n100_n{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n100_n} : undef;
		}

		sub _build_n_count{
			my ($self) = @_;
			my $bas = $self->_basic_assembly_stats;
			return $bas ? $bas->{n_count} : undef;
		}
    }

    # End Assembly Cells

	# Annotation Cells
	{
		sub _build_gene_n {
			my ($self) = @_;
			my $gff = $self->gff_file;
			return undef unless(defined $gff);
			open(GFF, "<", $gff);
			my $gene_count = 0;
			while(my $line = <GFF>){
				last if($line =~ /##FASTA/);
				$gene_count++ unless($line =~ /^##/);
			}
			return $gene_count;
		}

		sub _build_cds_n {
			my ($self) = @_;
			my $gff = $self->gff_file;
			return undef unless(defined $gff);
			my $cds_count = `grep -c CDS $gff`;
			chomp $cds_count;
			return $cds_count;
		}
		
	}
}

#End Build Cells

# Return genome coverage percent greater then 1X, 5X etc.
sub _target_bases_X_perc {
    my ( $self, $coverdepth ) = @_;

    # Check to constrain $coverdepth
    my %allowed =
      ( 1 => 1, 2 => 1, 5 => 1, 10 => 1, 20 => 1, 50 => 1, 100 => 1 );
    return undef unless exists $allowed{$coverdepth};

    # return percentage or undef
    my $coverdepth_field = 'target_bases_' . $coverdepth . 'X';
    my $cover_perc       = $self->mapstats->$coverdepth_field;
    $cover_perc = sprintf( "%.1f", $cover_perc ) if defined $cover_perc;
    return $cover_perc;
}

# Checks Project, Sample, Assembly and Mapper set.
sub is_all_tables_set {
    my ($self) = @_;
    my @vrtrack_table_obj =
      qw(_vrtrack_project _vrtrack_sample _vrtrack_assembly _vrtrack_mapper);
    for my $table_obj (@vrtrack_table_obj) {
        return 0 unless defined $self->$table_obj;
    }
    return 1;
}

# Add selected QC mapstat values to Mapping mapstat values.
sub transfer_qc_values {
    my ( $self, $qc_row ) = @_;

    # error check
    return 0 unless defined $qc_row && $qc_row->is_qc_mapstats;
    return 0
      unless defined
      $self->is_mapping_complete;    # Do not update failed/running mapping.

    # update cells
    my @list_cells = qw(adapter_perc transposon_perc);

    for my $cell (@list_cells) {
        $self->$cell( $qc_row->$cell ) unless defined $self->$cell;
    }

    return 1;
}

1;
