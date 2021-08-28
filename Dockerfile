
# Main image
FROM debian:latest

# Variable to specify if running on GitHub Action or localy (prevent GitHub action resource issues)
ARG RUNS_ON_GITHUB=false

LABEL maintainer="flo-mic" \
   description="Deepspeech docker image with german model."

# environment variables
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine \
   PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
   HOME="/root" \
   TERM="xterm"

# Install image components
RUN echo "**** install packages ****" && \
   apt update && \
   apt install --upgrade -y \
      bash \
      git \
      nano \
      python3-pip \
      tzdata \
      wget && \
      \
      # Install S6 Overlay \
      wget --quiet https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64-installer -O /tmp/s6-overlay-installer \
      echo "**** Install S6 overlay ****" && \
      chmod +x /tmp/s6-overlay-installer && \
      /tmp/s6-overlay-installer / && \
      # Install deepspeech \
      pip3 install av && \
      pip3 install deepspeech && \
      pip3 install deepspeech-server && \
      # Download german language model \
      git clone https://github.com/synesthesiam/de_deepspeech-aashishag /tmp/de_deepspeech && \
      cd /tmp/de_deepspeech/model && \
      # Extract files \
      mkdir -p /data && \
      cat base.scorer.gz.part-* | gunzip -c > /data/base.scorer && \
      cat output_graph.pbmm.gz.part-* | gunzip -c > /data/output_graph.pbmm && \
      # Cleanup before deploying \
      echo "**** clean build files ****" && \
      rm -rf \
         /root/.cache \
         /root/.cargo \
         /tmp/* \
         /var/cache/apt/* 

# Copy/replace root files
COPY services.d/ /etc/services.d/

# Expose needed ports
EXPOSE 8080

# Entrypoint of S6 overlay
ENTRYPOINT [ "/init" ]

