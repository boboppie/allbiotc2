# Makefile - GASV module for the AllBioTC2 pipeline
#
# (c) 2013 - Wai Yi Leung
# (c) 2013 AllBio (see AUTHORS file)

########################
### Pipeline Setting ###
########################

SQ_CENTER = BGI
PLATFORM = ILLUMINA

# SGE configuration.
SGE_PE = BWA

# Keep all files (Todo: In view of disk space, maybe we shouldn't do this?).
.SECONDARY:

# Delete target if recipe returns error status code.
.DELETE_ON_ERROR:

# Makefile specific settings
MAKEFILE_DIR := $(realpath $(dir $(realpath $(firstword $(MAKEFILE_LIST)))))
THIS_MAKEFILE_DIR := $(realpath $(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

#####################
### Used Programs ###
#####################
include $(MAKEFILE_DIR)/../conf.mk


# GASV
GASV_DIR := $(PROGRAMS_DIR)/gasv/GASVRelease_Oct1_2013
BAM2GASV := $(GASV_DIR)/bin/BAMToGASV.jar
GASV := $(GASV_DIR)/bin/GASV.jar
JAVA := java -Xms512m -Xmx2048m -jar

GASVProHQ := $(GASV_DIR)/bin/GASVPro-HQ.sh
GASVPro := $(GASV_DIR)/bin/GASVPro.sh

GASV2VCF := python $(THIS_MAKEFILE_DIR)/gasv2vcf.py

###############
### Targets ###
###############

all: $(OUT)

#########################
### Rules and Recipes ###
#########################

# expect $(IN) = *.bam

# Just for make -n
%.bam:
	@

%.gasv/sample.gasv.in: %.bam
	mkdir -p $(dir $@);
	$(JAVA) $(BAM2GASV) $< -OUTPUT_PREFIX $(dir $@)sample

%.gasv/sample.gasv.in.txt: %.gasv/sample.gasv.in
	sed 's:$(basename $<)/:$(dir $@):g' $< > $@

%.gasv/sample.gasv.in.txt.clusters: %.gasv/sample.gasv.in.txt
	cd $(dir $@);$(JAVA) $(GASV) --batch $?

%.gasv.vcf: %.gasv/sample.gasv.in.txt.clusters
	$(GASV2VCF) $< $@ BWA

