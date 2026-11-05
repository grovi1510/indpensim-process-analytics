# M2 decisions (recorded before fitting)

Recorded Nov 5, 2026, before any PCA model was fitted. Data: IndPenSim, simulated. Split: `splits/batch_split.csv` (seed 20261031), unchanged.

## 1. Reference set

**Primary: all training batches except the Phase I exclusions (7, 20), 51 batches across the three control strategies.** The monitored plant runs all three strategies, so the model of normal operation has to cover them.

**Sensitivity run: recipe training batches only (16 batches, the M1 reference).** Same code, one setting (`ref_set`). It separates what changes because of the method (univariate → PCA) from what changes because of the reference.

**Phase I rule (applied in M2.2, once limits exist; written now so it is not chosen after seeing results):** a reference batch is removed if its in-sample T² or Q exceeds the 99% limit for more than 10% of its time points. Refit once; no further iterations. Batches 39, 61, 67, 69 and 73 (>10 h at the base-pump ceiling, `results/fb_ceiling_hours.csv`) are reviewed by this rule, not removed by hand.

## 2. Event batches (the 90 h event)

- The 10 event batches (`test_disturbance`) never enter the reference. Batch 100 stays in the fault set and is also reported with the event flag.
- They are treated as unlabelled disturbances, not as faults.
- Detection is reported against onset at 88 h n four classes (M1 used three: before, after, missed): before onset, at onset (88–92 h), late (after 92 h), missed.
- Near-misses: batch 17 is a test batch, so its result is out of sample. Batches 61 and 66 are training batches; if they stay in the reference after Phase I, their results are in sample and are reported as such.
- Bar to beat (M1, all five charts): normal 10/27 alarmed; events 9/10 flagged but 8 before onset, 1 late, 1 missed (64); faults 10/10.

## 3. Method choices

- **Unfolding:** observation-wise. Each variable is standardised against the reference trajectory (mean and SD across reference batches at each 0.1 h time point, SD floored at its 10th percentile), then PCA runs on rows = batch × time. This gives T² and Q at every sample, so detection can be timed against onset.
- **Variables:** online process measurements only. Excluded: penicillin (outcome), offline columns, S and X (simulator states, not measured online in a plant), Q (calculated), labels. Variables with near-zero reference SD for more than half the batch are dropped automatically.
- **Number of components:** chosen from in-sample variance, the broken-stick rule and a leave-batch-out check (variance each component explains in a batch the model did not see). Results are later checked at k ± 1.

## 4. Number of components (decided Nov 5, after the first fit)

- Primary k = 2 by the broken-stick rule (PC1 31.9%, PC2 17.8% above it; PC3 11.8% vs 12.9%). Sensitivity: k = 3.
- Leave-batch-out gains track in-sample gains for all 10 components, so no component looks overfitted; the check does not decide k here.
- Eigenvalue > 1 would give k = 4 (PC4 eigenvalue 1.02), not used.
- The rule, not the number, carries forward: after the Phase I refit, re-apply broken stick.
- With k = 2, Q holds about 50% of the variance and is expected to do much of the detecting.
- Decided Nov 5, before the Phase I refit: if broken stick gives k = 1 after the refit, k = 1 is primary and k = 2 is the sensitivity run (replacing k = 3). PC2 sat within about 0.5 points of the broken-stick line in both earlier fits, so the rule is on its boundary either way.

## 5. First-fit observations

- PC2 separates the five base-pump-ceiling batches (73, 67, 61, 39, 69; 21–51 h at Fb max) from the rest. Gap to the next batch: PC2 2.5 → 1.3.
- Otherwise the three control strategies overlap in PC1/PC2, so one pooled model is reasonable.
- Fs was dropped at 52% zero-SD time points, just over the 50% cut-off. Operator batches are the ones that vary it, so the model sees operator feed changes only through their effects.
- Loadings: PC1 = metabolic activity (CER, CO2outgas, OUR negative; off-gas O2 positive). PC2 = base addition and broth volume (V, Wt ~0.5; Fb 0.35). V and Wt are near-duplicates, so volume carries about double weight.

## 6. Limits (decided Nov 5, before computing them)

- 99% limits, theoretical: T² from the F distribution, Q from Box's approximation (g·χ²(h), matched to the reference Q mean and variance). The empirical 99th percentiles of the reference are reported as a check on the assumptions.
- Phase I uses these limits, as written in section 1.

## 7. Phase I result (Nov 5)

- Theoretical 99% limits on the first fit: T² 9.21 (empirical 15.20), Q 34.8 (empirical 40.9). Reference rows beyond: T² 3.48%, Q 1.43% (nominal 1%). The T² limit is too tight because consecutive samples are correlated.
- Removed by the 10% rule (6 of 51): 73, 67, 61, 39 (base-pump ceiling, on T²; 67 also on Q) and 9, 30 (recipe, low-activity end of PC1, on T² only). Batch 69 (base-pump ceiling) stays at 6.8%.
- 9 and 30 are removals caused by the tight T² limit, not by an excursion. Removing them narrows PC1, so low-activity test batches may alarm more in M2.3. Stated as a limitation.
- Batch 61 is now out of the reference, so M2.3 monitors it out of sample as a near-miss of the event.
- Refit (45 batches): PC1 33.8%, PC2 14.3% < broken stick 16.8%, so k = 1 by the rule. PC1 unchanged (metabolic activity). PC2 became the temperature loop (T, Fh, Fc), so the earlier base-pump/volume PC2 was carried by the removed batches.
- Final limits (k = 1, 45 batches): T² 6.64 (empirical 7.48), Q 35.6 (empirical 40.8); reference rows beyond: T² 1.29%, Q 1.32%.
- Refit check (no further removals, by the refit-once rule): 51 (41% on T²) and 48 (15%) would fail a second pass. Both sit at the ends of PC1; removing 9 and 30 made them the new extremes. They stay in the reference.
- Highest Q in the reference: 69 (base-pump ceiling) and 66 (near the event CER threshold), about 7%. In sample.

## 8. Alarm rule and detection metrics (decided Nov 5, before monitoring)

- Alarm: 3 consecutive samples (0.6 h) beyond the 99% limit on T² or Q. Alarm time = the third sample, when an operator would actually see it. Single-point alarms on correlated data would mostly be noise.
- A batch is flagged if it alarms at any time. False-alarm rate = flagged normal test batches / 27.
- Events and faults, first alarm vs onset: before onset, at onset (onset to onset + 4 h), late, missed. Onsets from M1 (88 h for events, Fault_ref for faults).
- The main question gets its own measure: did an alarm fire inside the onset window, whatever happened earlier? Plus % of time out of limits in the 24 h before onset, to tell "already out" from "jumped at onset".
- Out-of-sample checks: Phase I removed batches (7, 20, 9, 30, 39, 61, 67, 73) and test batch 17. 66 and 69 are in sample.
- Comparison with M1: timing compares first alarms directly. The batch-flag rules differ (M1: % time out above the worst reference batch; M2: run rule), and the report says so.

## 9. Revision of the alarm limits (Nov 5, after the first monitoring run)

- Pre-registered rule (section 8, per-sample 99% limits): 18/45 reference and 19/27 normal test batches alarmed. The reference check named in advance failed. Cause: a 99% per-sample limit is not a 99% per-batch limit over ~1,150 correlated samples.
- Revision: same run rule (3 consecutive samples); limits re-set at the batch level. For each reference batch, the highest level held for 3 consecutive samples; limit = 97.5th percentile across the 45 reference batches, per statistic (about 5% of reference batches alarm on either).
- Calibrated on reference batches only, so the 27 normal test batches stay an out-of-sample false-alarm check.
- Both runs are reported. The calibrated run is primary and feeds results/fault_detection.csv.
- Reporting choice made after seeing results: the summary counts first alarms from −2 h to +4 h around onset as "near onset", because batches 32 and 68 alarm during the pre-event oscillation documented on Nov 3. Pre-registered classes are reported too.

Note: this file was kept locally during the session and first committed on Nov 5 at 10:12, after the results, because a `.gitignore` rule hid the `docs/` folder. The git history therefore does not show the order; the dated sections do.