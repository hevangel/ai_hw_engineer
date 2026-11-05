#!/bin/bash
# Build the SIMH PDP-1 oracle image (pdp1-oracle:local) on Ubuntu 24.04.
# Invoked with a directory containing this Dockerfile and, after the build,
# bin_pdp1 in the mounted work directory.
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq build-essential libedit-dev libpng-dev libsdl2-dev git > /work/oracle_apt.log 2>&1
cd /work
rm -rf simh
git clone -q --depth 1 https://github.com/simh/simh.git simh
cd simh
git rev-parse HEAD > /work/ref/simh_commit.txt
# PCRE only serves the SEND/EXPECT helpers; the oracle needs none of it and
# Ubuntu 24.04 no longer ships libpcre3-dev. Override the package table so the
# makefile's dependency probe does not block on it.
make pdp1 -j 4 BUILD_SEPARATE=1 QUIET=1 \
    PKGS_SRC_APT='gcc - - - libedit-dev libsdl2-dev libpng-dev - - - - - build-essential:/usr/share/build-essential' \
    > /work/oracle_build.log 2>&1
cp BIN/pdp1 /work/bin_pdp1
ls -l /work/bin_pdp1
