# Tools
CP = /bin/cp
MKDIR = /bin/mkdir

# Directories
DEPLOY_DIR = /Users/anoved/Documents/WheresThatSatBot

.PHONY: deploy

deploy:
	$(MKDIR) -p $(DEPLOY_DIR)
	$(CP) UpdateCatalog.rb $(DEPLOY_DIR)
	$(CP) WheresThatSat.rb $(DEPLOY_DIR)
	$(CP) WheresThatSat.yml $(DEPLOY_DIR)
	$(MKDIR) -p $(DEPLOY_DIR)/config
	$(CP) config/*.yml $(DEPLOY_DIR)/config
	$(MKDIR) -p $(DEPLOY_DIR)/tle
	$(CP) tle/*.tle $(DEPLOY_DIR)/tle
	$(CP) gtg $(DEPLOY_DIR)
