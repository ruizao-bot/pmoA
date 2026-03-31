# pmoA USC Phylogenetic Placement Pipeline

**Author:** jc224  
**Date:** March 2026

## Overview

Two-step pipeline for placing metagenomic pmoA reads onto reference phylogenetic trees
for the USCα and USCγ clades of atmospheric methane oxidisers.

| Pipeline | Script | Run | Purpose |
|----------|--------|-----|---------|
| 1 | `fastree.sh`  | Once | Build reference trees from curated PmoA sequences |
| 2 | `EPA-ng.sh`   | Per sample | Place metagenomic reads onto reference trees |

---

## Pipeline 1 — Reference Tree Builder (`fastree.sh`)

### Purpose
Builds fixed reference phylogenetic trees for USCα and USCγ from a curated PmoA
protein database. Run **once**; reuse the outputs for every new metagenomic sample.
Only re-run if you update the reference database.

### Prerequisites
- Modules: `MAFFT/7.520-GCC-12.3.0-with-extensions`, `FastTree/2.1.11-GCCcore-12.3.0`
- Conda env: `fungene_py2` (Biopython required)
- Reference database:
  `meta/Data/reference_dbs/DIAMOND/Particulate_methane_monooxygenase_PmoA_Feb2024.faa`

### Usage
```bash
qsub fastree.sh
```

### Steps
1. **Separate** — extract USCα and USCγ sequences from the PmoA database by accession
2. **Align** — multiple sequence alignment with MAFFT (`--auto`)
3. **Tree** — maximum likelihood trees with FastTree (LG + Γ model)

### Output (`fastree_output/`)
| File | Used by |
|------|---------|
| `USCalpha_ref_only.fasta` | combined reference construction (Pipeline 2) |
| `USCgamma_ref_only.fasta` | combined reference construction (Pipeline 2) |
| `USCalpha_ref_aligned.fasta` | EPA-ng `--ref-msa` |
| `USCgamma_ref_aligned.fasta` | EPA-ng `--ref-msa` |
| `USCalpha_tree.nwk` | EPA-ng `--tree` |
| `USCgamma_tree.nwk` | EPA-ng `--tree` |
| `*_fasttree.log` | diagnostic logs |

---

## Pipeline 2 — Metagenomic Read Placement (`EPA-ng.sh`)

### Purpose
Corrects frameshifts, translates, and phylogenetically places metagenomic pmoA reads
onto the reference trees from Pipeline 1. Run once per sample.

### Prerequisites
- Pipeline 1 outputs must exist in `fastree_output/`
- Modules: `ANTLR/2.7.7-GCCcore-12.3.0-Java-11`, `epa-ng`
- RDPTools (FrameBot) at `~/RDPTools/`
- Conda env: `fungene_py2` (Biopython required)
- Input reads: `pmoa_reads/<SAMPLE>_pmoA.fasta`

### Usage
```bash
# Single sample
qsub -v SAMPLE=53394 EPA-ng.sh

# All samples
for s in 53394 53395 53396 53397 53398 53399; do
    qsub -v SAMPLE=$s EPA-ng.sh
done
```

### Steps
1. **FrameBot** — frameshift correction and translation (`-i 0.2`, `-l 50`, glocal)
2. **Clean** — remove sequences containing internal stop codons (`*`)
3. **Separate** — classify reads as USCα or USCγ via FrameBot STATS best-match
4. **Extract** — filter clean proteins to per-clade FASTA files
5. **Placement** — EPA-ng grafts reads onto reference trees (hmmer realignment, 8 threads)

### Output (`EPA_output/`)
```
EPA_output/
├── USC_ref_combined.fasta               # shared FrameBot reference (built once)
└── <SAMPLE>/
    ├── framebot_USC_result_<SAMPLE>_corr_prot.fasta
    ├── framebot_USC_result_<SAMPLE>_failed_nucl.fasta
    ├── framebot_USC_result_<SAMPLE>_framebot.txt
    ├── framebot_USC_clean_<SAMPLE>_prot.fasta
    ├── USCalpha_<SAMPLE>_ids.txt
    ├── USCgamma_<SAMPLE>_ids.txt
    ├── USCalpha_<SAMPLE>_clean.fasta
    ├── USCgamma_<SAMPLE>_clean.fasta
    ├── epa_alpha_output/
    │   └── epa_result.jplace
    └── epa_gamma_output/
        └── epa_result.jplace
```

### Downstream analysis of `.jplace` files
| Tool | Command |
|------|---------|
| gappa | `gappa examine graft --jplace-path *.jplace` |
| iTOL | upload `.jplace` directly |
| genesis | programmatic / R interface |

Filter by likelihood weight ratio (LWR) > 0.5 for high-confidence placements.

---

## USC Clade Reference Accessions

| Clade | Organism | Accession |
|-------|----------|-----------|
| USCα | *Methylocapsa acidiphila* | KE386496 |
| USCα | *Methylocapsa gorgona* MG08 | CP024846 |
| USCα | *Methylocapsa palsarum* | FOSN01000007 |
| USCα | *Methylocapsa* sp017353815 | JAFMSB |
| USCα | *Methylocapsa* sp003162995 | PLUZ01000456 |
| USCγ | USCg-Taylor sp002007425 | MUGK01000060 |

---

## Directory Structure

```
pmoA_output/
├── fastree.sh              # Pipeline 1 — run once
├── EPA-ng.sh               # Pipeline 2 — run per sample
├── README.md               # this file
├── pmoa_reads/             # input nucleotide reads
│   └── <SAMPLE>_pmoA.fasta
├── fastree_output/         # Pipeline 1 outputs (reference trees)
│   ├── USCalpha_ref_aligned.fasta
│   ├── USCgamma_ref_aligned.fasta
│   ├── USCalpha_tree.nwk
│   └── USCgamma_tree.nwk
├── EPA_output/             # Pipeline 2 outputs
│   ├── USC_ref_combined.fasta
│   └── <SAMPLE>/
│       ├── epa_alpha_output/
│       └── epa_gamma_output/
└── logs/                   # PBS job logs
```
