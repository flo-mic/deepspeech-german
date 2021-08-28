#!/bin/sh

# Enable early exit in case of errors
set -e
set -o pipefail

# Get available cpu cores to improve compile time
if [[ $RUNS_ON_GITHUB = false ]]; then
    CPU_CORES=$(nproc --all)
else
    CPU_CORES=1
fi
export CPU_CORES

# Install packages
echo "**** install packages ****"
apt update
apt install --upgrade -y \
    bash \
    git \
    nano \
    python3-pip \
    tzdata \
    wget

# Download S6 Overlay files
if [[ ${ARCH} = "x86_64" ]]; then
    wget --quiet https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64-installer -O /tmp/s6-overlay-installer
else
    wget --quiet https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-arm-installer -O /tmp/s6-overlay-installer
fi

# Install S6 overlay
echo "**** Install S6 overlay ****"
chmod +x /tmp/s6-overlay-installer
/tmp/s6-overlay-installer /
rm /tmp/s6-overlay-installer

# Install deepspeech
pip3 install av
pip3 install deepspeech
pip3 install deepspeech-server

# Download german language model
git clone https://github.com/synesthesiam/de_deepspeech-aashishag /tmp/de_deepspeech
cd /tmp/de_deepspeech/model

# Extract files
mkdir -p /data
cat base.scorer.gz.part-* | gunzip -c > /data/base.scorer
cat output_graph.pbmm.gz.part-* | gunzip -c > /data/output_graph.pbmm


# Cleanup before deploying
echo "**** clean build files ****"
rm -rf \
    /root/.cache \
    /root/.cargo \
    /tmp/* \
    /var/cache/apt/* 
