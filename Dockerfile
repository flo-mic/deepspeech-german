# Build image
FROM debian:latest as base

# environment variables
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine \
   PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
   HOME="/root" \
   TERM="xterm" \
   DEBIAN_FRONTEND=noninteractive \
   TFDIR=/DeepSpeech/tensorflow

# Compile deepspeech for custom CPU architecture
RUN apt-get update && apt-get install -y --no-install-recommends \
         apt-utils \
         bash-completion \
         build-essential \
         ca-certificates \
         cmake \
         curl \
         g++ \
         gcc \
         git \
         libbz2-dev \
         libboost-all-dev \
         libgsm1-dev \
         libltdl-dev \
         liblzma-dev \
         libmagic-dev \
         libpng-dev \
         libsox-fmt-mp3 \
         libsox-dev \
         locales \
         pkg-config \
         python3 \
         python3-dev \
         python3-pip \
         python3-wheel \
         python3-numpy \
         sox \
         unzip \
         wget \
         zlib1g-dev; \
      update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1 && \
      update-alternatives --install /usr/bin/python python /usr/bin/python3 1 && \
      # Install pip prerequirements and bazel
      pip3 install sox && \
      pip3 install -U --user pip numpy wheel && \
      pip3 install -U --user keras_preprocessing --no-deps && \
      wget https://github.com/bazelbuild/bazel/releases/download/3.7.2/bazel-3.7.2-linux-x86_64 && \
      chmod +x bazel-3.7.2-linux-x86_64 && \
      mv bazel-3.7.2-linux-x86_64 /bin/bazel && \
      # Get deepspeech files
      git clone https://github.com/mozilla/DeepSpeech.git && \
      cd /DeepSpeech && \
      git submodule sync tensorflow/ && \
      git submodule update --init tensorflow/ && \
      git submodule sync kenlm/ && git submodule update --init kenlm/ && \
      # Configure tensorflow for custom cpu without AVX support
      CPU_COMPILE_FLAGS=$(grep flags -m1 /proc/cpuinfo | cut -d ":" -f 2 | tr '[:upper:]' '[:lower:]' | { read FLAGS; OPT="--copt=-march=native"; for flag in $FLAGS; do case "$flag" in "sse4_1" | "sse4_2" | "ssse3" | "fma" | "cx16" | "popcnt" | "avx" | "avx2") OPT+=" --copt=-m$flag";; esac; done; MODOPT=${OPT//_/\.}; echo "$MODOPT"; }) && \
      cd /DeepSpeech/tensorflow && \
      ./configure && \
      bazel build -c opt ${CPU_COMPILE_FLAGS} //native_client:libdeepspeech.so \
         --workspace_status_command="bash native_client/bazel_workspace_status_cmd.sh" \
         --config=monolithic \
         --verbose_failures \
         --action_env=LD_LIBRARY_PATH=${LD_LIBRARY_PATH} && \
      cp bazel-bin/native_client/libdeepspeech.so /DeepSpeech/native_client/ && \
      cd /DeepSpeech/native_client && make NUM_PROCESSES=$(nproc) deepspeech && \
      cd /DeepSpeech/native_client/python && make NUM_PROCESSES=$(nproc) bindings



# Create main image
FROM debian:latest

# Variable to specify if running on GitHub Action or localy (prevent GitHub action resource issues)
ARG RUNS_ON_GITHUB=false

LABEL maintainer="flo-mic" \
   description="Deepspeech docker image with german model."

# environment variables
ENV MIRROR=http://dl-cdn.alpinelinux.org/alpine \
   PS1="$(whoami)@$(hostname):$(pwd)\\$ " \
   HOME="/root" \
   TERM="xterm" \
   DEBIAN_FRONTEND=noninteractive

# Copy pip wheel file for install
COPY --from=base /DeepSpeech/native_client/python/dist/ /tmp/native_client_pkg

# Compile deepspeech for custom CPU architecture
RUN apt-get update && apt-get install -y --no-install-recommends \
         git \
         python3 \
         python3-pip \
         sox \
         tzdata \
         unzip \
         wget && \
      # Install S6 Overlay \
      wget --quiet https://github.com/just-containers/s6-overlay/releases/latest/download/s6-overlay-amd64-installer -O /tmp/s6-overlay-installer && \
      echo "**** Install S6 overlay ****" && \
      chmod +x /tmp/s6-overlay-installer && \
      /tmp/s6-overlay-installer / && \
      # Install deepspeech \
      pip3 install av && \
      pip3 install --upgrade /tmp/native_client_pkg/*.whl; \
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
         /var/cache/apt/*  && \
      apt clean

# Copy/replace root files
COPY services.d/ /etc/services.d/
COPY config.json /data/config.json

# Expose needed ports
EXPOSE 8080

# Entrypoint of S6 overlay
ENTRYPOINT [ "/init" ]

