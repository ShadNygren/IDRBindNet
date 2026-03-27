# IDRBindNet Docker Image — GPU with pre-loaded ProtT5 model
# Purpose: IDP-protein binding affinity (Kd) prediction
# Base: PyTorch with CUDA for GPU acceleration
#
# Build: docker build -t idrbindnet .
# Run (GPU):  docker run --gpus all -v /path/to/pdbs:/work idrbindnet --pdb_dir /work --gpu_id 0
# Run (CPU):  docker run -v /path/to/pdbs:/work idrbindnet --pdb_dir /work --gpu_id -1
#
# Image includes pre-loaded Rostlab/prot_t5_xl_bfd model (~4.2 GB)
# so there is no download delay at runtime.

FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

LABEL maintainer="Shad Nygren, Virtual Hipster Corporation"
LABEL description="IDRBindNet: IDP-protein binding affinity (Kd) prediction with GPU support"
LABEL version="1.1"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    csh \
    tcsh \
    gfortran \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies (no conda needed — base image has Python 3.10 + PyTorch)
RUN pip install --no-cache-dir \
    torch-geometric==2.6.1 \
    fair-esm==2.0.0 \
    "transformers>=4.33,<4.40" \
    biopython==1.81 \
    pandas \
    numpy \
    scipy \
    scikit-learn \
    mdtraj \
    freesasa \
    nmrglue \
    networkx \
    tqdm \
    pyyaml \
    sentencepiece \
    safetensors \
    contact_map

# Install SPARTA+ (chemical shift predictor required by IDRBindNet)
# The .tar.Z is actually gzip-compressed despite the extension
COPY SPARTA+/sparta+.tar.Z /opt/sparta+.tar.gz
RUN cd /opt && tar xzf sparta+.tar.gz && rm -f sparta+.tar.gz && \
    chmod +x /opt/SPARTA+/bin/SPARTA+.static.linux && \
    ln -sf /opt/SPARTA+/bin/SPARTA+.static.linux /opt/SPARTA+/bin/SPARTA+

# Create sparta+ wrapper script
RUN echo '#!/bin/bash' > /usr/local/bin/sparta+ && \
    echo 'export SPARTAP_DIR=/opt/SPARTA+' >> /usr/local/bin/sparta+ && \
    echo 'export SPARTA_DIR=/opt/SPARTA+' >> /usr/local/bin/sparta+ && \
    echo '/opt/SPARTA+/bin/SPARTA+ -spartaDir /opt/SPARTA+ "$@"' >> /usr/local/bin/sparta+ && \
    chmod +x /usr/local/bin/sparta+

ENV SPARTAP_DIR=/opt/SPARTA+
ENV SPARTA_DIR=/opt/SPARTA+

# Pre-load Rostlab/prot_t5_xl_bfd model (~4.2 GB)
# This avoids the 90+ minute download delay at runtime
RUN python -c "\
from transformers import T5Tokenizer, T5EncoderModel; \
T5Tokenizer.from_pretrained('Rostlab/prot_t5_xl_bfd', do_lower_case=False); \
T5EncoderModel.from_pretrained('Rostlab/prot_t5_xl_bfd'); \
print('ProtT5-BFD model pre-loaded successfully')"

# Copy IDRBindNet model weights (5 splits, ~177 MB)
COPY Prot_T5_BFD/ /app/Prot_T5_BFD/

# Copy IDRBindNet code
COPY GT-IDR-Bind/ /app/GT-IDR-Bind/

# Install SSH server for RunPod interactive access
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/sshd

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /work

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/bash"]
