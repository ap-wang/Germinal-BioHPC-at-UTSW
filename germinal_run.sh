#!/bin/bash
#SBATCH --job-name=germinal
#SBATCH --gres=gpu:1
#SBATCH -p GPUA100
#SBATCH --mem=256g
#SBATCH --cpus-per-task=8
#SBATCH --time=100-00:00
#SBATCH -o germinal_%j.log
#SBATCH -e germinal_%j.err

# ==============================================================================
echo "Starting Germinal Run on Host: $HOSTNAME"


#Load BioHPC modules Alphafold
module load singularity/3.9.9
module load apptainer/1.4.1
module load alphafold3/3.0.0

# Reroute Runtime Caches to Project Space to Protect home2 quota
# ---------------------------------------------------------------------------
export HF_HOME=/project/SCCC/Siegwart_lab/shared/.cache/huggingface
export TORCH_HOME=/project/SCCC/Siegwart_lab/shared/.cache/torch
export TRITON_CACHE_DIR=/project/SCCC/Siegwart_lab/shared/.cache/triton
mkdir -p $HF_HOME $TORCH_HOME $TRITON_CACHE_DIR

# Prevent JAX Out-Of-Memory (OOM) Errors (especially on GPUs with limited memory, happens a lot)
export XLA_PYTHON_CLIENT_PREALLOCATE=false
export XLA_CLIENT_MEM_FRACTION=0.5

# Ensure output directory exists before running
mkdir -p jobs

# Activate the environment via absolute path- note that germinal has be sym-linked to path to save space on home2:
conda activate /project/SCCC/Siegwart_lab/shared/envs/germinal

# Navigate to the repository containing the code and SLURM script.
cd /project/SCCC/Siegwart_lab/shared/germinal

#under 'module show', here are the paths to the .sif file executing Alphafold3 and weights
AF3_SIF_PATH=/project/apps/singularity-images/alphafold3/3.0.0/alphafold3_container.sif
AF3_DB_PATH=/project/apps_database/alphafold3/database_full
AF3_MODEL_PARAM_PATH=/project/apps_database/alphafold3/model_params

# Run Germinal targeting your VHH configuration [this is with Chai-1] (change your configs here)
#Germinal's AF3 wrapper will pass the directories through singularity container- ensure to append them to the end of your run using Hydra's syntax (+)
python -u run_germinal.py \
    run=vhh_pdl1 \
    experiment_name=test_vhh_run \
    filter/initial=vhh_pdl1 \
    filter/final=vhh_pdl1 \
    target=pdl1 \
    structure_model=af3 \
    +structure_model.singularity_image_path=$AF3_SIF_PATH \
    +structure_model.db_dir=$AF3_DB_PATH \
    +structure_model.model_dir=$AF3_MODEL_PARAM_PATH

echo "finished"

#==============================================================================
#if isusing AF3 use the following commands: 
    #python -u run_germinal.py \
    #run=vhh_pdl1 \
    #filter/initial=vhh_pdl1 \
    #filter/final=vhh_pdl1_af3 \
    #target=pdl1 \
    #+structure_model.singularity_image_path=/project/SCCC/Siegwart_lab/shared/singularity/alphafold3.sif