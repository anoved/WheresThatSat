# Tools
CP = /bin/cp
MKDIR = /bin/mkdir
LN = /bin/ln

# Directories
DEPLOY_DIR = /Users/anoved/Documents/WheresThatSatBot

.PHONY: update deploy link

# Called to update deployment directory
# (just copies bot and catalog update scripts)
update:
	$(CP) UpdateCatalog.rb $(DEPLOY_DIR)
	$(CP) WheresThatSat.rb $(DEPLOY_DIR)
	$(CP) wtsutil.rb $(DEPLOY_DIR)

# Called once to create a deployment directory
# (creates directories and installs gtg and bot config files)
deploy:
	# create directories
	$(MKDIR) -p $(DEPLOY_DIR)
	$(MKDIR) -p $(DEPLOY_DIR)/config
	# install default config files
	$(CP) default-config/WheresThatSat.yml $(DEPLOY_DIR)
	$(CP) default-config/intervals.yml $(DEPLOY_DIR)/config
	$(CP) default-config/sat_searches.yml $(DEPLOY_DIR)/config
	$(CP) default-config/tle_sources.yml $(DEPLOY_DIR)/config
	# install tools
	$(CP) gtg $(DEPLOY_DIR)
	# install scripts
	$(CP) UpdateCatalog.rb $(DEPLOY_DIR)
	$(CP) WheresThatSat.rb $(DEPLOY_DIR)
	$(CP) wtsutil.rb $(DEPLOY_DIR)

# Make links to the deployment config and tle files and directories
# in the development folder so that we can test-run with same setup.
link:
	$(LN) -s $(DEPLOY_DIR)/config config
	$(LN) -s $(DEPLOY_DIR)/WheresThatSat.yml WheresThatSat.yml
