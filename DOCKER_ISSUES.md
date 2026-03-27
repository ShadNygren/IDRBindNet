# IDRBindNet Docker Image Issues Found During Testing

**Date**: 2026-03-27
**Pod**: zj9st8v42whdgy (RTX A4000, RunPod)

## Issues Found

### 1. No `python3` in PATH
**Symptom**: `bash: python3: command not found`
**Root cause**: PyTorch base image (`pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime`) puts Python at `/opt/conda/bin/python3` but the container's PATH doesn't include `/opt/conda/bin/` when SSH'd in.
**Also**: `run_all.py` calls subprocess with `python3` which fails even when invoked via full path.
**Fix**: Add `ln -sf /opt/conda/bin/python3 /usr/local/bin/python3` to Dockerfile.

### 2. No SSH authorized_keys
**Symptom**: `Permission denied (publickey,password)` when SSH'ing from laptop.
**Root cause**: Docker image has no `/root/.ssh/authorized_keys`. RunPod does NOT inject SSH keys automatically — the container must set them up.
**Fix**: Entrypoint script must create `/root/.ssh/authorized_keys` with our public keys.

### 3. sshd_config doesn't allow root login
**Symptom**: Even with correct keys, SSH rejected.
**Root cause**: Default `sshd_config` has `#PermitRootLogin prohibit-password` (commented out, defaults vary by version).
**Fix**: Dockerfile must `sed` uncomment and set `PermitRootLogin yes`.

### 4. PubkeyAcceptedKeyTypes vs PubkeyAcceptedAlgorithms
**Symptom**: `Bad configuration option: PubkeyAcceptedAlgorithms`
**Root cause**: OpenSSH 8.2 (Ubuntu 20.04 in PyTorch base image) uses `PubkeyAcceptedKeyTypes`. The rename to `PubkeyAcceptedAlgorithms` happened in OpenSSH 8.5 (March 2021).
**Fix**: Use `PubkeyAcceptedKeyTypes +ssh-rsa` in Dockerfile.

### 5. RSA key got line-wrapped in authorized_keys
**Symptom**: RSA key rejected even with correct sshd config.
**Root cause**: When pasting the long RSA key into Web Terminal, it got wrapped across multiple lines, corrupting the key.
**Fix**: Bake the key into the Docker image via Dockerfile (no manual paste needed). Also include ed25519 key.

### 6. No conda env `kd_predict` created
**Symptom**: `ls: cannot access '/opt/conda/envs/kd_predict/bin/python*': No such file or directory`
**Root cause**: Dockerfile used `pip install` directly into the base image instead of creating a conda env. The base image already has Python 3.10 + PyTorch, so direct pip install is fine — but `run_all.py` and subscripts call `python3` which isn't in PATH.
**Fix**: Symlink python3 to /usr/local/bin/. No conda env needed.

### 7. Entrypoint auto-runs prediction with no input
**Symptom**: `No KD CSV files found` loop in logs on pod startup.
**Root cause**: Original entrypoint ran `run_all.py --pdb_dir /work` immediately. Empty /work = no PDBs = loop.
**Fix**: Entrypoint starts SSH daemon and stays alive. User SSHs in, uploads PDBs, runs manually.

### 8. ProtT5 model not pre-loaded (first-run issue)
**Symptom**: 90+ minute delay on first run downloading Rostlab/prot_t5_xl_bfd (4.2 GB) from HuggingFace.
**Root cause**: Model downloaded at runtime, not baked into image.
**Fix**: Dockerfile pre-downloads model during build with `python -c "from transformers import T5Tokenizer, T5EncoderModel; ..."`. Increases image size by ~4.2 GB but eliminates runtime delay.

## Summary of Dockerfile Fixes Needed

```dockerfile
# 1. Symlink python3 into standard PATH
RUN ln -sf /opt/conda/bin/python3 /usr/local/bin/python3 && \
    ln -sf /opt/conda/bin/python /usr/local/bin/python

# 2. Configure sshd for root login + RSA keys
RUN sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config && \
    echo "PubkeyAcceptedKeyTypes +ssh-rsa" >> /etc/ssh/sshd_config

# 3. Bake SSH public keys into image
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# 4. Entrypoint: start sshd, stay alive for interactive use
# (via docker-entrypoint.sh following Protenix pattern)
```
