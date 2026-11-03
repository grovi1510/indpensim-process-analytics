# IndPenSim Process Analytics (R)

Process monitoring and model validation on the IndPenSim penicillin fermentation benchmark, in R.

**Status:** Milestone 1 complete (the unlabeled 90 h event and univariate control charts). Milestone 2 (PCA monitoring) is next.

> **All data in this project is simulated.** IndPenSim is a simulation of a 100,000 L penicillin
> fermentation, not real plant data.

## Reports

- [M1: The unlabeled 90 h event and univariate control charts](reports/m1_report.md)

## Key findings so far

- **An unlabeled disturbance.** Eleven of the 100 batches show a sharp dissolved-oxygen crash at about 90 h, across all three control strategies. No label column in the dataset marks it.
- **Which batches get it.** Before the event, the affected batches produce more CO₂ (higher carbon evolution rate at similar oxygen uptake) and are already oscillating. At the scheduled aeration step (90.2 h), DO2 and pH drop, the base pump saturates for 1–1.5 h, and pH takes about 2 h to recover. This is an exploratory association in simulated data, not a confirmed mechanism.
- **Univariate charts don't catch the event when it happens.** They flag most affected batches as unusual long before 90 h, and they alarm on 10 of 27 normal test batches. That is the baseline the multivariate model in M2 has to beat.

## Data

- **Source:** IndPenSim, Goldrick et al., Mendeley Data, DOI [10.17632/pdnjz7zz5x.2](https://doi.org/10.17632/pdnjz7zz5x.2).
- **License:** [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The data are subset and transformed in this project.
- **Citations:**
  - Goldrick S., Ştefan A., Lovett D., Montague G., Lennox B. (2015). The development of an industrial-scale fed-batch fermentation simulation. *Journal of Biotechnology*, 193:70–82.
  - Goldrick S., Duran-Villalobos C.A., Jankauskas K., Lovett D., Farid S.S., Lennox B. (2019). Modern day monitoring and control challenges outlined on an industrial-scale benchmark fermentation process. *Computers & Chemical Engineering*. doi:10.1016/j.compchemeng.2019.05.037
- Raw data are not committed. Download the two CSVs from the Mendeley page into `data/raw/`.

### Batch structure (verified against the label columns)

| Batches | Control strategy | Notes |
|---|---|---|
| 1–30 | Recipe-driven | Clean training batches are the control-chart reference |
| 31–60 | Operator-controlled | |
| 61–90 | Advanced process control using Raman | |
| 91–100 | Recipe-driven, with faults | `Fault reference` marks fault onset within each batch |

### Known data issue

The raw CSV header has 2,239 names, but each row has 2,237 values. Header names 34–36 are one column
(the PAT reference) split on commas, so every name from column 34 onward is shifted by two.
`R/01_load_data.R` reads the file without the header and assigns the corrected names.

### Data observations

- **90 h event:** batches 6, 18, 27, 32, 42, 44, 64, 68, 70, 89 and 100 (DO2 below 6 mg/L between 80 and 110 h). Details in the M1 report.
- **Other unlabeled excursions:** batch 7 (pH drop, 161–206 h) and batch 20 (temperature spike at about 90 h) are excluded from the control-chart reference. Several other normal batches spend long periods with the base pump at maximum (`results/fb_ceiling_hours.csv`); they are review candidates for the M2 reference set.

## Train/test split

Batches are split once and saved in `splits/batch_split.csv` (script: `R/04_batch_split.R`, seed 20261031).
Within each control strategy, two-thirds of the batches are used for training and one-third is held out
for testing. Fault batches 91–100 are test only. The ten normal-operation batches with the 90 h event are
held out as their own test group (batch 100 stays with the faults), so models learn only clean normal
operation. Result: 53 train, 27 normal test, 10 event, 10 fault. The digital twin project reuses this split.

## Methods

1. **M1, done:** univariate control charts organized by control loop. Fixed limits for the controlled variables (pH, temperature); time-varying limits for base flow (the pH controller's output), dissolved oxygen and CER.
2. **M2, next:** PCA batch monitoring with Hotelling's T² and Q. Main question: can it detect the 90 h event when it happens? Faults 91–100 are a secondary check.
3. **M3, planned:** PLS prediction of penicillin from Raman spectra, validated on held-out batches, including behavior on the event batches.

## Repository layout

| Folder | Contents |
|---|---|
| `R/` | Analysis scripts, numbered in run order, plus shared settings (`key_variables.R`, `theme_portfolio.R`) |
| `splits/` | The fixed train/test split |
| `results/` | Tables written by the scripts |
| `figures/` | Figures written by the scripts |
| `reports/` | Quarto reports (`.qmd` source and rendered `.md`) |

## How to reproduce

1. Download the data into `data/raw/`.
2. Open `indpensim-process-analytics.Rproj` in RStudio.
3. Run the scripts in `R/` in numeric order, `01_` to `09_`.
4. Render `reports/m1_report.qmd` with Quarto.

## Limitations

Simulated data: results show methods, not plant performance. The 90 h event findings are exploratory;
they were found and described on the same batches. Each report lists its own limitations.
