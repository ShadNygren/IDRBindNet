#!/bin/bash
# Docker entrypoint for IDRBindNet
# Keeps container running for interactive use in RunPod and other cloud environments

set -e

# Print environment info
echo "==================================="
echo "IDRBindNet Docker Container Started"
echo "==================================="
echo "PyTorch version: $(python -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'Not available')"
echo "CUDA available: $(python -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'Not available')"
echo "GPU count: $(python -c 'import torch; print(torch.cuda.device_count())' 2>/dev/null || echo '0')"
if python -c 'import torch; assert torch.cuda.is_available()' 2>/dev/null; then
    echo "GPU name: $(python -c 'import torch; print(torch.cuda.get_device_name(0))' 2>/dev/null)"
    echo "GPU VRAM: $(python -c 'import torch; print(f\"{torch.cuda.get_device_properties(0).total_mem/1024**3:.1f} GB\")' 2>/dev/null)"
fi
echo ""
echo "SPARTA+: $(which sparta+ 2>/dev/null && echo 'installed' || echo 'NOT FOUND')"
echo "ProtT5 model: $(python -c 'from pathlib import Path; p=Path.home()/\".cache/huggingface/hub/models--Rostlab--prot_t5_xl_bfd\"; print(\"pre-loaded\" if p.exists() else \"will download at runtime\")' 2>/dev/null)"
echo "IDRBindNet weights: $(ls /app/Prot_T5_BFD/*.pth 2>/dev/null | wc -l) model splits"
echo "==================================="
echo ""
echo "To run IDRBindNet prediction:"
echo "  python3 /app/GT-IDR-Bind/run_all.py --pdb_dir /work --gpu_id 0"
echo ""
echo "PDB input format: Chain A = IDR (STELLA), Chain B = Protein (UHRF1)"
echo "==================================="

# Set working directory
cd /work 2>/dev/null || cd /root

# Check if we're running in RunPod environment
if [ -n "$RUNPOD_POD_ID" ] || [ -n "$RUNPOD_DC_ID" ]; then
    echo "Detected RunPod environment (Pod: ${RUNPOD_POD_ID})"
    echo "Starting SSH daemon for RunPod access..."

    # Start SSH service if available
    if command -v sshd &> /dev/null; then
        service ssh start 2>/dev/null || /usr/sbin/sshd || true
    fi

    echo "Container ready for connections"
    echo "Upload PDB files with SCP, then run predictions via SSH"

    # Keep container running
    while true; do
        sleep 3600
    done
elif [ $# -eq 0 ]; then
    # No command provided and not in RunPod - start interactive shell
    echo "Starting interactive shell..."
    exec /bin/bash
else
    # Execute the provided command
    exec "$@"
fi
