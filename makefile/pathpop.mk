# Target population VCF should be configurable (e.g. dbSNP, ExAC, 5000exome, etc.)
GNOMAD_VCF_URL := https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.1.vcf.bgz
GNOMAD_VCF_URL ?= https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.vcf.bgz
GNOMAD_VCF ?= $(notdir $(GNOMAD_VCF_URL))

# snpEff annotated VCF
SNPEFF_VCF ?= $(subst .vcf,snpeff.vcf,$(GNOMAD_VCF))

# Genome Database used by snpEff. Must match genome of GNOMAD_VCF_URL
GENOME_SNPEFF ?= GRCh37.p13

INPUT_DIR ?= input
SNPEFF_DIR ?= snpEff

$(INPUT_DIR) $(SNPEFF_DIR) :
	mkdir $@

$(INPUT_DIR)/$(GNOMAD_VCF) : | $(INPUT_DIR)
	wget --output-document=$@ "$(GNOMAD_VCF_URL)" 

%.tbi : %
	tabix $<

$(SNPEFF_DIR)/$(SNPEFF_VCF) : $(INPUT_DIR)/$(GNOMAD_VCF) $(INPUT_DIR)/$(GNOMAD_VCF).tbi | $(SNPEFF_DIR)
	snpEff eff -csvStats $(dir $@)summary.csv $(GENOME_SNPEFF) $< | bgzip > $@

all : $(INPUT_DIR)/$(GNOMAD_VCF) $(INPUT_DIR)/$(GNOMAD_VCF).tbi $(SNPEFF_DIR)/$(SNPEFF_VCF) $(SNPEFF_DIR)/$(SNPEFF_VCF).tbi

purge : clean
	rm -r $(INPUT_DIR)/

clean :
	rm -rf $(SNPEFF_DIR)/


.PHONY : all clean purge
