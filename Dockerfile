
# Main image
FROM debian:latest

# Variable to specify if running on GitHub Action or localy (prevent GitHub action resource issues)
ARG RUNS_ON_GITHUB=false

LABEL maintainer="flo-mic" \
   description="Deepspeech docker image with german model."

# environment variables
ENV ARCH="x86_64" \    
   MIRROR=http://dl-cdn.alpinelinux.org/alpine \
   PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
   HOME="/root" \
   TERM="xterm"

#Copy Install scripts
COPY install.sh /tmp/

# Install image components
RUN ./tmp/install.sh && rm -rf /tmp/*

# Copy/replace root files
COPY services.d/ /etc/services.d/

# Expose needed ports
EXPOSE 8080

# Entrypoint of S6 overlay
ENTRYPOINT [ "/init" ]

