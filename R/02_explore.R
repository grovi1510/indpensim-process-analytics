# 02_explore.R
# Check batch groups against the documented structure and plot penicillin titer.

library(data.table)
library(ggplot2)

proc <- readRDS("data/processed/process_vars.rds")

# Batch groups as documented (1-30 recipe, 31-60 operator, 61-90 Raman APC, 91-100 faults)
proc[, grp := cut(`Batch ID`, c(0, 30, 60, 90, 100),
                  labels = c("1-30 Recipe", "31-60 Operator",
                             "61-90 Raman APC", "91-100 Faults"))]

# Do the label columns agree with the groups?
ctrl_col  <- "0 - Recipe driven 1 - Operator controlled(Control_ref:Control ref)"
fault_col <- "Fault reference(Fault_ref:Fault ref)"
lab <- proc[, .(control    = paste(unique(get(ctrl_col)),  collapse = ","),
                pat        = paste(unique(PAT_ref),        collapse = ","),
                fault_ref  = paste(unique(get(fault_col)), collapse = ","),
                fault_flag = paste(unique(`Fault flag`),   collapse = ",")),
            by = .(`Batch ID`, grp)]
print(lab[, .N, by = .(grp, control, pat, fault_ref, fault_flag)])

# Penicillin trajectories by group
dir.create("figures", showWarnings = FALSE)
p <- ggplot(proc, aes(`Time (h)`, `Penicillin concentration(P:g/L)`,
                      group = `Batch ID`, colour = grp)) +
  geom_line(alpha = 0.5) +
  facet_wrap(~ grp) +
  labs(title = "IndPenSim (simulated): penicillin concentration by batch group",
       y = "Penicillin (g/L)") +
  theme_minimal() + theme(legend.position = "none")
print(p)
ggsave("figures/penicillin_by_group.png", p, width = 9, height = 6, dpi = 150)