# 07_control_charts_varying.R
# Time-varying limits (mean ± 3 SD at each time point) for Fb, DO2, CER.
# Reference: 16 clean recipe training batches. IndPenSim (simulated).

library(data.table); library(ggplot2)
source(here::here("R", "theme_portfolio.R"))
source(here::here("R", "key_variables.R"))

dt <- readRDS(here::here("data", "processed", "process_vars.rds"))
setnames(dt, sub("^[^(]*\\(([^:]+):.*$", "\\1", names(dt)))
setnames(dt, c("Time (h)", "Batch ID"), c("time", "batch"))
dt <- merge(dt, fread(here::here("splits", "batch_split.csv")), by = "batch")
dt[, t_grid := round(time, 1)]   # align batches on a common time grid

ref <- dt[role == "train" & strategy == "recipe" & !batch %in% ref_excluded]

# Envelope: mean ± 3 SD across reference batches at each time point
env <- melt(ref, id.vars = c("batch", "t_grid"), measure.vars = varying_lim)[,
                                                                             .(center = mean(value), sd = sd(value), n = .N), by = .(variable, t_grid)][n >= 10]
# Floor on SD: where all reference batches are nearly identical, SD ~ 0 would alarm on anything
env[, sd := pmax(sd, quantile(sd, 0.10, na.rm = TRUE)), by = variable]
env[, `:=`(lcl = center - 3 * sd, ucl = center + 3 * sd)]
# Fb, DO2 and CER can't be negative: floor the lower limit at 0
env[, lcl := pmax(lcl, 0)]

# Plot: envelope, one 90 h event batch (44) and one fault batch (93)
show <- dt[batch %in% c(44, 93)]
show_long <- melt(show, id.vars = c("batch", "t_grid"), measure.vars = varying_lim)
p_env <- ggplot(env, aes(t_grid)) +
  geom_ribbon(aes(ymin = lcl, ymax = ucl), fill = col_ref, alpha = 0.5) +
  geom_line(aes(y = center), colour = col_ref) +
  geom_line(data = show_long, aes(y = value, colour = factor(batch)), linewidth = 0.4) +
  scale_colour_manual(values = c("44" = col_strat[["recipe"]], "93" = col_strat[["apc_raman"]]),
                      name = "Batch") +
  facet_wrap(~ variable, scales = "free_y", ncol = 1) +
  labs(title = "IndPenSim (simulated): time-varying limits, Fb, DO2, CER",
       x = "Time (h)", y = NULL)
print(p_env)

# Alarms for every batch (times beyond the envelope are dropped)
long <- melt(dt, id.vars = c("batch", "t_grid", "role", "strategy"), measure.vars = varying_lim)
long <- merge(long, env, by = c("variable", "t_grid"))
long[, out := value < lcl | value > ucl]

alarms_v <- long[, .(pct_out = 100 * mean(out),
                     first_alarm_h = if (any(out)) min(t_grid[out]) else NA_real_),
                 by = .(batch, role, strategy, variable)]

# Same batch-level rule as for pH and T: worse than the worst clean reference batch
thr <- alarms_v[batch %in% unique(ref$batch), .(thr = max(pct_out)), by = variable]
print(thr)
alarms_v <- merge(alarms_v, thr, by = "variable")[, batch_alarm := pct_out > thr]

print(dcast(alarms_v[role != "train"], role + strategy ~ variable, value.var = "batch_alarm",
            fun.aggregate = function(x) paste0(sum(x), "/", length(x))))

# When are the 90 h event batches first flagged?
print(alarms_v[role == "test_disturbance" & batch_alarm == TRUE,
               .(batch, variable, first_alarm_h)][order(variable, batch)])

comb <- alarms_v[, .(any_alarm = any(batch_alarm)), by = .(batch, role, strategy)]
print(comb[role != "train", .(flagged = paste0(sum(any_alarm), "/", .N)), by = role])

ggsave(here::here("figures", "varying_limits_Fb_DO2_CER.png"), p_env, width = 8, height = 8, dpi = 150)
fwrite(alarms_v, here::here("results", "varying_limits_alarms.csv"))
