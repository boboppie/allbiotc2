# preprocess-bwa.mk
#
# Makefile for preprocessing FastQ files -- Part of pipeline for ALLBioTC2
#
# (c) 2013 by Wai Yi Leung [SASC-LUMC]
# 
# Adapted makefile configuration from Wibowo Arindrarto [SASC-LUMC]
# 
# This pipeline is able to run with multiple aligners (aligner modules)
# Settings can be found in the conf.mk in this directory

# Delete target if recipe returns error status code.
.DELETE_ON_ERROR:

# Load all module definition
# Makefile specific settings
MAKEFILE_DIR := $(realpath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))
THIS_MAKEFILE = $(lastword $(MAKEFILE_LIST))
SHELL := $(MAKEFILE_DIR)/modules/logwrapper.sh
include $(MAKEFILE_DIR)/modules.mk
include $(MAKEFILE_DIR)/conf.mk
export MAKEFILE_DIR THIS_MAKEFILE

#######################
#### Basic checking ###
#######################

# only check the variable in non-install goals
ifneq ($(MAKECMDGOALS),install)
$(if $(REFERENCE_VCF),,$(error REFERENCE_VCF is a required value))
endif
ifeq ($(MAKECMDGOALS),preprocess)
$(if $(SDI_FILE),,$(error SDI_FILE is a required value))
endif

#######################
### General Targets ###
#######################
 

all: data_generation fastqc alignment aligmentstats sv_vcf report 

##############################
### Generate reference VCF ###
##############################

preprocess: $(REFERENCE_VCF)

$(REFERENCE_VCF): $(SDI_FILE)
	python $(MAKEFILE_DIR)/sdi-to-vcf/sdi-to-vcf.py -p $^ $(REFERENCE) > $@

######################
## Data generation ###
######################

data_generation: $(SAMPLE)$(PEA_MARK).$(FASTQ_EXTENSION)

%.$(FASTQ_EXTENSION): 
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/data_generation/makefile

#################
### Alignment ###
#################

BAM_FILES = $(addsuffix .sam, $(SAMPLE)) $(addsuffix .bam, $(SAMPLE)) $(addsuffix .bam.bai, $(SAMPLE))

alignment: $(addprefix $(OUT_DIR)/, $(BAM_FILES))

aligmentstats: $(addprefix $(OUT_DIR)/, $(addsuffix .flagstat, $(SAMPLE)) )

%.sam: %$(PEA_MARK).trimmed.$(FASTQ_EXTENSION) %$(PEB_MARK).trimmed.$(FASTQ_EXTENSION)
	$(MAKE) -f $(MAKEFILE_DIR)/modules/alignment.mk $@

%.bam: %$(PEA_MARK).trimmed.$(FASTQ_EXTENSION) %$(PEB_MARK).trimmed.$(FASTQ_EXTENSION)
	$(MAKE) -f $(MAKEFILE_DIR)/modules/alignment.mk $@

%.bam.bai: %$(PEA_MARK).trimmed.$(FASTQ_EXTENSION) %$(PEB_MARK).trimmed.$(FASTQ_EXTENSION)
	$(MAKE) -f $(MAKEFILE_DIR)/modules/alignment.mk $@

%.flagstat: %.bam
	$(MAKE) -f $(MAKEFILE_DIR)/modules/alignment.mk $@

###############
### Targets ###
###############

# outputdir for all recipies:

SV_PROGRAMS := clever delly bd prism gasv pindel meerkat
SV_OUTPUT := $(foreach s, $(SAMPLE), $(foreach p, $(SV_PROGRAMS), $(s).$(p).vcf))
SV_OUTPUT_2 := $(addprefix $(OUT_DIR)/, $(SV_OUTPUT))
sv_vcf: $(addprefix $(OUT_DIR)/, $(SV_OUTPUT))
# Partial recipies
qc: $(addsuffix .fastqc, $(SINGLES))
FASTQC_FILES = $(addsuffix .raw_fastqc, $(PAIRS)) $(addsuffix .trimmed_fastqc, $(PAIRS)) $(addsuffix .trimmed.fastq, $(SINGLES))
fastqc: $(addprefix $(OUT_DIR)/, $(FASTQC_FILES))
report: $(addprefix $(OUT_DIR)/, $(addsuffix .report.pdf, $(SAMPLE))) $(addprefix $(OUT_DIR)/, $(addsuffix .report.tex, $(SAMPLE)))

# settings for reporting
EVALUATE_PREDICTIONS := ~/virtualenv-1.10.1/myVE/bin/python $(MAKEFILE_DIR)/evaluation/evaluate-sv-predictions2


#########################
### Debug targets     ###
#########################

.PHONY: test

# Debugging variables
test:
	echo $(CURDIR)
	echo $(MAKEFILE_DIR)
	echo $(SV_OUTPUT)
	echo $(SAMPLE)

#########################
### Rules and Recipes ###
#########################

# creates the output directory
$(OUT_DIR):
	mkdir -p $@

%.fastqc: %.$(FASTQ_EXTENSION)
	$(MAKE) -f $(MAKEFILE_DIR)/modules/fastqc.mk $@

# FastQC for quality control
%.raw_fastqc: %$(PEA_MARK).$(FASTQ_EXTENSION) %$(PEB_MARK).$(FASTQ_EXTENSION)
	mkdir -p $@ && (SGE_RREQ="-now no -pe $(SGE_PE) $(FASTQC_THREADS)" $(FASTQC) --format fastq -q -t $(FASTQC_THREADS) -o $@ $^ || (rm -Rf $@ && false))

%$(PEA_MARK).trimmed.$(FASTQ_EXTENSION): %$(PEA_MARK).$(FASTQ_EXTENSION) %$(PEB_MARK).$(FASTQ_EXTENSION)
	$(SICKLE) pe -f $(word 1, $^) -r $(word 2, $^) -t sanger -o $(basename $(word 1, $^)).trimmed.fastq -p $(basename $(word 2, $^)).trimmed.fastq -s $(basename $(word 1, $^)).singles.fastq -q 30 -l 25 > $(basename $(word 1, $^)).filtersync.stats

%$(PEB_MARK).trimmed.$(FASTQ_EXTENSION): 
	@

# FastQC to check trimming
%.trimmed_fastqc: %$(PEA_MARK).trimmed.$(FASTQ_EXTENSION) %$(PEB_MARK).trimmed.$(FASTQ_EXTENSION)
	mkdir -p $@ && (SGE_RREQ="-now no -pe $(SGE_PE) $(FASTQC_THREADS)" $(FASTQC) --format fastq -q -t $(FASTQC_THREADS) -o $@ $^ || (rm -Rf $@ && false))


##############################
## Call the SV applications ##
##############################

%.meerkat.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/meerkat/makefile REFERENCE=$(REFERENCE) DATA_BAM=$< $@

%.bd.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/breakdancer/Makefile REFERENCE=$(REFERENCE) $@

%.pindel.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/pindel/Makefile REFERENCE=$(REFERENCE) PINDEL_DIR=../software/pindel/pindel_0.2.5a1 $@

%.delly.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/delly/Makefile REFERENCE=$(REFERENCE) $@

%.prism.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/prism/Makefile REFERENCE=$(REFERENCE) $@

%.gasv.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/gasv/makefile REFERENCE=$(REFERENCE) $@

%.clever.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/clever/Makefile REFERENCE=$(REFERENCE) IN=$< VERSION=$(CLEVER_VERSION) $@

%.svdetect.vcf: %.bam
	$(MAKE) -C $(PWD) -f $(MAKEFILE_DIR)/svdetect/makefile REFERENCE=$(REFERENCE) IN=$< $@


##############################
## Create comparison report ##
##############################

%.report.tex: $(SV_OUTPUT_2)
	$(EVALUATE_PREDICTIONS) -L $(REFERENCE_VCF) $^ > $@

%.report.pdf: %.report.tex
	pdflatex $^ && pdflatex $^


####################################
### Install software requirement ###
####################################
.PHONY: install

.SILENT:
install:
	echo Install python packages for the pipeline
	sudo apt-get install python-biopython
	

.PHONY: help
help:
	echo ALLBio pipeline

.PHONY: clean

clean:
	rm -rf *.bam *.bai *.sam *.flagstat *.fastqc *~
