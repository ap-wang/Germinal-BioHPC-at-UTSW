# Germinal on UTSW BioHPC: Complete Setup & Execution Guide
**Author:** [AP Wang](https://github.com/ap-wang) | UTSW [Siegwart Lab](https://siegwartlab.com/)


This guide details the specific workflow for deploying the Germinal generative antibody pipeline on the UTSW BioHPC cluster. Due to strict home2 storage quotas, institutional restrictions, and specific Slurm configurations, modifications are necessary to meet UTSW BioHPC guidelines. Follow these steps for full reproducibility.

1. Storage Routing (if needed due to home2 storage) & Environment Setup:
BioHPC limits /home2/ storage. Germinal requires large packages(PyTorch, JAX, HuggingFace models) that may exceed standard quotas (especially if you have many conda envs already set up). In this workflow, all environments and caches are routed to /project/ space (where there is more storage).

# 1. Define your shared project path (Adjust as necessary) 
    export PROJECT_DIR=/project/SCCC/Siegwart_lab/shared (change the path to your corresponding lab)

# 2. Clone the Germinal repository
    cd $PROJECT_DIR
    git clone https://github.com/SantiagoMille/germinal.git germinal_repo
    cd germinal_repo

# 3. Download ColabDesign AlphaFold-Multimer Weights (.npz files)
    cd params
    aria2c -x 16 https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar
    tar -xf alphafold_params_2022-12-06.tar -C .
    cd ..

OR if you already have the multimer parameters, move them into the params dir in geminal as ColabDesign looks for these. If you do not, speak with author, he can share the parameters if you don't want to follow the instructions above in using wget and tar for parameters. 

# 4. Create the Conda Environment
Build the environment directly in the project space (if you're running out of space in home2), then optionally symlink it to your home directory for easier activation.

Create the environment physically in the project space

    conda create -p $PROJECT_DIR/envs/germinal python=3.10
Create a targeted symlink so Conda recognizes it by name
    
    ln -s $PROJECT_DIR/envs/germinal ~/.conda/envs/germinal

Activate

    conda activate germinal

# 5. Dependency Installation
Reroute uv pip Caches
Before installing any packages, force the temporary package caches to the high-capacity project drive

    export UV_CACHE_DIR=$PROJECT_DIR/.cache/uv
    export PIP_CACHE_DIR=$PROJECT_DIR/.cache/pip
    mkdir -p $UV_CACHE_DIR $PIP_CACHE_DIR


# 6. Install PyRosetta (Firewall Bypass)
The UTSW network firewall will block automated downloads of PyRosetta via script or --find-links (403 ServerBrowsingOfPersonalWebSitesBlock). You must install it manually.
On a personal computer(or work desktop), log in to the PyRosetta Quarterly Release Mirror: https://west.rosettacommons.org/pyrosetta/quarterly/release/
Download the Python 3.10 Ubuntu wheel: pyrosetta-...-cp310-cp310-linux_x86_64.whl.
Transfer the .whl file to the cluster via scp or the BioHPC Web Portal.
Install the local file: 

    uv pip install ./pyrosetta-*-cp310-cp310-linux_x86_64.whl

# 7. Install Deep Learning Packages
Ensure you are physically inside the germinal_repo directory then Install core ML libraries:

    uv pip install iglm torchvision==0.21.* chai-lab==0.6.1 torch==2.6.* torchaudio==2.6.* torchtyping==0.1.5 torch_geometric==2.6.*

# 8. Pin specific JAX and Hydra versions for compatibility
    uv pip install jax==0.5.3 dm-haiku==0.0.13 hydra-core omegaconf
    uv pip install "jax[cuda12_pip]==0.5.3" -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
    uv pip install ablang2 --no-deps
    uv pip install rotary_embedding_torch --no-deps 

# 9. Install local editable packages
    uv pip install -e colabdesign
    uv pip install -e .

# 10. BioHPC AF3 Paths 
You will need to pass these specific BioHPC module paths to your Slurm script (This is established on the bash script germina_run.sh):

    AF3_SIF_PATH=/project/apps/singularity-images/alphafold3/3.0.0/alphafold3_container.sif
    AF3_DB_PATH=/project/apps_database/alphafold3/database_full
    AF3_MODEL_PARAM_PATH=/project/apps_database/alphafold3/model_params (Contains af3.bin.zst)

# 11. Run Germinal: 
sbatch germinal_run.sh

# 12. Live Monitoring & Tracking (a few recommendations):
ssh into your node (eg. NucleusC097)

Launch monitoring tool: nvtop (requires installation): Live GPU VRAM and compute utilization. Expect bursts of 100% compute during ColabDesign hallucination and heavy VRAM usage during AF3 prediction.

    nvtop 

launch monitoring tool: btop (requires installation): Live CPU/Memory utilization. Expect heavy core usage during PyRosetta scoring and AF3 MSA generation.

    btop

built-in with BioHPC of nvidia-smi (this allows you to watch the GPU usage in real time with bursts of GPU usage like nvtop)

    watch -n 1 nvidia-smi 

Pipeline Monitoring (From the Login Node)
Keep track of the model's design loop and acceptances in real-time by tracking the output files:
Watch the trajectory .log file that's built into the slurm script: (this will cover your terminal, if you'd like you can also just click on the .log file)

    tail -f germinal_*.log

Watch the trajectory metrics update live (iPAE, pLDDT, etc.)

    tail -f /project/SCCC/Siegwart_lab/shared/germinal/results/test_vhh_run/all_trajectories.csv

Watch for fully accepted PDB files that pass all AF3 filters (you will have to change the "test_vhh_run" to the name that you called for in your configuration settings within the .sh) 

    watch -n 10 "ls -la /project/SCCC/Siegwart_lab/shared/germinal/results/test_vhh_run/trajectories/structures" 
    
alterinatively, you can also just cd into the dir and crt + click the file to track it live. It is a throttled version, so if you'd like to see if live every 10 seconds, then reocmmendation is to use the watch command. 
