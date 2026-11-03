# 09_event_zoom.R
# Order of events around the 90 h event. Each batch is aligned on its own aeration (Fg)
# step, and event batches are compared with no-event batches. IndPenSim (simulated).

library(data.table); library(ggplot2)
source(here::here("R", "theme_portfolio.R"))

dt <- readRDS(here::here("data", "processed", "process_vars.rds"))
setnames(dt, sub("^[^(]*\\(([^:]+):.*$", "\\1", names(dt)))
setnames(dt, c("Time (h)", "Batch ID"), c("time", "batch"))
dt <- merge(dt, fread(here::here("splits", "batch_split.csv")), by = "batch")
dt <- dt[strategy != "fault"]   # batch 100 (event + fault) excluded, as in 05
dt[, RQ := CER / OUR]           # ratio only: CER is g/h and OUR g/min, so not a true respiratory quotient

# 1. Timing: aeration step vs DO2 minimum, per batch (80-100 h window)
win   <- dt[time %between% c(80, 100)][order(batch, time)]
steps <- win[, .(t_step    = time[which(Fg > first(Fg))[1]],
                 fg_before = first(Fg), fg_after = last(Fg),
                 t_do2_min = time[which.min(DO2)], do2_min = min(DO2)),
             by = .(batch, disturbance_90h)]
steps[, lag_h := t_do2_min - t_step]   # negative = DO2 minimum before the aeration step

print(steps[disturbance_90h == TRUE][order(batch)])
print(steps[, .(n = .N,
                step_from = min(t_step), step_to = max(t_step),
                median_do2_min = median(do2_min),
                median_lag_h = median(lag_h)),
            by = disturbance_90h])

# 2. Zoom: -4 h to +2 h around each batch's own step
zoom_vars <- c("Fg", "DO2", "OUR", "CER", "RQ", "pH", "Fb")
z  <- merge(dt, steps[, .(batch, t_step)], by = "batch")[, t_rel := time - t_step][t_rel %between% c(-4, 2)]
zl <- melt(z, id.vars = c("batch", "t_rel", "disturbance_90h"), measure.vars = zoom_vars)

p <- ggplot(zl, aes(t_rel, value, group = batch)) +
  geom_line(data = zl[disturbance_90h == FALSE], colour = col_ref, alpha = 0.4, linewidth = 0.3) +
  geom_line(data = zl[disturbance_90h == TRUE], colour = col_strat[["fault"]], linewidth = 0.5) +
  geom_vline(xintercept = 0, linetype = 2) +
  facet_wrap(~ variable, scales = "free_y", ncol = 2) +
  labs(title = "IndPenSim (simulated): order of events around the aeration step",
       subtitle = "Aligned on each batch's own Fg step; black = event batches (n = 10), gray = no-event (n = 80)",
       x = "Hours from aeration step", y = NULL)
print(p)

ggsave(here::here("figures", "event_90h_zoom.png"), p, width = 9, height = 10, dpi = 150)
fwrite(steps, here::here("results", "event_90h_timing.csv"))

# 3. Hours at the base-pump ceiling (Fb >= 224 L/h; data sampled every 0.2 h), no-event batches.
#    More than 10 h (median is about 3 h) marks a Phase I review candidate for M2's reference set.
fb_ceiling <- dt[disturbance_90h == FALSE,
                 .(h_Fb_max  = 0.2 * sum(Fb >= 224),
                   CER_70_88 = mean(CER[time >= 70 & time < 88]),
                   role = first(role), strategy = first(strategy)),
                 by = batch]
print(fb_ceiling[, summary(h_Fb_max)])
print(fb_ceiling[h_Fb_max > 10][order(-h_Fb_max)])
fwrite(fb_ceiling, here::here("results", "fb_ceiling_hours.csv"))
