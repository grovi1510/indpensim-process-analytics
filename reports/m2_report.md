# M2: PCA monitoring of the 90 h event
Gabriela Rovi
2026-11-05

> **All data in this report is simulated.** It comes from the IndPenSim
> benchmark, not from a real plant.

## In plain language

The penicilin fermentation process is watched through a dozen sensors at
once: oxygen, CO₂, pH, temperature, pump flows. Milestone 1 watched each
sensor on its own chart. That flagged the batches with the 90 h
disturbance as “unusual” long before anything happened, which is not
much use to an operator.

This milestone combines the sensors into one model of normal operation
(principal component analysis, PCA) and raises an alarm when a batch
moves away from it. The combined model sounds the alarm when the
disturbance actually happens, within about 2 hours of it, in 7 of the 10
affected batches. The single-sensor charts did that in 1 of 10. It does
not reduce false alarms, though: about a third of normal batches still
alarm at some point. And it is slower than a simple pH chart for faults
that move only pH. The practical answer is to use both: the combined
model for disturbances that move many signals together, and single
charts on the critical controlled variables.

## Summary

- **Reference:** 45 normal training batches from all three control
  strategies, after a pre-registered Phase I review removed 6 batches
  (9, 30, 39, 61, 67, 73).
- **Model:** observation-wise PCA on 13 online variables, each
  standardized against the reference trajectory; one component
  (broken-stick rule), so T² tracks metabolic activity and Q tracks
  everything else.
- **Alarm rule:** 3 consecutive samples (0.6 h) beyond the limit on T²
  or Q. The pre-registered per-sample 99% limits alarmed on 19/27 normal
  test batches, so the limits were recalibrated at the batch level on
  the reference batches only.
- **The 90 h event:** first alarm within 2 h before to 4 h after onset
  in 7/10 event batches, against 1/10 for the M1 charts. Two are missed:
  batch 89 (a mild event) and batch 44 (oscillating spikes that never
  last three samples).
- **False alarms:** 9/27 normal test batches, against 10/27 in M1. No
  improvement.
- **Faults 91–100:** 6/10 at onset, against 8/10 in M1. The two pH
  faults (92, 98) are about 60 h late: a shift in one variable is
  diluted across thirteen.

## Purpose

M1 showed that univariate charts flag the 90 h event batches early but
not at the event itself. M2 asks whether a multivariate model can detect
the event when it happens, and at what cost in false alarms and fault
detection. The M1 results are the bar to beat.

All choices (reference set, Phase I rule, number of components, limits,
alarm rule) were written down before the step they govern, in
[`docs/m2_decisions.md`](../docs/m2_decisions.md). One choice was
revised after seeing results (the limits); the revision and its reason
are recorded there and reported below.

## Method

### Reference set and Phase I

- **Start:** all 53 training batches except 7 and 20 (excluded in M1),
  giving 51 batches across the three control strategies. The plant runs
  all three, so the model of normal operation covers them.
- **Phase I rule, fixed before fitting:** remove a reference batch if T²
  or Q exceeds its 99% limit for more than 10% of its time points, refit
  once, no further iterations.
- **Result:** 6 batches removed. Four spend 21–51 h with the base pump
  at maximum (39, 61, 67, 73); the first model’s second component was
  mostly these batches. Two (9, 30) are normal low-activity batches at
  the edge of the first component; they crossed only because the
  theoretical T² limit was too tight for correlated samples.
- **Refit check:** on the refit model, batches 48 and 51 would fail a
  second pass. They stay in the reference, as the refit-once rule says;
  removing them would keep peeling off the edges of normal variation.

![Phase I review on the first model: share of each reference batch’s
time beyond the 99% limit.](../figures/pca_phase1_all_train.png)

### Data arrangement and variables

- **Unfolding:** observation-wise. Each variable is standardized against
  the reference trajectory (mean and SD across reference batches at each
  0.1 h time point, SD floored at its 10th percentile, at least half the
  reference batches present). PCA then runs on rows = batch × time, so
  T² and Q exist at every sample and can be timed against onset.
- **Variables:** 13 online measurements: base, cooling and heating flows
  (Fb, Fc, Fh), DO2, volume and weight, pH, temperature, off-gas CO₂ and
  O₂, OUR, CER, and PAA flow. Penicillin (the outcome), offline
  measurements, simulator states not measured in a plant (substrate,
  biomass) and calculated heat are excluded. Recipe-set variables that
  are identical across reference batches for more than half the batch
  (aeration, agitation, pressure, water, oil, acid flow, sugar feed)
  carry no information about normal variation and are dropped. Sugar
  feed was dropped at 52%, just over the cut-off.

### Number of components

|  PC | % variance | Broken stick % | Leave-batch-out gain % |
|----:|:-----------|:---------------|:-----------------------|
|   1 | 33.8       | 24.5           | 33.3                   |
|   2 | 14.3       | 16.8           | 13.8                   |
|   3 | 11.2       | 12.9           | 10.6                   |
|   4 | 8.6        | 10.4           | 5.9                    |

Final model (after Phase I). Leave-batch-out gain: variance each
component explains in a reference batch left out of the fit.

The broken-stick rule gives one component: PC2 (14.3%) falls below the
broken-stick value (16.8%). This was decided in advance as the rule to
follow if PC2 fell below the line after the refit. PC1 is metabolic
activity: CER, CO₂ and OUR load negatively, off-gas O₂ and DO2
positively. It is unchanged by the Phase I removals. Before them, PC2
was the base-pump and volume direction carried by the removed batches;
after them, it became the temperature loop. The leave-batch-out gains
track the in-sample gains for every component, so nothing looks
overfitted, but that check does not decide k here.

![Batch-mean scores of the reference batches by control strategy. The
strategies overlap, so one pooled model is
reasonable.](../figures/pca_strategy_all_train.png)

### Limits and alarm rule

- **Pre-registered:** theoretical 99% limits (T² from the F
  distribution, Q from Box’s approximation): T² 6.64, Q 35.6. Empirical
  99th percentiles of the reference: T² 7.48, Q 40.8. Alarm: 3
  consecutive samples beyond a limit, T² or Q.
- **Why this failed:** 18/45 reference batches and 19/27 normal test
  batches alarmed. A 99% limit per sample is not a 99% limit per batch:
  each batch has about 1,150 correlated samples, so a run of three
  somewhere is likely.
- **Revision (primary):** same run rule, limits set at the batch level.
  For each reference batch, take the highest level it holds for three
  consecutive samples; the limit is the 97.5th percentile of these
  across the 45 reference batches. This gives T² 11.35 and Q 90.0. The
  limits use only reference batches, so the 27 normal test batches
  remain an out-of-sample check.
- **Timing:** first alarm compared with onset. Events: 88 h, as in M1.
  Faults: the fault reference signal. Classes: before onset, at onset (0
  to +4 h), late, missed.

*Code:* `R/10_pca_model.R`, `R/11_pca_limits.R`, `R/12_pca_monitoring.R`

## Results

| Method | Normal test flagged | Events, first alarm −2 to +4 h | Faults, first alarm 0 to +4 h |
|:---|:---|:---|:---|
| M1: univariate charts | 10/27 | 1/10 | 8/10 |
| M2: PCA, per-sample 99% limits | 19/27 | 3/10 | 6/10 |
| M2: PCA, batch-calibrated (primary) | 9/27 | 7/10 | 6/10 |

M1 vs M2. M1’s batch flag rule differs (share of time out above the
worst reference batch); timing compares first alarms directly.

### The 90 h event

| Batch | Strategy | M1 first alarm (h) | M2 first alarm (h) | M2 statistic | M2 alarm in 88–92 h |
|---:|:---|:---|:---|:---|:---|
| 6 | recipe | 26.4 | 90.4 | Q | yes |
| 18 | recipe | 86.2 | 90.6 | Q | yes |
| 27 | recipe | 10.4 | 90.6 | both | yes |
| 32 | operator | 50.6 | 86.0 | Q | yes |
| 42 | operator | 14.2 | 23.2 | T2 | yes |
| 44 | operator | 11.4 | missed |  | no |
| 64 | apc_raman | missed | 89.2 | Q | yes |
| 68 | apc_raman | 10.2 | 87.4 | Q | yes |
| 70 | apc_raman | 50.6 | 88.0 | Q | yes |
| 89 | apc_raman | 132.8 | missed |  | no |

Event batches, onset 88 h. M2 = batch-calibrated limits.

![T² and Q from 40 to 140 h. Gray: reference batches; colour: event
batches; dashed: batch-calibrated limit; dotted: 88
h.](../figures/pca_event_trajectories_all_train_k1_batch.png)

- Q rises two to three orders of magnitude between 88 and 92 h in the
  event batches, far beyond anything in the reference. Q carries the
  detection; T² adds little.
- 5 batches alarm at onset. Batches 32 and 68 alarm 2.0 and 0.6 h before
  88 h. The M1 zoom (`R/09_event_zoom.R`) showed event batches
  oscillating from about 86 h, so these are early detections of the same
  event, not unrelated alarms. The −2 h allowance in the summary was set
  after seeing these two results; under the pre-registered classes they
  count as “before onset”.
- Batch 42 alarms at 23 h, like M1.
- **Missed: 44 and 89.** Batch 89 is a mild event: Q crosses the limit
  once or twice. Batch 44 is clearly abnormal (Q above 1,000 three times
  between 89 and 91 h) but every spike is a single sample, because the
  event oscillates. The run rule that removes single-sample noise also
  removes this.

![Batch 44 (missed), 64 (detected) and 89 (missed), 80–100 h. Dashed:
batch-calibrated limit.](../figures/pca_event_runrule_44_64_89.png)

### Faults 91–100

| Batch | Onset (h) | M1 first alarm (h) | M2 first alarm (h) | M2 statistic |
|------:|----------:|:-------------------|:-------------------|:-------------|
|    91 |        20 | 20.0               | 20.4               | T2           |
|    92 |        80 | 80.0               | 140.6              | Q            |
|    93 |        70 | 0.2                | 75.0               | Q            |
|    94 |        20 | 20.0               | 20.4               | both         |
|    95 |        20 | 20.0               | 20.4               | T2           |
|    96 |        70 | 50.4               | 78.2               | Q            |
|    97 |        20 | 20.0               | 20.4               | T2           |
|    98 |        80 | 80.0               | 140.8              | Q            |
|    99 |        20 | 20.0               | 20.4               | both         |
|   100 |        20 | 20.0               | 20.4               | both         |

Fault batches (batch 100 also has the 90 h event). Results in
results/fault_detection.csv.

The six faults starting at 20 h are caught within 0.4 h. Faults 93 and
96 (onset 70 h) are 5–8 h late. Faults 92 and 98 (onset 80 h) are about
60 h late. In M1 the pH chart caught both at 80 h, and nothing else did,
so these are pH faults. pH barely loads on PC1, so a pH shift goes to Q,
and Q sums squared deviations over 13 variables: a single variable must
be about 9–10 SD off to cross the limit alone, against 3 SD on a pH
chart. The fault reference column is 0/1 only, so the fault type is
inferred from M1, not read from a label.

### Near-misses and out-of-sample checks

| Batch | Group | Known | Flagged | First alarm (h) |
|---:|:---|:---|:---|:---|
| 7 | phase I removed | pH excursion from 161 h | yes | 160.4 |
| 9 | phase I removed | Low activity (PC1 edge) | yes | 152.0 |
| 20 | phase I removed | T spike at about 90 h | yes | 87.8 |
| 30 | phase I removed | Low activity (PC1 edge) | yes | 163.2 |
| 39 | phase I removed | Base pump at max 29 h | no | missed |
| 61 | phase I removed | Near-miss of the event; base pump at max 22 h | no | missed |
| 67 | phase I removed | Base pump at max 51 h | yes | 77.0 |
| 73 | phase I removed | Base pump at max 45 h | yes | 38.6 |
| 66 | reference (in sample) | Near the CER threshold, no event | yes | 89.8 |
| 69 | reference (in sample) | Base pump at max 31 h | no | missed |
| 17 | test | Near the CER threshold, no event | yes | 145.2 |
| 75 | test | Base pump near max for about 50 h | yes | 113.8 |

Batches with a known feature. Phase I removed and test batches are out
of sample; reference batches are in sample.

- Batches 7 and 20 are caught at their known excursions (160 h and 87.8
  h), out of sample.
- Batch 61, the near-miss of the event, is not flagged. Neither is 39.
  Under the calibrated limits both look normal, so their Phase I removal
  was driven by the tight theoretical T² limit, not by an excursion.
- Batch 17 alarms only at 145 h, not near 88 h. Batch 66 alarms at 89.8
  h, in sample.
- Batch 75, a normal test batch with the base pump near maximum for
  about 50 h, is the most persistent false alarm (Q beyond the limit 12%
  of the time).

## What this shows

- **PCA detects the event when it happens.** M1’s charts saw the event
  batches as different; PCA sees the event. That is the result the
  milestone was asking for.
- **It does not buy specificity.** About a third of normal test batches
  alarm, as in M1. The in-sample rate (4/45) is much lower than the
  out-of-sample rate, because the reference trajectory and the model are
  fit on the reference batches.
- **Multivariate monitoring dilutes single-variable faults.** The pH
  faults show why univariate charts on critical controlled variables
  should stay alongside the model.
- **The run rule is a trade-off.** It removes single-sample noise and,
  with it, oscillating disturbances like batch 44. A rule such as 3 of 5
  samples, or an EWMA on Q, would likely catch 44; choosing one now
  would be fitting the rule to the answer, so it is left for a fresh
  test.

## Limitations

- Simulated data: results show the method, not plant performance.
- The limits were revised after the first monitoring run. The revision
  used only reference batches and is reported with the original, but it
  is not a pre-registered result.
- Event onset is fixed at 88 h for all event batches; the true onset
  varies by about 2 h.
- Phase I removed two normal low-activity batches (9, 30) because of the
  tight T² limit, which narrows PC1; low-activity test batches may alarm
  more as a result.
- Volume and weight are near-duplicates, so volume carries about double
  weight in the model.
- Recipe-set variables are dropped, so the model cannot see faults
  acting only through them.
- Sensitivity runs (recipe-only reference; k = 2) are set up in the code
  but not reported here.

## Decisions record

[`docs/m2_decisions.md`](../docs/m2_decisions.md) lists every choice,
when it was made, and the one revision.
