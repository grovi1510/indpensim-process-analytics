# 03_screen_variables.R
# Screen process variables in the reference batches (1-30) to choose candidates
# for control charts: online vs offline, constant vs varying.

library(data.table)

proc <- readRDS("data/processed/process_vars.rds")
ref  <- proc[`Batch ID` %in% 1:30]

label_cols <- c("Time (h)", "Batch ID", "Fault flag", "PAT_ref",
                "0 - Recipe driven 1 - Operator controlled(Control_ref:Control ref)",
                "Fault reference(Fault_ref:Fault ref)",
                "Batch reference(Batch_ref:Batch ref)")
vars <- setdiff(names(proc), label_cols)

screen <- rbindlist(lapply(vars, function(v) {
  x <- ref[[v]]
  data.table(variable    = v,
             pct_present = round(100 * mean(!is.na(x)), 1),
             pct_zero    = round(100 * mean(x == 0, na.rm = TRUE), 1),
             n_unique    = uniqueN(x, na.rm = TRUE),
             mean        = signif(mean(x, na.rm = TRUE), 3),
             sd          = signif(sd(x, na.rm = TRUE), 3))
}))

options(width = 200)
print(screen[order(pct_present, -pct_zero)], nrows = 50)

library(ggplot2)

# Control-loop map: controlled variable (CV), manipulated variables (MV), disturbance
loops <- list(
  temperature = c(CV          = "Temperature(T:K)",
                  MV_cooling  = "Heating/cooling water flow rate(Fc:L/h)",
                  MV_heating  = "Heating water flow rate(Fh:L/h)",
                  Disturbance = "Generated heat(Q:kJ)"),
  pH          = c(CV          = "pH(pH:pH)",
                  MV_base     = "Base flow rate(Fb:L/h)",
                  MV_acid     = "Acid flow rate(Fa:L/h)",
                  Disturbance = "Carbon evolution rate(CER:g/h)"),
  oxygen      = c(Response    = "Dissolved oxygen concentration(DO2:mg/L)",
                  Demand      = "Oxygen Uptake Rate(OUR:(g min^{-1}))",
                  Supply      = "Aeration rate(Fg:L/h)")
)

sub <- proc[`Batch ID` %in% c(1:30, 91:100)]
sub[, set := fifelse(`Batch ID` <= 30, "Reference 1-30", "Faults 91-100")]

plot_loop <- function(name) {
  v <- loops[[name]]
  d <- melt(sub, id.vars = c("Batch ID", "Time (h)", "set"),
            measure.vars = unname(v))
  d[, panel := factor(paste0(names(v)[match(variable, v)], ": ", variable),
                      levels = paste0(names(v), ": ", v))]
  p <- ggplot(mapping = aes(`Time (h)`, value, group = `Batch ID`)) +
    geom_line(data = d[set == "Reference 1-30"], colour = "grey75", alpha = 0.6) +
    geom_line(data = d[set == "Faults 91-100"],
              aes(colour = factor(`Batch ID`)), linewidth = 0.6) +
    scale_colour_brewer(palette = "Paired", name = "Fault batch") +
    facet_wrap(~ panel, scales = "free_y", ncol = 1) +
    labs(title = paste("IndPenSim (simulated):", name, "loop"),
         subtitle = "Grey = reference batches 1-30") +
    theme_minimal() + theme(legend.position = "right")
  print(p)
  ggsave(paste0("figures/loop_", name, ".png"), p, width = 10, height = 9, dpi = 150)
}

for (nm in names(loops)) plot_loop(nm)

do_col <- "Dissolved oxygen concentration(DO2:mg/L)"
event <- proc[`Time (h)` %between% c(80, 110),
              .(min_DO = min(get(do_col)),
                t_min  = `Time (h)`[which.min(get(do_col))]),
              by = `Batch ID`][min_DO < 6]
print(event)

zoom_vars <- screen[pct_present == 100 & n_unique > 1, variable]
z <- melt(proc[`Batch ID` %in% c(1, 44) & `Time (h)` %between% c(80, 100)],
          id.vars = c("Batch ID", "Time (h)"), measure.vars = zoom_vars)

p <- ggplot(z, aes(`Time (h)`, value, colour = factor(`Batch ID`))) +
  geom_line() +
  geom_vline(xintercept = 90, linetype = 2) +
  facet_wrap(~ variable, scales = "free_y", ncol = 4) +
  scale_colour_manual(values = c("1" = "grey50", "44" = "firebrick"), name = "Batch") +
  labs(title = "IndPenSim (simulated): batch 44 vs batch 1 around the 90 h event") +
  theme_minimal(base_size = 8)
print(p)
ggsave("figures/event_90h_batch44.png", p, width = 12, height = 10, dpi = 150)

z[, code := sub("^.*\\(([^:]+):.*$", "\\1", variable)]
z[, code := factor(code, levels = unique(code))]

p <- ggplot(z, aes(`Time (h)`, value, colour = factor(`Batch ID`))) +
  geom_line() +
  geom_vline(xintercept = 90, linetype = 2) +
  facet_wrap(~ code, scales = "free_y", ncol = 4) +
  scale_colour_manual(values = c("1" = "grey50", "44" = "firebrick"), name = "Batch") +
  labs(title = "IndPenSim (simulated): batch 44 vs batch 1 around the 90 h event") +
  theme_minimal(base_size = 9)
print(p)
ggsave("figures/event_90h_batch44.png", p, width = 12, height = 10, dpi = 150)$$