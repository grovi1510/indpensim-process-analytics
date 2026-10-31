# 06_control_charts_fixed.R
# Fixed-limit control charts for the controlled variables (pH, T).
# Reference: training batches from 1–30 (recipe). IndPenSim (simulated).

library(data.table); library(ggplot2)

dt <- readRDS(here::here("data", "processed", "process_vars.rds"))
setnames(dt, sub("^[^(]*\\(([^:]+):.*$", "\\1", names(dt)))
setnames(dt, c("Time (h)", "Batch ID"), c("time", "batch"))

split <- fread(here::here("splits", "batch_split.csv"))
dt <- merge(dt, split, by = "batch")
source(here::here("R", "key_variables.R"))

source(here::here("R", "theme_portfolio.R"))

ref_all <- dt[role == "train" & strategy == "recipe"]

# Phase I clean-up: unlabelled events found in reference batches
# batch 7: pH excursion 161-206 h (min 5.70); batch 20: T spike at ~90 h (299.7 K)
ref_excluded <- c(7, 20)

long_ref <- melt(ref_all, id.vars = c("batch", "time"), measure.vars = fixed_lim)
long_ref[, excluded := batch %in% ref_excluded]

p_ref <- ggplot(long_ref, aes(time, value, group = batch)) +
  geom_line(data = long_ref[excluded == FALSE], colour = col_ref, linewidth = 0.3) +
  geom_line(data = long_ref[excluded == TRUE], aes(colour = factor(batch)), linewidth = 0.6) +
  scale_colour_manual(values = c("7" = col_strat[["recipe"]], "20" = col_strat[["apc_raman"]]),
                      name = "Excluded from reference") +
  facet_wrap(~ variable, scales = "free_y", ncol = 1) +
  labs(title = "IndPenSim (simulated): recipe reference batches, pH and T",
       x = "Time (h)", y = NULL)
print(p_ref)
ggsave(here::here("figures", "reference_pH_T_phase1.png"), p_ref, width = 8, height = 6, dpi = 150)

ref <- ref_all[!batch %in% ref_excluded]   # 16 batches used for the limits

# Part B: fixed limits (mean ± 3 SD) from the 16 clean reference batches, after start-up
t_start <- 50   # start-up transients settle by ~50 h (see reference plot)

limits <- melt(ref[time >= t_start], id.vars = c("batch", "time"),
               measure.vars = fixed_lim)[,
                                         .(center = mean(value), sd = sd(value)), by = variable][,
                                                                                                 `:=`(lcl = center - 3 * sd, ucl = center + 3 * sd)]
print(limits)

# Apply to every batch
long <- melt(dt[time >= t_start], id.vars = c("batch", "time", "role", "strategy"),
             measure.vars = fixed_lim)
long <- merge(long, limits, by = "variable")
long[, out := value < lcl | value > ucl]

alarms <- long[, .(pct_out = 100 * mean(out),
                   first_alarm_h = if (any(out)) min(time[out]) else NA_real_),
               by = .(batch, role, strategy, variable)]

# Summary: how many batches in each group raise at least one alarm?
print(alarms[, .(batches = .N,
                 with_alarm = sum(pct_out > 0),
                 median_pct_out = round(median(pct_out), 2)),
             by = .(variable, role)][order(variable, role)])

# Batch-level rule: alarm if % time out of limits exceeds the worst clean reference batch
thr <- alarms[batch %in% unique(ref$batch), .(thr = max(pct_out)), by = variable]
print(thr)

alarms <- merge(alarms, thr, by = "variable")
alarms[, batch_alarm := pct_out > thr]

print(dcast(alarms[role != "train"],
            role + strategy ~ variable,
            value.var = "batch_alarm",
            fun.aggregate = function(x) paste0(sum(x), "/", length(x))))

dir.create(here::here("results"), showWarnings = FALSE)
fwrite(limits, here::here("results", "fixed_limits_pH_T.csv"))
fwrite(alarms, here::here("results", "fixed_limits_alarms.csv"))