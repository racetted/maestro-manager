# this file contains common config that is sourced by all makefiles
VERSION=1.4.1
ARCH=all
SWDEST=$(shell pwd)/..

# platform specific definition
SSMPACKAGE=maestro-manager_${VERSION}_$(ARCH)
