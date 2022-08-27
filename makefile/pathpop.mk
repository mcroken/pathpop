# Target population VCF should be configurable (e.g. dbSNP, ExAC, 5000exome, etc.)
GNOMAD_VCF_URL := https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.1.vcf.bgz
GNOMAD_VCF_URL ?= https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.vcf.bgz
GNOMAD_VCF ?= $(notdir $(GNOMAD_VCF_URL))

# Genome Database used by snpEff. Must match genome of GNOMAD_VCF_URL
GENOME_SNPEFF ?= GRCh37.75

INPUT_DIR ?= input

$(INPUT_DIR) :
	mkdir $@

$(INPUT_DIR)/$(GNOMAD_VCF) : | $(INPUT_DIR)
	wget --output-document=$@ "$(GNOMAD_VCF_URL)" 

$(INPUT_DIR)/$(GNOMAD_VCF).tbi : $(INPUT_DIR)/$(GNOMAD_VCF)
	bcftools index --tbi $<

all : $(INPUT_DIR)/$(GNOMAD_VCF) $(INPUT_DIR)/$(GNOMAD_VCF).tbi

clean :
	rm -r $(INPUT_DIR)/


.PHONY : all
