# -*- GNUMakefile -*-

-include Makefile.config
include Makefile.defaults

# Miscellaneous vars

MKDIR = mkdir -p

# ---

COPYBOOKS_SRC_DIR = app/cpy
COPYBOOKS_DST_DIR = $(BUILD_DIR)/cpy
COPYBOOK_SOURCES = $(wildcard $(COPYBOOKS_SRC_DIR)/*.cpy)
COPYBOOK_TARGETS = $(patsubst $(COPYBOOKS_SRC_DIR)/%,\
			      $(COPYBOOKS_DST_DIR)/%,\
			      $(COPYBOOK_SOURCES))

COPYBOOKS_BMS_SRC_DIR = app/cpy-bms
COPYBOOKS_BMS_DST_DIR = $(BUILD_DIR)/cpy-bms
COPYBOOK_BMS_SOURCES = $(wildcard $(COPYBOOKS_BMS_SRC_DIR)/*.CPY)
COPYBOOK_BMS_TARGETS = $(patsubst $(COPYBOOKS_BMS_SRC_DIR)/%,\
			      $(COPYBOOKS_BMS_DST_DIR)/%,\
			      $(COPYBOOK_BMS_SOURCES))
BMS_SRC_DIR = app/bms
MAP_DST_DIR = $(BUILD_DIR)/map
BMS_SOURCES = $(wildcard $(BMS_SRC_DIR)/*.bms)
MAP_TARGETS = $(patsubst $(BMS_SRC_DIR)/%.bms,\
			 $(MAP_DST_DIR)/%.map,\
			 $(BMS_SOURCES))

COB_SRC_DIR = app/cbl
COB_DST_DIR = $(BUILD_DIR)/cbl
COB_TARGETS =

COB_CORE_SOURCES = $(wildcard $(COB_SRC_DIR)/*.cbl)
COB_CORE_TARGETS = $(patsubst $(COB_SRC_DIR)/%,\
			      $(COB_DST_DIR)/%,\
			      $(COB_CORE_SOURCES))
COB_TARGETS += $(COB_CORE_TARGETS)

# cobc args

COBC_TMPS_DIR = $(BUILD_DIR)/cobc-temps
COBC_ARGS = -std=mf -g				\
	    -I$(COPYBOOKS_DST_DIR)		\
	    -I$(COPYBOOKS_BMS_DST_DIR)		\
	    -L$(SUPERKIX_LIB_DIR) -lsuperkix	\
	    -ext CPY

# Module targets:

SO_DST_DIR = $(BUILD_DIR)/cobol/modules
SO_TARGETS = $(patsubst $(COB_DST_DIR)/%.cbl,		\
			 $(SO_DST_DIR)/%.so,		\
			$(COB_CORE_TARGETS))			\

# ---

.PHONY: all
all:
	$(MAKE) preproc-copybooks preproc-copybooks-bms translate-bms
	$(MAKE) so-targets

.PHONY: debug
debug:
	@echo "COPYBOOK_TARGETS = $(COPYBOOK_TARGETS)"
	@echo "COPYBOOK_BMS_TARGETS = $(COPYBOOK_BMS_TARGETS)"
	@echo "MAP_TARGETS = $(MAP_TARGETS)"
	@echo "COB_TARGETS = $(COB_TARGETS)"
	@echo "SO_TARGETS = $(SO_TARGETS)"

# copybook pre-processing.

.PHONY: preproc-copybooks
preproc-copybooks: $(COPYBOOK_TARGETS)

.INTERMEDIATE: $(COPYBOOKS_DST_DIR)/%.cpy
$(COPYBOOKS_DST_DIR)/%.cpy: $(COPYBOOKS_SRC_DIR)/%.cpy
	@$(MKDIR) $(COPYBOOKS_DST_DIR)
#	$(PADBOL) cics preproc -v $< > $@
	ln -sfr $< $@

.PHONY: preproc-copybooks-bms
preproc-copybooks-bms: $(COPYBOOK_BMS_TARGETS)

.INTERMEDIATE: $(COPYBOOKS_BMS_DST_DIR)/%.CPY
$(COPYBOOKS_BMS_DST_DIR)/%.CPY: $(COPYBOOKS_BMS_SRC_DIR)/%.CPY
	@$(MKDIR) $(COPYBOOKS_BMS_DST_DIR)
#	$(PADBOL) cics preproc -v $< > $@
	ln -sfr $< $@

# BMS processing

.PHONY: translate-bms
translate-bms: $(MAP_TARGETS)

$(MAP_DST_DIR)/DFHZSGM.map: $(BMS_SRC_DIR)/DFHZCSGM.bms
	$(makemap)
$(MAP_DST_DIR)/%.map: $(BMS_SRC_DIR)/%.bms
	$(makemap)

define makemap
	@$(MKDIR) $(MAP_DST_DIR)
	$(PADBOL) bms parse --output-phys=$(MAP_DST_DIR) $<
endef

# COBOL

.PHONY: cobol-targets
cobol-targets: $(COB_TARGETS)

.INTERMEDIATE: $(COB_DST_DIR)/%

$(COB_DST_DIR)/data/sql/%: $(COB_SRC_DIR)/data/sql/%
	@$(MKDIR) "$$(dirname "$@")"
	$(PADBOL) cics preproc -v $< > $@-1	\
		-I $(COPYBOOKS_DST_DIR)		\
		-I $(COPYBOOKS_BMS_DST_DIR)	\
		--copybooks
	$(GIXPP) -e -S -p -i $@-1 -o $@		\
		-I $(GIXPP_COPYBOOKS_DIR)	\
		-I $(COPYBOOKS_DST_DIR)		\
		-I $(COPYBOOKS_BMS_DST_DIR)

$(COB_DST_DIR)/%: $(COB_SRC_DIR)/%
	@$(MKDIR) "$$(dirname "$@")"
	$(PADBOL) cics preproc -v $< > $@	\
		--copybooks			\
		-I $(COPYBOOKS_DST_DIR)		\
		-I $(COPYBOOKS_BMS_DST_DIR)

# modules

.PHONY: so-targets
so-targets: $(SO_TARGETS)

$(SO_DST_DIR)/data/sql/%.so: $(COB_DST_DIR)/data/sql/%.cbl
	@$(MKDIR) "$$(dirname "$@")" $(COBC_TMPS_DIR)
	$(COBC) $(COBC_ARGS) $< -o $@		\
		--save-temps=$(COBC_TMPS_DIR)	\
		-I $(GIXPP_COPYBOOKS_DIR)	\
		-L $(GIX_LIB_DIR)

$(SO_DST_DIR)/%.so: $(COB_DST_DIR)/%.cbl
	@$(MKDIR) "$$(dirname "$@")" $(COBC_TMPS_DIR)
	$(COBC) $(COBC_ARGS) $< -o $@		\
		--save-temps=$(COBC_TMPS_DIR)

# cleanup

.PHONY: clean
clean:	 # Note: bit dangerous (take care when redefining $(BUILD_DIR)
	-rm -rf $(BUILD_DIR)

# misc.

$(BUILD_DIR)		\
$(SO_DST_DIR)		\
$(MAP_DST_DIR)		\
$(COB_DST_DIR)		\
$(COBC_TMPS_DIR)	\
$(COPYBOOKS_DST_DIR)	\
$(COPYBOOK_BMS_DST_DIR):
	mkdir -p $@

