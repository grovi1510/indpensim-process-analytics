# 05_event_90h_test.R
# Tests the 90 h event hypothesis on IndPenSim (simulated) data:
# 1. Were the event batches more metabolically active (OUR, CER) before 88 h?
# 2. Does every batch get the aeration (Fg) step at ~90 h?

library(data.table); library(ggplot2)

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

p <- ggplot(pre, aes(disturbance_90h, OUR)) +
  geom_boxplot(outlier.shape = NA) +
  geom_jitter(aes(colour = strategy), width = 0.15) +
  labs(title = "IndPenSim (simulated): pre-event OUR, 70–88 h") +
  theme_minimal()
print(p)

# 2. Aeration step at ~90 h: before vs after, per batch
fg <- dt[`Time (h)` %between% c(85, 95)][order(`Time (h)`),
                                         .(before = first(Fg), after = last(Fg)), by = .(batch = `Batch ID`)]
print(fg[, .N, by = .(step_up = after > before)])

ggsave(here::here("figures", "event_90h_pre_OUR.png"), p, width = 6, height = 6, dpi = 150)
