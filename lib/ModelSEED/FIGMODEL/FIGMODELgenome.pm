use strict;
package ModelSEED::FIGMODEL::FIGMODELgenome;
use Scalar::Util qw(weaken);
use Carp qw(cluck);

=head1 FIGMODELgenome object
=head2 Introduction
Module for holding genome related access functions
=head2 Core Object Methods

=head3 new
Definition:
	FIGMODELgenome = FIGMODELgenome->new(figmodel,string:genome id);
Description:
	This is the constructor for the FIGMODELgenome object.
=cut
sub new {
	my ($class,$figmodel,$genome) = @_;
	#Error checking first
	if (!defined($figmodel)) {
		print STDERR "FIGMODELfba->new():figmodel must be defined to create an genome object!\n";
		return undef;
	}
	if (!defined($genome)) {
		$figmodel->error_message("FIGMODELfba->new():figmodel must be defined to create an genome object!");
		return undef;
	}
	my $self = {_figmodel => $figmodel,_genome => $genome};
    weaken($self->{_figmodel});
	bless $self;
    $self->{_ppo} = $self->figmodel()->database()->get_object("genomestats",{GENOME => $self->genome()});
	if (!defined($self->{_ppo})) {
		if (!defined($self->{_ppo})) {
			$self->{_ppo} = $self->update_genome_stats();
		}
		if (!defined($self->{_ppo})) {
			$self->error_message("Could not find genome in database:".$self->genome());
			return undef;
		}
	}
	return $self;
}

=head3 figmodel
Definition:
	FIGMODEL = FIGMODELgenome->figmodel();
Description:
	Returns the figmodel object
=cut
sub figmodel {
	my ($self) = @_;
	return $self->{_figmodel};
}

=head3 ppo
Definition:
	PPO:genomestats = FIGMODELgenome->ppo();
Description:
	Returns the PPO genomestats object for the genome
=cut
sub ppo {
	my ($self) = @_;
	return $self->{_ppo};
}

=head3 genome_stats
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->genome_stats();
Description:
=cut
sub genome_stats {
	my ($self) = @_;
	return $self->ppo();
}

=head3 genome
Definition:
	string:genome ID = FIGMODELgenome->genome();
Description:
	Returns the genome ID
=cut
sub genome {
	my ($self) = @_;
	return $self->{_genome};
}

=head3 error_message
Definition:
	string:message text = FIGMODELgenome->error_message(string::message);
Description:
=cut
sub error_message {
	my ($self,$message) = @_;
	return $self->figmodel()->error_message("FIGMODELgenome:".$self->genome().":".$message);
}

=head3 source
Definition:
	string:source = FIGMODELgenome->source();
Description:
	Returns the source of the genome
=cut
sub source {
	my ($self) = @_;
	return $self->ppo()->source();
}

=head3 name
Definition:
	string:source = FIGMODELgenome->name();
Description:
	Returns the name of the genome
=cut
sub name {
	my ($self) = @_;
	return $self->ppo()->name();
}

=head3 taxonomy
Definition:
	string:taxonomy = FIGMODELgenome->taxonomy();
Description:
	Returns the taxonomy of the genome
=cut
sub taxonomy {
	my ($self) = @_;
	return $self->ppo()->taxonomy();
}

=head3 owner
Definition:
	string:source = FIGMODELgenome->owner();
Description:
	Returns the owner of the genome
=cut
sub owner {
	my ($self) = @_;
	return $self->ppo()->owner();
}

=head3 size
Definition:
	string:source = FIGMODELgenome->size();
Description:
	Returns the size of the genome
=cut
sub size {
	my ($self) = @_;
	return $self->ppo()->size();
}

=head3 modelObj
Definition:
	FIGMODELmodel:model object = FIGMODELgenome->modelObj();
Description:
	Returns the model object for the default model for this genome
=cut
sub modelObj {
	my ($self) = @_;
	my $mdl = $self->figmodel()->get_model("Seed".$self->genome());
	if (!defined($mdl)) {
		$mdl = $self->figmodel()->get_model("Seed".$self->genome().".796");
	}
	return $mdl;
}

=head3 feature_table
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->feature_table({
		genome =>
		getSequences =>
		getEssentiality =>
		models =>
		source =>	
	});
Description:
	Returns a table of features in the genome
=cut
sub feature_table {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{
		genome => $self->genome(),
		getSequences => 0,
		getEssentiality => 1,
		models => undef,
		source => $self->source(),
		owner => $self->owner()
	});	
	if (!defined($self->{_features})) {
		if ($args->{source} =~ m/RAST/) {
			my $output = $self->getRastGenomeData();
		} elsif ($args->{source} =~ m/SEED/) {
			$self->{_features} = ModelSEED::FIGMODEL::FIGMODELTable->new(["ID","GENOME","ESSENTIALITY","ALIASES","TYPE","LOCATION","LENGTH","DIRECTION","MIN LOCATION","MAX LOCATION","ROLES","SOURCE","SEQUENCE"],$self->figmodel()->config("database message file directory")->[0]."Features-".$args->{genome}.".txt",["ID","ALIASES","TYPE","ROLES","GENOME"],"\t","|",undef);
			$self->{_features}->{_source} = $args->{source};
			$self->{_features}->{_owner} = $args->{owner};
			my $sap = $self->figmodel()->sapSvr($args->{source});
			#TODO: I'd like to see if we could possibly get all of this data with a single call
			#Getting feature list for genome
			my $featureHash = $sap->all_features({-ids => $args->{genome}});
			my $featureList = $featureHash->{$args->{genome}};
			#Getting functions for each feature
			my $functions = $sap->ids_to_functions({-ids => $featureList});
			#Getting locations for each feature
			my $locations = $sap->fid_locations({-ids => $featureList});
			#Getting aliases
			my $aliases;
			#my $aliases = $sap->fids_to_ids({-ids => $featureList,-protein => 1});
			#Getting sequences for each feature
			my $sequences;
			if ($args->{getSequences} == 1) {
				$sequences = $sap->ids_to_sequences({-ids => $featureList,-protein => 1});
			}
			#Placing data into feature table
			for (my $i=0; $i < @{$featureList}; $i++) {
				my $row = {ID => [$featureList->[$i]],GENOME => [$args->{genome}],TYPE => ["peg"]};
				if ($featureList->[$i] =~ m/\d+\.([^\.]+)\.\d+$/) {
					$row->{TYPE}->[0] = $1;
				}
				if (defined($locations->{$featureList->[$i]}->[0]) && $locations->{$featureList->[$i]}->[0] =~ m/(\d+)([\+\-])(\d+)$/) {
					if ($2 eq "-") {
						$row->{"MIN LOCATION"}->[0] = ($1-$3);
						$row->{"MAX LOCATION"}->[0] = ($1);
						$row->{LOCATION}->[0] = $1."_".($1-$3);
						$row->{DIRECTION}->[0] = "rev";
						$row->{LENGTH}->[0] = $3;
					} else {
						$row->{"MIN LOCATION"}->[0] = ($1);
						$row->{"MAX LOCATION"}->[0] = ($1+$3);
						$row->{LOCATION}->[0] = $1."_".($1+$3);
						$row->{DIRECTION}->[0] = "for";
						$row->{LENGTH}->[0] = $3;
					}
				}
				if (defined($aliases->{$featureList->[$i]})) {
					my @types = keys(%{$aliases->{$featureList->[$i]}});
					for (my $j=0; $j < @types; $j++) {
						push(@{$row->{ALIASES}},@{$aliases->{$featureList->[$i]}->{$types[$j]}});
					}
				}
				if (defined($functions->{$featureList->[$i]})) {
					push(@{$row->{ROLES}},$self->figmodel()->roles_of_function($functions->{$featureList->[$i]}));
				}
				if (defined($args->{getSequences}) && $args->{getSequences} == 1 && defined($sequences->{$featureList->[$i]})) {
					$row->{SEQUENCE}->[0] = $sequences->{$featureList->[$i]};
				}
				$self->{_features}->add_row($row);
			}
		}
		#Adding gene essentiality data to the table
		if ($args->{getEssentiality} == 1 && defined($self->{_features})) {
			my $sets = $self->figmodel()->database()->get_objects("esssets",{GENOME => $self->genome()});
			for (my $i=0; $i < $self->{_features}->size(); $i++) {
				my $row = $self->{_features}->get_row($i);
				if (defined($sets->[0])) {
					if ($row->{ID}->[0] =~ m/(peg\.\d+)/) {
						my $gene = $1;
						for (my $i=0; $i < @{$sets}; $i++) {
							my $essGene = $self->figmodel()->database()->get_object("essgenes",{FEATURE=>$gene,ESSENTIALITYSET=>$sets->[$i]->id()});
							if (defined($essGene)) {
								push(@{$row->{ESSENTIALITY}},$sets->[$i]->MEDIA().":".$essGene->essentiality());
							}
						}
					}
				}
			}
		}
	}
	#Adding model data to feature table
	if (defined($args->{models})) {
		for (my $i=0; $i < @{$args->{models}}; $i++) {
			my $mdl = $self->figmodel()->get_model($args->{models}->[$i]);
			my $geneHash = $mdl->featureHash();
			my @genes = keys(%{$geneHash});
			for (my $j=0; $j < @genes; $j++) {
				my $row = $self->{_features}->get_row_by_key("fig|".$self->genome().".".$genes[$j],"ID");
				if (defined($row)) {
					$row->{$args->{models}->[$i]} = $geneHash->{$genes[$j]};
				}	
			}
		}
	}
	return $self->{_features};
}

=head3 getRastGenomeData
Definition:
	FIGMODELTable:feature table = FIGMODELgenome->getRastGenomeData({});
Description:
=cut
sub getRastGenomeData {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,[],{});
	#Getting RAST feature data from the FBAMODEL server for now
	my $fbaserv = FBAMODELserver->new();
	my $output = $fbaserv->getRastGenomeData({genome => $self->genome(),username => $self->figmodel()->userObj()->login(),password => $self->figmodel()->userObj()->password()});
	if (!defined($output->{features})) {
		$self->error_message("Could not load feature table for rast genome:".$output->{error});
		return undef;
	}
	$output->{features}->{_source} = $output->{source};
	$output->{features}->{_owner} = $output->{owner};
	$output->{features}->{_name} = $output->{name};
	$output->{features}->{_taxonomy} = $output->{taxonomy};
	$output->{features}->{_size} = $output->{size};
	$output->{features}->{_active_subsystems} = $output->{activeSubsystems};
	$self->{_active_subsystems} = $output->{activeSubsystems};
	$output->{features}->{_gc} = $output->{gc};
	$self->{_features} = $output->{features};
	return $output;
}

=head3 intervalGenes
Definition:
	{genes => [string:gene IDs]} = FIGMODELgenome->intervalGenes({start => integer:start location,stop => integer:stop location});
Description:
=cut
sub intervalGenes {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["start","stop"],{});
	if (defined($args->{error})) {return {error => $args->{error}};}
	my $tbl = $self->feature_table();
	if (!defined($tbl)) {return {error => $self->error_message("intervalGenes:could not load feature table for genome")};}
	my $results;
	for (my $i=0; $i < $tbl->size(); $i++) {
		my $row = $tbl->get_row($i);
		if ($row->{ID}->[0] =~ m/fig\|\d+\.\d+\.(peg\.\d+)/) {
			my $id = $1;
			if (defined($row->{"MIN LOCATION"}->[0]) && defined($row->{"MAX LOCATION"}->[0]) && $args->{stop} > $row->{"MIN LOCATION"}->[0] && $args->{start} < $row->{"MAX LOCATION"}->[0]) {
				push(@{$results->{genes}},$id);
			}
		}
	}
	return $results;
}
=head3 update_genome_stats
Definition:
	FIGMODELgenome->update_genome_stats();
Description:
=cut
sub update_genome_stats {
	my ($self) = @_;
	#Initializing the empty stats hash with default values
	my $genomeStats = {
		GENOME => $self->genome(),
		class => "Unknown",
		source => "PSEED",
		owner => "master",
		name => undef,
		taxonomy => undef,
		size => undef,
		public => 1,
		genes => 0,
		gramPosGenes => 0,
		gramNegGenes => 0,
		genesWithFunctions => 0,
		genesInSubsystems => 0,
		gcContent => 0
	};
	#Determining the source, name, size, taxonomy of the genome
	my $GenomeData;
	my $sap = $self->figmodel()->sapSvr("PSEED");
	my $result = $sap->exists({-type => 'Genome',-ids => [$self->genome()]});
	if ($result->{$self->genome()} eq "0") {
		my $output = $self->getRastGenomeData();
		if (!defined($self->{_features})) {
			$self->error_message("FIGMODELgenome:genome_stats:Could not find genome ".$self->genome()." in database");
			return undef;
		}
		my $rastDataHeadings = {
			_gc => "gcContent",
			_owner => "owner",
			_size => "size",
			_name => "name",
			_taxonomy => "taxonomy",
			_source => "source"
		};
		foreach my $key (keys(%{$rastDataHeadings})) {
			if (defined($self->{_features}->{$key})) {
				$genomeStats->{$rastDataHeadings->{$key}} = $self->{_features}->{$key};
			}
		}
		$GenomeData = $self->{_features};
	} else {
		$genomeStats->{source} = "PSEED";
		my $genomeHash = $self->figmodel()->sapSvr("PSEED")->genome_data({
			-ids => [$self->genome()],
			-data => ["dna-size","name","taxonomy"]
		});
		if (defined($genomeHash->{$self->genome()})) {
			$genomeStats->{name} = $genomeHash->{$self->genome()}->{name};
			$genomeStats->{size} = $genomeHash->{$self->genome()}->{"dna-size"};
			$genomeStats->{taxonomy} = $genomeHash->{$self->genome()}->{taxonomy};
		}
		my $numgc = 0;
		my $totalLength = 0;
		my $sequences = $self->get_genome_sequence();
		for (my $i=0; $i < @{$sequences}; $i++) {
			$totalLength += length($sequences->[$i]);
			while ($sequences->[$i] =~ m{([gc])}g) {
				$numgc++;
			}
		}
		if ($totalLength == 0) {
			$genomeStats->{gcContent} = 0.5;
		} else {
			$genomeStats->{gcContent} = $numgc/$totalLength;
		}
		$GenomeData = $self->feature_table({
			getSequences => 0,
			getEssentiality => 0,
			source => $genomeStats->{source},
			owner => $genomeStats->{owner}
		});
	}
	if (!defined($GenomeData)) {
		$self->error_message("FIGMODELgenome:genome_stats:Could not load features table!");
		return undef;
	}
	#Looping through the genes and gathering statistics
	for (my $j=0; $j < $GenomeData->size(); $j++) {
		my $GeneData = $GenomeData->get_row($j);
		if (defined($GeneData) && $GeneData->{"ID"}->[0] =~ m/(peg\.\d+)/) {
			$GeneData->{"ID"}->[0] = $1;
			$genomeStats->{genes}++;
			#Checking that the gene has roles
			if (defined($GeneData->{"ROLES"}->[0])) {
				my $functionFound = 0;
				my $subsystemFound = 0;
				my $gramPosFound = 0;
				my $gramNegFound = 0;
				my @Roles = @{$GeneData->{"ROLES"}};
				foreach my $Role (@Roles) {
					if ($self->figmodel()->role_is_valid($Role) != 0) {
						$functionFound = 1;
						#Looking for role subsystems
						my $GeneSubsystems = $self->figmodel()->subsystems_of_role($Role);
						if (defined($GeneSubsystems) && @{$GeneSubsystems} > 0) {
							$subsystemFound = 1;
							foreach my $Subsystem (@{$GeneSubsystems}) {
								if ($Subsystem->classOne() =~ m/Gram\-Negative/ || $Subsystem->classTwo() =~ m/Gram\-Negative/) {
									$gramNegFound = 1;
								} elsif ($Subsystem->classOne() =~ m/Gram\-Positive/ || $Subsystem->classTwo() =~ m/Gram\-Positive/) {
									$gramPosFound = 1;
								}
							}
						}
					}
				}
				if ($functionFound == 1) {
					$genomeStats->{genesWithFunctions}++;
					if ($subsystemFound == 1) {
						$genomeStats->{genesInSubsystems}++;
						if ($gramPosFound == 1) {
							$genomeStats->{gramPosGenes}++;
						} elsif ($gramNegFound == 1) {
							$genomeStats->{gramNegGenes}++;
						}
					}
				}
			}
		}
	}
	#Setting the genome class
	foreach my $ClassSetting (@{$self->figmodel()->config("class list")}) {
		if (defined($self->{$ClassSetting}->{$self->genome()})) {
			$genomeStats->{class} = $ClassSetting;
			last;
		} else {
			for (my $i=0; $i < @{$self->figmodel()->config($ClassSetting." families")}; $i++) {
				my $family = $self->figmodel()->config($ClassSetting." families")->[$i];
				if ($self->name() =~ m/$family/) {
					$genomeStats->{class} = $ClassSetting;
					last;
				}
			}
		}
	}
	#Determining the genome class
	if ($genomeStats->{class} eq "Unknown") {
		if ($genomeStats->{source} eq "MGRAST") {
			$genomeStats->{class} = "Metagenome";
		} elsif ($genomeStats->{gramNegGenes} > $genomeStats->{gramPosGenes}) {
			$genomeStats->{class} = "Gram negative";
		} elsif ($genomeStats->{gramNegGenes} < $genomeStats->{gramPosGenes}) {
			$genomeStats->{class} = "Gram positive";
		}
	}
	#Loading the data into the PPO database
	$self->{_stats} = $self->figmodel()->database()->get_object("genomestats",{GENOME => $self->genome()});
	if (defined($self->{_stats})) {	
		foreach my $key (keys(%{$genomeStats})) {
			$self->{_stats}->$key($genomeStats->{$key});	
		}
	} else {
		$self->{_stats} = $self->figmodel()->database()->create_object("genomestats",$genomeStats);
	}
}
=head3 roles_of_peg
Definition:
	my @Roles = roles_of_peg($self,$GeneID,$SelectedModel);
Description:
	Returns list of functional roles associated with the input peg in the SEED for the specified model
=cut
sub roles_of_peg {
	my ($self,$args) = @_;
	$args = $self->figmodel()->process_arguments($args,["gene"],{});
	if (!defined($args->{error})) {
		$self->error_message({message=>$args->{error}});
		return undef;
	}
	my $ftrTbl = $self->feature_table();
	if (!defined($ftrTbl)) {
		$self->error_message({message=>"Could not load feature table"});
		return undef;
	}
	my $gene = $ftrTbl->get_object({ID => "fig|".$self->genome().".".$args->{gene}});
	if (!defined($gene)) {
		$self->error_message({message=>"Could not find gene ".$args->{gene}});
		return undef;
	}
	return $gene->{ROLES};
	
}

sub active_subsystems {
	my ($self) = @_;
	if (!defined($self->{_active_subsystems})) {
		if ($self->source() =~ m/SEED/) {
			my $sap = $self->figmodel()->sapSvr($self->source());
			my $output = $sap->genomes_to_subsystems({
				-ids => [$self->genome()],
				-exclude => ['cluster-based','experimental']	
			});
			$self->{_active_subsystems} = [];
			if (defined($output->{$self->genome()})) {
				for (my $i=0; $i < @{$output->{$self->genome()}}; $i++) {
					push(@{$self->{_active_subsystems}},$output->{$self->genome()}->[$i]->[0]);
				}	
			}
		} else {
			my $output = $self->getRastGenomeData();
		}
	}
	return $self->{_active_subsystems};
}

sub totalGene {
	my ($self) = @_;
	return $self->ppo()->genes();
}

=head3 get_genome_sequence
Definition:
	[string] = FIGMODEL->get_genome_sequence(string::genome ID);
Description:
	This function returns a list of the DNA sequence for every contig of the genome
=cut
sub get_genome_sequence {
	my ($self) = @_;
	if ($self->source() =~ m/SEED/) {
		my $sap = $self->figmodel()->sapSvr("PSEED");
		my $genomeHash = $sap->genome_contigs({-ids => [$self->genome()]});
		my $contigHash = $sap->contig_sequences({-ids => $genomeHash->{$self->genome()}});
		return [values(%{$contigHash})];
	} elsif ($self->source() =~ m/RAST/) {
		my $output = $self->getRastGenomeData({
			getDNASequence => 1
		});
		return $output->{DNAsequence};
	}
	return undef;
}

1;