#!/bin/bash
# Docker entrypoint for IDRBindNet
# Follows the same pattern as our Protenix Docker image

set -e

echo "==================================="
echo "IDRBindNet Docker Container Started"
echo "==================================="
echo "PyTorch: $(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null || echo 'N/A')"
echo "CUDA: $(python3 -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null || echo 'N/A')"
if python3 -c 'import torch; assert torch.cuda.is_available()' 2>/dev/null; then
    echo "GPU: $(python3 -c 'import torch; print(torch.cuda.get_device_name(0))' 2>/dev/null)"
    echo "VRAM: $(python3 -c 'import torch; print(f"{torch.cuda.get_device_properties(0).total_mem/1024**3:.1f} GB")' 2>/dev/null)"
fi
echo "SPARTA+: $(which sparta+ 2>/dev/null && echo 'OK' || echo 'NOT FOUND')"
echo "==================================="
echo ""
echo "To run: python3 /app/GT-IDR-Bind/run_all.py --pdb_dir /work --gpu_id 0"
echo "Input:  Chain A = IDR (STELLA), Chain B = Protein (UHRF1)"
echo "==================================="

cd /work 2>/dev/null || cd /root

# RunPod environment
if [ -n "$RUNPOD_POD_ID" ] || [ -n "$RUNPOD_DC_ID" ]; then
    echo "RunPod Pod: ${RUNPOD_POD_ID}"

    # Set up SSH authorized keys from environment variable if provided
    # Pass SSH_PUBLIC_KEY when creating the pod, or set it in RunPod template
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        echo "SSH key installed from SSH_PUBLIC_KEY env var"
    elif [ -n "$PUBLIC_KEY" ]; then
        echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        echo "SSH key installed from PUBLIC_KEY env var"
    else
        echo "WARNING: No SSH_PUBLIC_KEY env var set — SSH login will require manual key setup via Web Terminal"
    fi

    # Start SSH
    if command -v sshd &> /dev/null; then
        service ssh start 2>/dev/null || /usr/sbin/sshd || true
    fi

    echo "SSH: ssh root@${RUNPOD_PUBLIC_IP} -p ${RUNPOD_TCP_PORT_22}"
    echo "Container ready"

    while true; do
        sleep 3600
    done
elif [ $# -eq 0 ]; then
    exec /bin/bash
else
    exec "$@"
fi
