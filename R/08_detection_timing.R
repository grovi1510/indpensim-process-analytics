# 08_detection_timing.R
# First alarm vs onset for fault (91-100) and 90 h event batches.
# Onset: faults from Fault_ref; events at 88 h (DO2 minimum, 03_screen_variables.R). IndPenSim (simulated).

library(data.table)

dt <- readRDS(here::here("data", "processed", "process_vars.rds"))
setnames(dt, sub("^[^(]*\\(([^:]+):.*$", "\\1", names(dt)))
setnames(dt, c("Time (h)", "Batch ID"), c("time", "batch"))

al <- rbind(fread(here::here("results", "fixed_limits_alarms.csv")),
            fread(here::here("results", "varying_limits_alarms.csv")),
            use.names = TRUE)

onset <- rbind(
  dt[batch %in% 91:100 & as.numeric(Fault_ref) > 0,
     .(onset_h = min(time), role = "test_fault"), by = batch],
  data.table(batch = al[role == "test_disturbance", unique(batch)],
             onset_h = 88, role = "test_disturbance")
)

first <- al[batch_alarm == TRUE,
            .(first_alarm_h = min(first_alarm_h),
              first_var = variable[which.min(first_alarm_h)]),
            by = batch]

tim <- merge(onset, first, by = "batch", all.x = TRUE)
tim[, delay_h := first_alarm_h - onset_h]
tim[, status := fcase(is.na(first_alarm_h), "missed",
                      delay_h < 0,          "before onset",
                      default =             "after onset")]

print(tim[order(role, batch)])
print(tim[, .N, by = .(role, status)][order(role, status)])

fwrite(tim, here::here("results", "m1_detection_timing.csv"))

summ <- al[role != "train",
           .(all5  = any(batch_alarm),
             no_fb = any(batch_alarm[variable != "Fb"])),
           by = .(batch, role)][,
                                .(all5  = paste0(sum(all5), "/", .N),
                                  no_fb = paste0(sum(no_fb), "/", .N)),
                                by = role]
print(summ)
fwrite(summ, here::here("results", "m1_summary.csv"))