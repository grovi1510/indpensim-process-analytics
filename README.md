# IndPenSim Process Analytics (R)

Process monitoring and model validation on the IndPenSim penicillin fermentation benchmark, in R.

**Status:** Milestones 1 and 2 complete (univariate control charts; PCA monitoring). Milestone 3 (PLS on Raman spectra, with a validation report) is next.

> **All data in this project is simulated.** IndPenSim is a simulation of a 100,000 L penicillin
> fermentation, not real plant data.

## Reports

- [M1: The unlabeled 90 h event and univariate control charts](reports/m1_report.md)
- [M2: PCA monitoring of the 90 h event](reports/m2_report.md)
- [M2 decisions record](docs/m2_decisions.md): every modelling choice, written down before the step it governs

## Key findings so far

- **An unlabeled disturbance.** Eleven of the 100 batches show a sharp dissolved-oxygen crash at about 90 h, across all three control strategies. No label column in the dataset marks it.
- **Which batches get it.** Before the event, the affected batches produce more CO₂ (higher carbon evolution rate at similar oxygen uptake) and are already oscillating. At the scheduled aeration step (90.2 h), DO2 and pH drop, the base pump saturates for 1–1.5 h, and pH takes about 2 h to recover. This is an exploratory association in simulated data, not a confirmed mechanism.
- **Univariate charts don't catch the event when it happens (M1).** They flag most affected batches as unusual long before 90 h, and they alarm on 10 of 27 normal test batches.
- **PCA does (M2).** A one-component PCA model with T² and Q raises its first alarm within 2 h before to 4 h after the event in 7 of 10 event batches, against 1 of 10 for the univariate charts. The signal is in Q.
- **What PCA doesn't fix (M2).** False alarms stay at about a third of normal test batches (9 of 27). Faults that move only pH are caught about 60 h late, because a one-variable shift is diluted across thirteen variables; the univariate pH chart caught them at onset. The two methods are complementary.
- **Method lesson (M2).** A 99% limit per sample is not a 99% limit per batch: with about 1,150 correlated samples per batch, the textbook limits alarmed on 19 of 27 normal batches. The limits were recalibrated at the batch level on reference batches only; both results are reported.

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
| 1–30 | Recipe-driven | Clean training batches are the M1 control-chart reference |
| 31–60 | Operator-controlled | |
| 61–90 | Advanced process control using Raman | |
| 91–100 | Recipe-driven, with faults | `Fault reference` marks fault onset within each batch (0/1, no fault type) |

### Known data issue

The raw CSV header has 2,239 names, but each row has 2,237 values. Header names 34–36 are one column
(the PAT reference) split on commas, so every name from column 34 onward is shifted by two.
`R/01_load_data.R` reads the file without the header and assigns the corrected names.

### Data observations

- **90 h event:** batches 6, 18, 27, 32, 42, 44, 64, 68, 70, 89 and 100 (DO2 below 6 mg/L between 80 and 110 h). Details in the M1 report.
- **Other unlabeled excursions:** batch 7 (pH drop, 161–206 h) and batch 20 (temperature spike at about 90 h) are excluded from both references. The M2 PCA model catches both out of sample.
- **Base pump at maximum:** several normal batches spend long periods with the base pump at its ceiling (`results/fb_ceiling_hours.csv`). Four of them (39, 61, 67, 73) were removed from the M2 reference by the pre-registered Phase I rule.

## Train/test split

Batches are split once and saved in `splits/batch_split.csv` (script: `R/04_batch_split.R`, seed 20261031).
Within each control strategy, two-thirds of the batches are used for training and one-third is held out
for testing. Fault batches 91–100 are test only. The ten normal-operation batches with the 90 h event are
held out as their own test group (batch 100 stays with the faults), so models learn only clean normal
operation. Result: 53 train, 27 normal test, 10 event, 10 fault. The digital twin project reuses this split.

## Methods

1. **M1, done:** univariate control charts organized by control loop. Fixed limits for the controlled variables (pH, temperature); time-varying limits for base flow (the pH controller's output), dissolved oxygen and CER.
2. **M2, done:** observation-wise PCA on 13 online variables standardized against the reference trajectory; reference of 45 normal training batches from all three strategies after a Phase I review; one component by the broken-stick rule; Hotelling's T² and Q with batch-calibrated limits and a 3-sample run rule. Fault-detection results for faults 91–100 are in `results/fault_detection.csv`, the baseline for the digital twin project.
3. **M3, next:** PLS prediction of penicillin from Raman spectra, validated on held-out batches, including behavior on the event batches.

## Repository layout

| Folder | Contents |
|---|---|
| `R/` | Analysis scripts, numbered in run order, plus shared settings (`key_variables.R`, `theme_portfolio.R`) |
| `splits/` | The fixed train/test split |
| `results/` | Tables written by the scripts |
| `figures/` | Figures written by the scripts |
| `reports/` | Quarto reports (`.qmd` source and rendered `.md`) |
| `docs/` | Decisions records |

## How to reproduce

1. Download the data into `data/raw/`.
2. Open `indpensim-process-analytics.Rproj` in RStudio.
3. Run `renv::restore()` to install the package versions recorded in `renv.lock`.
4. Run the scripts in `R/` in numeric order, `01_` to `09_`.
5. For M2, run in this order (the Phase I step needs a refit):
   1. `10_pca_model.R` (first fit; set `k` in section 6),
   2. `11_pca_limits.R` (Phase I; writes the exclusions),
   3. `10_pca_model.R` again (refit; re-check `k`),
   4. `11_pca_limits.R` again (final limits),
   5. `12_pca_monitoring.R` with `calib <- "sample"`, then with `calib <- "batch"`.
6. Render the reports in `reports/` with Quarto.

## Limitations

Simulated data: results show methods, not plant performance. The 90 h event findings are exploratory;
they were found and described on the same batches. In M2 the alarm limits were revised after the first
monitoring run (documented in the decisions record). Each report lists its own limitations.