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

### Train/test split

Batches are split once and saved in `splits/batch_split.csv` (script: `R/04_batch_split.R`, seed 20261031).
Within each control strategy (1–30 recipe, 31–60 operator, 61–90 Raman APC), two thirds of the batches
are used for training and one third is held out for testing. Faulty batches 91–100 are test only.
Eleven batches with an unlabelled disturbance at about 90 h (see Results) are held out as their own
test group, so that models are trained on clean normal operation. The digital twin project reuses this split.

## Results

### Finding: 90 h event

Eleven of the 100 batches show a sharp dissolved-oxygen dip at about 90 h, across all three control
strategies. All 100 batches receive the same scheduled aeration (Fg) step at that time. The affected
batches had higher metabolic activity before the step: median CER from 70 to 88 h was 1.55 vs 1.41
(Wilcoxon p < 0.001, fault batches excluded), and the nine highest-CER batches were all event batches.
Working hypothesis: the aeration step destabilises the most active batches. This is an association in
simulated data, not a confirmed mechanism. Batches 66 and 17 sit just below the apparent threshold;
to check in M2.

### Fixed-limit control charts (pH, T)

pH and temperature are both under closed-loop control, so they were charted with fixed limits
(mean ± 3 SD) from the recipe-strategy training batches, using data after 50 h to skip start-up
transients (script: `R/06_control_charts_fixed.R`).

**Phase I clean-up.** Two reference batches showed unlabelled events and were removed before
the limits were set: batch 7 (pH dropped to 5.70 between 161 and 206 h) and batch 20 (temperature
spike to 299.7 K at about 90 h). Batch 20 had no elevated pre-event CER, so the 90 h hypothesis
above does not explain every case. Limits were computed from the remaining 16 batches.

**Point-level alarms are not usable on their own.** Almost every batch, including the training
batches, has at least one point outside ±3 SD. The data are autocorrelated (0.2 h sampling) and
contain scheduled spikes, so the share of points outside the limits is well above the 0.27%
expected for independent normal data.

**Batch-level rule.** A batch is flagged when its percentage of time outside the limits exceeds
that of the worst clean reference batch (pH 7.1%, T 5.0%). This is a deliberately loose threshold.

| Group | pH | T |
|---|---|---|
| Held-out normal batches (false alarms) | 2/27 | 6/27 |
| 90 h disturbance batches (detected) | 2/10 | 3/10 |
| Fault batches 91–100 (detected) | 7/10 | 6/10 |

**Interpretation.** Fixed limits on pH and T catch most faults but miss most 90 h events, and
temperature raises too many false alarms in operator-controlled batches (4/9). Within the recipe
strategy, pH limits transfer well (0/9 false alarms); across strategies they do not, because each
strategy holds the setpoints differently. The main limitation is that pH and T are controlled
variables: the controllers absorb disturbances before they appear there. The upset shows up
instead in controller effort (base flow, cooling and heating) and in uncontrolled responses such
as dissolved oxygen. The next step charts Fb, DO2 and CER with time-varying limits, and M2
monitors all variables together with PCA.

Results: `results/fixed_limits_pH_T.csv`, `results/fixed_limits_alarms.csv`.
Data: IndPenSim, simulated.

## How to reproduce

1. Download the data into `data/raw/`
2. Run `R/01_load_data.R`, then `R/02_explore.R`

## Limitations

Simulated data. Results show methods, not plant performance.