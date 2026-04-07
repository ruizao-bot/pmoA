# pmoA USC Phylogenetic Placement Pipeline

**Author:** jc224  
**Last Updated:** April 2026

## Overview

Two-step pipeline for placing metagenomic pmoA reads onto reference phylogenetic trees
for the USCα and USCγ clades of atmospheric methane oxidisers.

| Pipeline | Script | Run | Purpose |
|----------|--------|-----|---------|
| 1 | `scripts/fastree.sh`  | Once | Build reference trees from curated PmoA sequences |
| 2 | `scripts/EPA-ng.sh`   | Per sample | Place metagenomic reads onto reference trees |

---

## Pipeline 1 — Reference Tree Builder (`fastree.sh`)

### Purpose
Builds fixed reference phylogenetic trees for USCα and USCγ from a curated PmoA
protein database. Run **once**; reuse the outputs for every new metagenomic sample.
Only re-run if you update the reference database.

### Prerequisites
- **Modules**: `MAFFT/7.520-GCC-12.3.0-with-extensions`, `FastTree/2.1.11-GCCcore-12.3.0`
- **Conda env**: `fungene_py2` (Biopython required)
- **Reference database**:
  `~/meta/Data/reference_dbs/DIAMOND/Particulate_methane_monooxygenase_PmoA_Feb2024.faa`

### Usage
```bash
cd /rds/general/user/jc224/home/pmoA_output
qsub scripts/fastree.sh
```

### Steps
1. **Separate** — extract USCα and USCγ sequences from the PmoA database by accession
2. **Align** — multiple sequence alignment with MAFFT (`--auto`)
3. **Tree** — maximum likelihood trees with FastTree (LG + Γ model)

### Output (`results/fastree_output/`)
| File | Used by |
|------|---------|
| `USCalpha_ref_only.fasta` | combined reference construction (Pipeline 2) |
| `USCgamma_ref_only.fasta` | combined reference construction (Pipeline 2) |
| `USCalpha_ref_aligned.fasta` | MAFFT `--add` template |
| `USCgamma_ref_aligned.fasta` | MAFFT `--add` template |
| `USCalpha_tree.nwk` | EPA-ng `--tree` |
| `USCgamma_tree.nwk` | EPA-ng `--tree` |

---

## Pipeline 2 — Metagenomic Read Placement (`EPA-ng.sh`)

### Purpose
Places metagenomic pmoA reads onto the reference trees. Run once **per sample**.

### Prerequisites
- **Modules**: `ANTLR/2.7.7-GCCcore-12.3.0-Java-11`
- **Conda env**: `fungene_py2`
- **RDPTools**: `~/RDPTools` (FrameBot required)
- **Pipeline 1 outputs**: must exist in `results/fastree_output/`

### Usage
```bash
# Single sample
qsub -v SAMPLE=53394 scripts/EPA-ng.sh

# Batch submit multiple samples
for sample in 53394 53395 53396; do
    qsub -v SAMPLE=${sample} scripts/EPA-ng.sh
done
```

### Steps
1. **FrameBot** — error-correct reads against combined USC reference (α + γ)
2. **Stop codon filter** — remove internal stop codons from corrected proteins
3. **Separate** — split USCα and USCγ reads by best-match to reference accession
4. **Extract** — retrieve clean sequences for each clade
5. **Align** — add query sequences to reference MSA with MAFFT `--add --keeplength`
6. **Split** — separate ref and query for EPA-ng; fix PmoA- ID prefix mismatch
7. **Place** — phylogenetic placement with EPA-ng (LG+Γ model)

### Interpreting Results

**Success indicators:**
```
Pipeline 2 Complete: <timestamp>
USCα sequences: XX
USCγ sequences: YY
Placement outputs: .jplace files created
```

**Check logs:**
```bash
# Standard output
cat logs/<JOBID>.pbs-7.OU

# Error log (should be minimal if successful)
cat logs/<JOBID>.pbs-7.ER
```
---

## Directory Structure

**📁 Organized Directory Layout (Updated April 2026)**

The pmoA_output directory has been reorganized for clarity:

```
pmoA_output/
├── scripts/         
├── results/         
│   ├── fastree_output/
│   └── EPA_output/
├── pmoa_reads/       
├── logs/            
└── README.md

---

## References

- **EPA-ng**: Barbera et al. (2019) *Syst Biol* 68(2):365-369  
  https://github.com/Pbdas/epa-ng
- **FrameBot**: Wang et al. (2013) *Bioinformatics* 29(13):1710-1712  
  https://github.com/rdpstaff/RDPTools
- **MAFFT**: Katoh & Standley (2013) *Mol Biol Evol* 30(4):772-780
- **FastTree**: Price et al. (2010) *PLOS ONE* 5(3):e9490

---

## Contact

For questions about this pipeline:
- jc224@ic.ac.uk
- Imperial College London HPC: https://www.imperial.ac.uk/admin-services/ict/self-service/research-support/rcs/

---

**Version History:**
- **v1.0** (Mar 2026): Initial pipeline with 5-step placement
- **v1.1** (Apr 2026): Added MAFFT alignment + EPA-ng split (Steps 5-6); fixed ref-msa bug
- **v1.2** (Apr 2026): Reorganized directory structure into scripts/, docs/, results/, archive/
- **v1.3** (Apr 2026): Moved EPA_output and fastree_output under results/ for better organization
