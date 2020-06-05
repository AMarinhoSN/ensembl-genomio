package Bio::EnsEMBL::Pipeline::PipeConfig::BRC4_genome_prepare_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');

use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;
use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::ApiVersion qw(software_version);

use File::Basename;
use File::Spec::Functions qw(catdir catfile);
use FindBin;
use Class::Inspector;

my $package_path = Class::Inspector->loaded_filename(__PACKAGE__);
my $package_dir = dirname($package_path);
my $root_dir = "$package_dir/../../../../../..";

my $schema_dir = "$root_dir/schema";

sub default_options {
  my ($self) = @_;
  return {
    %{ $self->SUPER::default_options() },

    ############################################
    # Config to be set by the user
    # MZ/BRC4 release id
    db_prefix => "",

    # Basic pipeline configuration
    pipeline_tag => '',
    pipeline_name => 'brc4_genome_prepare' . $self->o('pipeline_tag'),

    # Working directory
    pipeline_dir => 'genome_prepare',
    data_dir => $self->o('data_dir'),
    output_dir => $self->o('output_dir'),

    debug => 0,
    ensembl_mode => 0,

    ## Metadata parameters
    'schemas' => {
      'seq_region' => catfile($schema_dir, "seq_region_schema.json"),
      'seq_attrib' => catfile($schema_dir, "seq_attrib_schema.json"),
      'functional_annotation' => catfile($schema_dir, "functional_annotation_schema.json"),
      'genome' => catfile($schema_dir, "genome_schema.json"),
      'manifest' => catfile($schema_dir, "manifest_schema.json"),
    },

    ############################################
    # Config unlikely to be changed by the user

  };
}

sub pipeline_wide_parameters {
  my ($self) = @_;

  return {
    %{$self->SUPER::pipeline_wide_parameters},
    debug          => $self->o('debug'),
    'schemas'      => $self->o('schemas'),
    pipeline_dir   => $self->o('pipeline_dir'),
  };
}

sub pipeline_create_commands {
    my ($self) = @_;
    return [
      # inheriting database and hive tables' creation
      @{$self->SUPER::pipeline_create_commands},
      'mkdir -p '.$self->o('pipeline_dir'),
    ];
}

sub pipeline_analyses {
  my ($self) = @_;

  return
  [
    # Starting point
    {
      -logic_name => 'Start',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -input_ids  => [{}],
      -analysis_capacity   => 1,
      -rc_name    => 'default',
      -meadow_type       => 'LSF',
      -flow_into  => 'Genome_factory',
    },

    {
      # Create a thread for each species = manifest file
      # Output:
      -logic_name        => 'Genome_factory',
      -module         => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
      -parameters        => {
        data_dir => $self->o('data_dir'),
        inputcmd => "find #data_dir# -type f -name '*.json'",
      },
      -analysis_capacity   => 1,
      -rc_name    => 'default',
      -meadow_type       => 'LSF',
      -max_retry_count => 0,
      -flow_into => {
        '2' => { 'Check_genome_schema' => { genome_json => '#_0#' } },
      },
    },

    {
      -logic_name     => 'Check_genome_schema',
      -module         => 'ensembl.brc4.runnable.schema_validator',
      -language => 'python3',
      -parameters     => {
        json_file => '#genome_json#',
        json_schema => '#schemas#',
        metadata_type => 'genome'
      },
      -analysis_capacity => 1,
      -failed_job_tolerance => 100,
      -batch_size     => 50,
      -rc_name        => 'default',
      -flow_into  => {1 => { 'Read_genome_data' => INPUT_PLUS() } },
    },

    {
      -logic_name     => 'Read_genome_data',
      -module         => 'ensembl.brc4.runnable.read_json',
      -language => 'python3',
      -parameters     => {
        json_path => '#genome_json#',
        name => "genome_data"
      },
      -analysis_capacity => 1,
      -failed_job_tolerance => 100,
      -batch_size     => 50,
      -rc_name        => 'default',
      -flow_into  => { 2 => 'Download_assembly_data' },
    },

    {
      -logic_name     => 'Download_assembly_data',
      -module         => 'ensembl.brc4.runnable.download_assembly_data',
      -language => 'python3',
      -parameters     => {
        genome_data => '#genome_data#',
        download_dir => $self->o('pipeline_dir') . "/download",
      },
      -analysis_capacity => 1,
      -failed_job_tolerance => 100,
      -rc_name        => 'default',
      -flow_into  => {
        '2->A' => { 'Process_data' => INPUT_PLUS() },
        'A->2' => { 'Manifest_maker' => INPUT_PLUS() },
      },
    },

    {
      -logic_name => 'Process_data',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity   => 1,
      -rc_name    => 'default',
      -flow_into  => [
        'Process_genome_metadata',
        'Process_seq_region',
        'Process_fasta_dna',
      ],
    },

    # Process files to our specifications
    {
      -logic_name => 'Process_genome_metadata',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity   => 1,
      -rc_name    => 'default',
      -parameters     => {
        hash_key => "genome",
      },
      -flow_into  => { 1 => '?accu_name=manifest_files&accu_address={hash_key}&accu_input_variable=genome_json' },
    },

    {
      -logic_name => 'Process_seq_region',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity   => 1,
      -rc_name    => 'default',
      -parameters     => {
        hash_key => "seq_region",
      },
      -flow_into  => { 1 => '?accu_name=manifest_files&accu_address={hash_key}&accu_input_variable=seq_region_json' },
    },

    {
      -logic_name => 'Process_fasta_dna',
      -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
      -analysis_capacity   => 1,
      -rc_name    => 'default',
      -parameters     => {
        hash_key => "fasta_dna",
      },
      -flow_into  => { 1 => '?accu_name=manifest_files&accu_address={hash_key}&accu_input_variable=fasta_dna' },
    },

    # Collate files to their final dir
    { -logic_name  => 'Manifest_maker',
      -module      => 'ensembl.brc4.runnable.manifest',
      -language    => 'python3',
      -max_retry_count => 0,
      -analysis_capacity   => 1,
      -rc_name         => 'default',
      -parameters     => {
        output_dir => $self->o('output_dir'),
      },
      -flow_into       => { '2' => 'Manifest_check' },
    },

    {
      -logic_name     => 'Manifest_check',
      -module         => 'ensembl.brc4.runnable.schema_validator',
      -language => 'python3',
      -parameters     => {
        metadata_type => 'manifest',
        json_file => '#manifest#',
        json_schema => '#schemas#',
      },
      -analysis_capacity => 1,
      -failed_job_tolerance => 100,
      -batch_size     => 50,
      -rc_name        => 'default',
      -flow_into       => 'Integrity_check',
    },

    { -logic_name  => 'Integrity_check',
      -module      => 'ensembl.brc4.runnable.integrity',
      -language    => 'python3',
      -parameters     => {
        ensembl_mode => $self->o('ensembl_mode'),
      },
      -analysis_capacity   => 5,
      -rc_name         => '8GB',
      -max_retry_count => 0,
    },
  ];
}

sub resource_classes {
    my $self = shift;
    return {
      'default'  	=> {'LSF' => '-q production-rh74 -M 4000   -R "rusage[mem=4000]"'},
      '8GB'       => {'LSF' => '-q production-rh74 -M 8000   -R "rusage[mem=8000]"'},
      '15GB'      => {'LSF' => '-q production-rh74 -M 15000  -R "rusage[mem=15000]"'},
      '32GB'  	 	=> {'LSF' => '-q production-rh74 -M 32000  -R "rusage[mem=32000]"'},
      '64GB'  	 	=> {'LSF' => '-q production-rh74 -M 64000  -R "rusage[mem=64000]"'},
      '128GB'  	 	=> {'LSF' => '-q production-rh74 -M 128000 -R "rusage[mem=128000]"'},
      '256GB'  	 	=> {'LSF' => '-q production-rh74 -M 256000 -R "rusage[mem=256000]"'},
	}
}

1;
