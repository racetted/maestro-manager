# common section definition
include config.mk

ssm: profile.sh
	echo "Creating SSM package $(SSMPACKAGE)..."
	if [ ! -d $(SSMPACKAGE) ]; then \
	   mkdir $(SSMPACKAGE); \
	fi;
	cp -r $(SWDEST)/bin $(SSMPACKAGE); 
	cp -r $(SWDEST)/lib $(SSMPACKAGE); 
	cp -r $(SWDEST)/etc $(SSMPACKAGE); 
	cp -r ../LICENSE.txt $(SSMPACKAGE); 
	mkdir -p $(SSMPACKAGE)/.ssm.d;
	cp -r post-install $(SSMPACKAGE)/.ssm.d;
	cp -r profile.sh $(SSMPACKAGE)/.ssm.d;
	echo "Package: maestro-manager" > $(SSMPACKAGE)/.ssm.d/control; \
	echo "Version: ${VERSION}" >> $(SSMPACKAGE)/.ssm.d/control; \
	echo "Platform: all" >> $(SSMPACKAGE)/.ssm.d/control; \
	echo "Maintainer: $(shell whoami)" >> $(SSMPACKAGE)/.ssm.d/control; \
	echo "BuildInfo:" >> $(SSMPACKAGE)/.ssm.d/control; \
	echo "Description: Maestro Manager" >> $(SSMPACKAGE)/.ssm.d/control; \
	tar cvf - $(SSMPACKAGE) | gzip -> $(SSMPACKAGE).ssm

profile.sh: Makefile config.mk
	echo "export SEQ_MANAGER_VERSION=${VERSION}" >$@

clean:
	rm -fr profile.sh $(SSMPACKAGE).ssm $(SSMPACKAGE)
