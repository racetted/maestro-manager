# this file contains common config that is sourced by all makefiles
VERSION=1.5.2
ARCH=all
SWDEST=$(shell pwd)/..

# platform specific definition
SSMPACKAGE=maestro-manager_${VERSION}_$(ARCH)
