# IndPenSim Process Analytics (R)

Process monitoring and PLS model validation on the IndPenSim penicillin
fermentation benchmark, in R.

**Status:** in progress (Milestone 1: data and control charts)

> **All data in this project are simulated.** IndPenSim is a simulation of a
> 100,000 L penicillin fermentation, not real plant data.

## Data

- **Source:** IndPenSim, Goldrick et al., Mendeley Data,
  DOI [10.17632/pdnjz7zz5x.2](https://doi.org/10.17632/pdnjz7zz5x.2)
- **License:** TODO
- **Citations:** TODO (two Goldrick et al. papers)
- Raw data are not committed. Download the two CSVs into `data/raw/`.

### Batch structure (verified against the label columns)

| Batches | Control strategy | Notes |
|---|---|---|
| 1–30 | Recipe-driven | Reference set for control charts |
| 31–60 | Operator-controlled | |
| 61–90 | Advanced process control using Raman | |
| 91–100 | Recipe-driven, with faults | `Fault reference` marks fault onset within each batch |

### Known data issue

The raw CSV header has 2,239 names, but each row has 2,237 values. Header
names 34–36 are one column (the PAT reference) split on commas, so every name
from column 34 onward is shifted by two. `R/01_load_data.R` reads the file
without the header and assigns the corrected names.

## Methods (planned)

1. Univariate control charts using batches 1–30 as reference
2. PCA batch monitoring (Hotelling's T², Q/SPE); fault detection on 91–100
3. PLS prediction of penicillin from Raman spectra, validated on held-out batches

## How to reproduce

1. Download the data into `data/raw/`
2. Run `R/01_load_data.R`, then `R/02_explore.R`

## Limitations

Simulated data. Results show methods, not plant performance.