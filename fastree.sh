#!/bin/bash
#PBS -N pmoA_reference_tree
#PBS -l walltime=12:00:00
#PBS -l select=1:ncpus=8:mem=16gb
#PBS -o /rds/general/user/jc224/home/pmoA_output/pipeline1_reference_tree.out
#PBS -e /rds/general/user/jc224/home/pmoA_output/pipeline1_reference_tree.err

# --- Load Modules ---
module load MAFFT/7.520-GCC-12.3.0-with-extensions
module load FastTree/2.1.11-GCCcore-12.3.0

# Unset MAFFT_BINARIES to prevent version mismatch error
unset MAFFT_BINARIES

# --- Activate Conda Environment ---
source ~/miniconda3/etc/profile.d/conda.sh
conda activate fungene_py2

# --- Define Paths ---
export OUTDIR=/rds/general/user/jc224/home/pmoA_output/fastree_output
export REFDIR=/rds/general/user/jc224/home/meta/Data/reference_dbs/DIAMOND
export REFERENCE=${REFDIR}/Particulate_methane_monooxygenase_PmoA_Feb2024.faa

mkdir -p ${OUTDIR}

echo "============================================"
echo "Pipeline 1: Reference Tree Builder"
echo "Started: $(date)"
echo "============================================"

# ============================================================
# STEP 1: Separate USCα and USCγ Reference Sequences
# Purpose: Extract only USCα and USCγ sequences from the
#          full PmoA reference database by accession ID.
#
# USCα references (Methylocapsa/Beijerinckiaceae):
#   - NZ_KE386496     = Methylocapsa acidiphila
#   - CP024846        = Methylocapsa gorgona MG08
#   - NZ_FOSN01000007 = Methylocapsa palsarum
#   - JAFMSB          = Methylocapsa sp017353815
#   - PLUZ01000456    = Methylocapsa sp003162995
#
# USCγ references (Gammaproteobacteria):
#   - MUGK01000060    = USCg-Taylor sp002007425
# ============================================================
echo ""
echo "STEP 1: Separating USCα and USCγ reference sequences..."

python << 'PYEOF'
# -*- coding: utf-8 -*-
from Bio import SeqIO
import os

ref_file = os.environ["REFERENCE"]
outdir   = os.environ["OUTDIR"]

# Accession substrings that identify each clade
alpha_ids = ["KE386496", "CP024846", "FOSN01000007", "JAFMSB", "PLUZ01000456"]
gamma_ids  = ["MUGK01000060"]

alpha_seqs = []
gamma_seqs = []

for record in SeqIO.parse(ref_file, "fasta"):
    if any(acc in record.id for acc in alpha_ids):
        alpha_seqs.append(record)
    elif any(acc in record.id for acc in gamma_ids):
        gamma_seqs.append(record)

SeqIO.write(alpha_seqs, outdir + "/USCalpha_ref_only.fasta", "fasta")
SeqIO.write(gamma_seqs, outdir + "/USCgamma_ref_only.fasta", "fasta")

print("USCα reference sequences: %d" % len(alpha_seqs))
print("USCγ reference sequences: %d" % len(gamma_seqs))
PYEOF

echo "USCα references: $(grep -c '>' ${OUTDIR}/USCalpha_ref_only.fasta)"
echo "USCγ references: $(grep -c '>' ${OUTDIR}/USCgamma_ref_only.fasta)"

# ============================================================
# STEP 2: Align Reference Sequences with MAFFT
# Purpose: Create a multiple sequence alignment of reference
#          sequences only — no query reads included here.
#          This MSA is used both for tree building (Step 3)
#          and as the --ref-msa input to EPA-ng (Pipeline 2).
# ============================================================
echo ""
echo "STEP 2: Aligning reference sequences with MAFFT..."

mafft --auto \
    --thread 8 \
    ${OUTDIR}/USCalpha_ref_only.fasta \
    > ${OUTDIR}/USCalpha_ref_aligned.fasta

echo "USCα reference alignment width: $(awk '/^>/{next} {print length($0); exit}' ${OUTDIR}/USCalpha_ref_aligned.fasta)"

mafft --auto \
    --thread 8 \
    ${OUTDIR}/USCgamma_ref_only.fasta \
    > ${OUTDIR}/USCgamma_ref_aligned.fasta

echo "USCγ reference alignment width: $(awk '/^>/{next} {print length($0); exit}' ${OUTDIR}/USCgamma_ref_aligned.fasta)"

# ============================================================
# STEP 3: Build Reference Trees with FastTree
# Purpose: Build maximum likelihood phylogenetic trees from
#          reference sequences only. These trees define the
#          fixed topology that EPA-ng will place reads onto.
#          Branch lengths and topology will not be altered
#          when query reads are placed in Pipeline 2.
# Tool:    FastTree v2.1.11
# Model:   -lg    (LG substitution model, best for proteins)
#          -gamma (gamma rate variation across sites)
# ============================================================
echo ""
echo "STEP 3: Building reference trees with FastTree..."

FastTree \
    -lg \
    -gamma \
    ${OUTDIR}/USCalpha_ref_aligned.fasta \
    > ${OUTDIR}/USCalpha_tree.nwk \
    2> ${OUTDIR}/USCalpha_fasttree.log

echo "USCα tree built: $(ls -lh ${OUTDIR}/USCalpha_tree.nwk)"

FastTree \
    -lg \
    -gamma \
    ${OUTDIR}/USCgamma_ref_aligned.fasta \
    > ${OUTDIR}/USCgamma_tree.nwk \
    2> ${OUTDIR}/USCgamma_fasttree.log

echo "USCγ tree built: $(ls -lh ${OUTDIR}/USCgamma_tree.nwk)"

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "============================================"
echo "Pipeline 1 Complete: $(date)"
echo "============================================"
echo "Outputs (pass these to Pipeline 2):"
echo ""
echo "  Reference alignments:"
echo "    ${OUTDIR}/USCalpha_ref_aligned.fasta"
echo "    ${OUTDIR}/USCgamma_ref_aligned.fasta"
echo ""
echo "  Reference trees:"
echo "    ${OUTDIR}/USCalpha_tree.nwk"
echo "    ${OUTDIR}/USCgamma_tree.nwk"
echo ""
echo "These files are fixed. Re-run Pipeline 1 only if"
echo "you update your reference database."
echo "============================================"
