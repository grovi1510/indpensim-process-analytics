# M2.3: monitor every batch with the PCA model (T2 and Q), time detection
# against onset, compare with M1, save results/fault_detection.csv (twin baseline).
# Rules: docs/m2_decisions.md, section 8. IndPenSim (simulated), DOI 10.17632/pdnjz7zz5x.2

library(data.table); library(ggplot2)
source(here::here("R", "theme_portfolio.R"))
source(here::here("R", "key_variables.R"))   # ref_excluded = c(7, 20)

ref_set <- "all_train"
calib   <- "batch"   # "sample": pre-registered 99% per-sample limits; "batch": ~5% of reference batches alarm
q_batch <- 0.975
primary <- calib == "batch"   # only the calibrated run writes fault_detection.csv
n_run   <- 3      # consecutive samples beyond a limit (0.6 h) to raise an alarm
win_h   <- 4      # "at onset" = alarm within onset .. onset + 4 h

m   <- readRDS(here::here("data", "processed", paste0("pca_model_", ref_set, ".rds")))
st  <- readRDS(here::here("data", "processed", paste0("pca_stats_", ref_set, ".rds")))
lim <- fread(here::here("results", paste0("pca_limits_", ref_set, ".csv")))
T2_lim <- lim[stat == "T2", theoretical]; Q_lim <- lim[stat == "Q", theoretical]
tag <- paste0(ref_set, "_k", m$k, "_", calib)

p1_removed <- c(ref_excluded,
                fread(here::here("results", paste0("phase1_excluded_", ref_set, ".csv")))$batch)
onset <- fread(here::here("results", "m1_detection_timing.csv"))[, .(batch, onset_h)]

setorder(st, batch, t_grid)
st[, group := fcase(batch %in% m$ref_batches, "reference (in sample)",
                    batch %in% p1_removed,    "phase I removed",
                    default = role)]
if (calib == "batch") {
  # highest level each batch holds for n_run consecutive samples
  st[, `:=`(T2_m = do.call(pmin, shift(T2, 0:(n_run - 1))),
            Q_m  = do.call(pmin, shift(Q,  0:(n_run - 1)))), by = batch]
  bmax <- st[batch %in% m$ref_batches,
             .(T2 = max(T2_m, na.rm = TRUE), Q = max(Q_m, na.rm = TRUE)), by = batch]
  T2_lim <- unname(quantile(bmax$T2, q_batch)); Q_lim <- unname(quantile(bmax$Q, q_batch))
}
cat("Limits used (", calib, "): T2", round(T2_lim, 2), " Q", round(Q_lim, 2), "\n")
st[, `:=`(T2_out = T2 > T2_lim, Q_out = Q > Q_lim)]
st <- merge(st, onset, by = "batch", all.x = TRUE)
setorder(st, batch, t_grid)

# Index of the sample that completes the first run of n consecutive TRUEs
first_run <- function(out, n = n_run) {
  r <- rle(out); s <- cumsum(r$lengths) - r$lengths + 1
  i <- which(r$values & r$lengths >= n)
  if (length(i)) s[i[1]] + n - 1L else NA_integer_
}
t_at <- function(t, i) if (is.na(i)) NA_real_ else t[i]

# ---- Per batch ----------------------------------------------------------------
per <- st[, {
  tT <- t_at(t_grid, first_run(T2_out)); tQ <- t_at(t_grid, first_run(Q_out))
  o  <- onset_h[1]
  pre <- if (is.na(o)) rep(FALSE, .N) else t_grid >= o - 24 & t_grid < o
  win <- if (is.na(o)) rep(FALSE, .N) else t_grid >= o & t_grid <= o + win_h
  .(onset_h = o,
    first_T2_h = tT, first_Q_h = tQ,
    pct_T2 = 100 * mean(T2_out), pct_Q = 100 * mean(Q_out),
    pre24_pct_out = if (is.na(o)) NA_real_ else 100 * mean((T2_out | Q_out)[pre]),
    onset_alarm   = if (is.na(o)) NA else !is.na(first_run((T2_out | Q_out)[win])))
}, by = .(batch, role, strategy, group)]

per[, first_alarm_h := pmin(first_T2_h, first_Q_h, na.rm = TRUE)]
per[, first_stat := fcase(is.na(first_alarm_h), NA_character_,
                          !is.na(first_T2_h) & first_T2_h == first_alarm_h &
                            !is.na(first_Q_h) & first_Q_h == first_alarm_h, "both",
                          !is.na(first_T2_h) & first_T2_h == first_alarm_h, "T2",
                          default = "Q")]
per[, flagged := !is.na(first_alarm_h)]
per[, delay_h := first_alarm_h - onset_h]
per[!is.na(onset_h), status := fcase(!flagged, "missed",
                                     delay_h < 0, "before onset",
                                     delay_h <= win_h, "at onset",
                                     default = "late")]

options(width = 200)
cat("\nAlarm rule:", n_run, "consecutive samples beyond the 99% limit, T2 or Q. Model:", tag, "\n")

cat("\n-- Batches flagged, by group --\n")
print(per[, .(flagged = paste0(sum(flagged), "/", .N)), by = group])

cat("\n-- Events and faults: timing --\n")
print(per[!is.na(onset_h), .(batch, role, strategy, onset_h, first_alarm_h, first_stat, delay_h,
                             status, pre24_pct_out = round(pre24_pct_out, 1), onset_alarm)][order(role, batch)])
print(per[!is.na(onset_h), .N, by = .(role, status)][order(role, status)])
print(per[!is.na(onset_h), .(alarm_in_onset_window = paste0(sum(onset_alarm), "/", .N)), by = role])

cat("\n-- Near-misses and Phase I batches --\n")
print(per[batch %in% c(17, 61, 66, 69, 75, p1_removed),
          .(batch, group, strategy, flagged, first_alarm_h, first_stat,
            pct_T2 = round(pct_T2, 1), pct_Q = round(pct_Q, 1))][order(batch)])

cat("\n-- Normal test batches flagged (false alarms) --\n")
print(per[role == "test" & flagged, .(batch, strategy, first_alarm_h, first_stat,
                                      pct_T2 = round(pct_T2, 1), pct_Q = round(pct_Q, 1))])

# ---- Compare with M1 (rules differ: M1 batch flag = % time out above the worst
# reference batch; M2 = run rule. Timing compares first alarms.) -----------------
m1 <- fread(here::here("results", "m1_detection_timing.csv"))[
  , .(batch, m1_first_alarm_h = first_alarm_h, m1_status = status)]
cmp <- merge(per[!is.na(onset_h), .(batch, role, m2_first_alarm_h = first_alarm_h, m2_status = status)],
             m1, by = "batch")
cat("\n-- M1 vs M2 --\n")
print(cmp[order(role, batch)])

# ---- Figure: event batches through the event ------------------------------------
pl <- melt(st[t_grid %between% c(40, 140) & group %in% c("reference (in sample)", "test_disturbance")],
           id.vars = c("batch", "t_grid", "group", "strategy"), measure.vars = c("T2", "Q"),
           variable.name = "stat")
pl[, stat := factor(stat, c("T2", "Q"), c("T²", "Q"))]
limd <- data.table(stat = factor(c("T²", "Q"), c("T²", "Q")), lim = c(T2_lim, Q_lim))
p_ev <- ggplot(pl, aes(t_grid, value, group = batch)) +
  geom_line(data = pl[group != "test_disturbance"], colour = col_ref, alpha = 0.3, linewidth = 0.2) +
  geom_line(data = pl[group == "test_disturbance"], aes(colour = strategy), linewidth = 0.4) +
  geom_hline(data = limd, aes(yintercept = lim), linetype = 2) +
  geom_vline(xintercept = 88, linetype = 3) +
  scale_y_log10() +
  scale_colour_manual(values = col_strat) +
  facet_wrap(~ stat, ncol = 1, scales = "free_y") +
  labs(title = "IndPenSim (simulated): PCA monitoring through the 90 h event",
       subtitle = paste0("Gray = reference batches; colour = 10 event batches; dashed = 99% limit; dotted = 88 h. Model: ", tag),
       x = "Time (h)", y = "Statistic (log scale)")
print(p_ev)

# ---- Save -------------------------------------------------------------------------
ggsave(here::here("figures", paste0("pca_event_trajectories_", tag, ".png")), p_ev,
       width = 9, height = 6, dpi = 150)
fwrite(per, here::here("results", paste0("m2_detection_", tag, ".csv")))
if (primary) {
  fwrite(per[role == "test_fault",
             .(batch, onset_h, flagged, first_alarm_h, first_stat, delay_h, status,
               method = paste0("PCA ", tag, ", T2/Q 99%, ", n_run, "-sample run rule"))],
         here::here("results", "fault_detection.csv"))
}