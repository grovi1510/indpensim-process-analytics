# 05_event_90h_test.R
# Tests the 90 h event hypothesis on IndPenSim (simulated) data:
# 1. Were the event batches more metabolically active (OUR, CER) before 88 h?
# 2. Does every batch get the aeration (Fg) step at ~90 h?

library(data.table); library(ggplot2)
source(here::here("R", "theme_portfolio.R"))

# Data: cleaned process variables from 01_load_data.R, with short column names
dt <- readRDS(here::here("data", "processed", "process_vars.rds"))
setnames(dt, sub("^[^(]*\\(([^:]+):.*$", "\\1", names(dt)))  # "Temperature(T:K)" -> "T"

split <- fread(here::here("splits", "batch_split.csv"))

# 1. Pre-event activity, 70–88 h window (fault batches excluded)
pre <- dt[`Time (h)` >= 70 & `Time (h)` < 88,
          .(OUR = mean(OUR), CER = mean(CER)), by = .(batch = `Batch ID`)]
pre <- merge(pre, split, by = "batch")[strategy != "fault"]

print(pre[, .(n = .N, OUR = median(OUR), CER = median(CER)), by = disturbance_90h])
print(wilcox.test(OUR ~ disturbance_90h, data = pre))
print(wilcox.test(CER ~ disturbance_90h, data = pre))

# Boxplot: same per-batch means as the tests; borderline batches 17, 66 (no event) and 89 (event) labelled
pre[, group := factor(fifelse(disturbance_90h, "Event", "No event"), levels = c("No event", "Event"))]
pre_long <- melt(pre, id.vars = c("batch", "group", "strategy"), measure.vars = c("OUR", "CER"))
pre_long[, lab := fifelse(batch %in% c(17, 66, 89), as.character(batch), "")]
jit <- position_jitter(width = 0.15, height = 0, seed = 1)   # same jitter for points and labels

p <- ggplot(pre_long, aes(group, value)) +
  geom_boxplot(outlier.shape = NA, colour = col_ref) +
  geom_point(aes(colour = strategy), position = jit, size = 1.5) +
  geom_text(aes(label = lab), position = jit, vjust = -0.8, size = 3) +
  scale_colour_manual(values = col_strat, name = "Control strategy") +
  facet_wrap(~ variable, scales = "free_y") +
  labs(title = "IndPenSim (simulated): activity before the 90 h event",
       subtitle = "Per-batch mean, 70–88 h; fault batches excluded",
       x = NULL, y = NULL)
print(p)
ggsave(here::here("figures", "event_90h_pre_activity.png"), p, width = 8, height = 4.5, dpi = 150)
fwrite(pre, here::here("results", "event_pre_activity.csv"))   # used by the M1 report

# 2. Aeration step at ~90 h: before vs after, per batch
fg <- dt[`Time (h)` %between% c(85, 95)][order(`Time (h)`),
                                         .(before = first(Fg), after = last(Fg)), by = .(batch = `Batch ID`)]
print(fg[, .N, by = .(step_up = after > before)])

