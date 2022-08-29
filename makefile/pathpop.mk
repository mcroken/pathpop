SHELL := /bin/bash
SELF := $(realpath $(lastword $(MAKEFILE_LIST)))
REPO_ROOT := $(abspath $(dir $(SELF))/..)

# Target population VCF should be configurable (e.g. dbSNP, ExAC, 5000exome, etc.)
#GNOMAD_VCF_URL := https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.1.vcf.bgz
GNOMAD_VCF_URL ?= https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.vcf.bgz
GNOMAD_VCF ?= $(notdir $(GNOMAD_VCF_URL))

# snpEff annotated VCF
SNPEFF_VCF ?= $(subst .vcf,.snpeff.vcf,$(GNOMAD_VCF))
SNPEFF_TBL ?= $(patsubst %.vcf.bgz,%.tbl.bgz,$(SNPEFF_VCF))

# Genome Database used by snpEff. Must match genome of GNOMAD_VCF_URL
GENOME_SNPEFF ?= GRCh37.p13

# Filter-in appropriate variants
FILT_VCF ?= $(subst .vcf,.snpeff_filt.vcf,$(GNOMAD_VCF))

# Comma separated list of valid FILTERs
FILTERS ?= "PASS"

# OncoKB API
ONCOKB_URL ?= https://www.oncokb.org/api/v1
ONCOKB_TOKEN_FILE ?= $(REPO_ROOT)/token/oncokb_token.txt
ONCOKB_TOKEN ?= $(shell cat $(ONCOKB_TOKEN_FILE))
ONCOKB_HEADER ?= -H "accept: application/json" -H "Authorization: Bearer $(ONCOKB_TOKEN)"

# All Gene endpoint
ONCOKB_ALLGENE ?= /utils/allCuratedGenes
# Genes curated by oncoKB
ONCOKB_GENE_LIST ?= oncoKB.geneList.json
# Extract gene symbols
ONCOKB_GENES = $(shell jq -r '.[].hugoSymbol' $(ONCOKB_DIR)/$(ONCOKB_GENE_LIST) | tr '\n' ' ')
# bcftools 'include' expression
#$(wordlist 1,$(shell expr $(words $(ONCOKB_GENE_INCLUDE)) - 1),$(ONCOKB_GENE_INCLUDE))
ONCOKB_GENE_INCLUDE_PRE = $(foreach gene,$(ONCOKB_GENES),INFO/ANN ~ '|$(gene)|' ||)
ONCOKB_GENE_INCLUDE = $(wordlist 1,$(shell expr $(words $(ONCOKB_GENE_INCLUDE_PRE)) - 1),$(ONCOKB_GENE_INCLUDE_PRE))

# Variant by Genomic Change Endpoint
ONCOKB_GCHANGE ?= /annotate/mutations/byGenomicChange
ONCOKB_VAR_JSON ?= oncoKB.gnomad_var.json


#GNOMAD variants within oncoKB curated genes
GNOMAD_ONCOKB_VCF ?= $(subst .vcf,.oncokb.vcf,$(GNOMAD_VCF))

INPUT_DIR ?= input
SNPEFF_DIR ?= snpEff
ONCOKB_DIR ?= oncoKB

$(ONCOKB_DIR)/$(ONCOKB_GENE_LIST) : | $(ONCOKB_DIR) $(ONCOKB_TOKEN_FILE)
	curl -X GET $(ONCOKB_HEADER) $(ONCOKB_URL)$(ONCOKB_ALLGENE) > $@

$(ONCOKB_DIR)/$(GNOMAD_ONCOKB_VCF) : $(SNPEFF_DIR)/$(SNPEFF_VCF) $(ONCOKB_DIR)/$(ONCOKB_GENE_LIST)
	bcftools view -i "$(ONCOKB_GENE_INCLUDE)" $< | bgzip > $@

$(INPUT_DIR) $(SNPEFF_DIR) $(ONCOKB_DIR) :
	mkdir $@

$(INPUT_DIR)/$(GNOMAD_VCF) : | $(INPUT_DIR)
	wget --output-document=$@ "$(GNOMAD_VCF_URL)"

%.tbi : %
	tabix $<

$(SNPEFF_DIR)/$(SNPEFF_VCF) : $(INPUT_DIR)/$(GNOMAD_VCF) $(INPUT_DIR)/$(GNOMAD_VCF).tbi | $(SNPEFF_DIR)
	snpEff eff -csvStats $(dir $@)summary.csv $(GENOME_SNPEFF) $< | bgzip > $@

$(SNPEFF_DIR)/$(FILT_VCF) : $(SNPEFF_DIR)/$(SNPEFF_VCF) $(SNPEFF_DIR)/$(SNPEFF_VCF).tbi
	bcftools view --apply-filters "$(FILTERS)" $< | bgzip > $@

$(SNPEFF_DIR)/$(SNPEFF_TBL) : $(SNPEFF_DIR)/$(SNPEFF_VCF) $(SNPEFF_DIR)/$(SNPEFF_VCF).tbi
	bcftools query -i "FILTER == 'PASS'" -f "%INFO/ANN\t%INFO/AC\t%INFO/AN\t%INFO/AF\t%CHROM,%POS,%REF,%ALT\n" $< | tr '|' '\t' | bgzip > $@

all : $(INPUT_DIR)/$(GNOMAD_VCF) $(INPUT_DIR)/$(GNOMAD_VCF).tbi \
	$(SNPEFF_DIR)/$(SNPEFF_VCF) $(SNPEFF_DIR)/$(SNPEFF_VCF).tbi \
	$(ONCOKB_DIR)/$(GNOMAD_ONCOKB_VCF) $(ONCOKB_DIR)/$(GNOMAD_ONCOKB_VCF).tbi


test : $(SNPEFF_DIR)/$(SNPEFF_TBL)

purge : clean
	rm -r $(INPUT_DIR)/

clean :
	echo "rm -rf $(SNPEFF_DIR)/"


.PHONY : all clean purge test
