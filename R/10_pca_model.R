# M2.1: arrange the batch data for PCA, fit on the reference set, choose the
# number of components. Decisions were recorded in docs/m2_decisions.md before
# this script was run. IndPenSim (simulated), Goldrick et al., DOI 10.17632/pdnjz7zz5x.2
#
# Unfolding: observation-wise. Each variable is standardised against the
# reference trajectory (mean and SD across reference batches at each time
# point, the same envelope idea as 07_), then PCA runs on rows = batch x time.
# This gives a T2 and Q value at every sample, so detection can be timed
# against onset (88 h for the events), as in M1.

library(data.table); library(ggplot2)
source(here::here("R", "theme_portfolio.R"))
source(here::here("R", "key_variables.R"))   # ref_excluded = c(7, 20)

ref_set <- "all_train"   # primary; "recipe_train" = sensitivity run matching M1's reference

# ---- Data -------------------------------------------------------------------
dt <- readRDS(here::here("data", "processed", "process_vars.rds"))
setnames(dt, sub("^[^(]*\\(([^:]+):.*$", "\\1", names(dt)))
setnames(dt, c("Time (h)", "Batch ID"), c("time", "batch"))
dt <- merge(dt, fread(here::here("splits", "batch_split.csv")), by = "batch")
dt[, t_grid := round(time, 1)]

# Online process measurements only. Left out: P (outcome), offline columns,
# S and X (simulator states, not measured online in a plant), Q (calculated),
# labels and reference codes.
cand <- c("Fg", "RPM", "Fs", "Fa", "Fb", "Fc", "Fh", "Fw", "pressure", "Fremoved",
          "DO2", "V", "Wt", "pH", "T", "CO2outgas", "O2", "OUR", "CER", "Fpaa", "Foil")
not_found <- setdiff(cand, names(dt))
if (length(not_found)) message("Not found, check names(dt): ", paste(not_found, collapse = ", "))
cand <- intersect(cand, names(dt))

ref_batches <- switch(ref_set,
                      all_train    = dt[role == "train" & !batch %in% ref_excluded, sort(unique(batch))],
                      recipe_train = dt[role == "train" & strategy == "recipe" & !batch %in% ref_excluded, sort(unique(batch))])
cat(ref_set, ":", length(ref_batches), "reference batches\n")

# ---- 1. Reference trajectory (mean, SD per variable and time point) ---------
long <- melt(dt[, c("batch", "t_grid", cand), with = FALSE],
             id.vars = c("batch", "t_grid"), variable.factor = FALSE)
min_n <- max(10, ceiling(0.5 * length(ref_batches)))   # need enough batches at a time point
traj  <- long[batch %in% ref_batches,
              .(mu = mean(value, na.rm = TRUE), s = sd(value, na.rm = TRUE), n = .N),
              by = .(variable, t_grid)][n >= min_n]

# Drop variables that are set by recipe and identical across reference batches
# for most of the batch (SD ~ 0): they carry no information about normal variation.
zero_sd <- traj[, .(frac_zero = mean(s < 1e-8)), by = variable]
print(zero_sd[order(-frac_zero)])
pca_vars <- zero_sd[frac_zero <= 0.5, variable]
cat("PCA variables (", length(pca_vars), "):", paste(pca_vars, collapse = ", "), "\n")

# Phase I exclusions from M2.2 (no file until 11_ has run once)
f_p1 <- here::here("results", paste0("phase1_excluded_", ref_set, ".csv"))
if (file.exists(f_p1)) {
  p1_out <- fread(f_p1)$batch
  ref_batches <- setdiff(ref_batches, p1_out)
  cat("Phase I exclusions:", paste(p1_out, collapse = ", "), "->", length(ref_batches), "batches\n")
}

# SD floor, as in 07_: avoid dividing by ~0 where reference batches coincide
traj <- traj[variable %in% pca_vars]
traj[, s := pmax(s, quantile(s[s > 1e-8], 0.10)), by = variable]

# ---- 2. Standardise every batch against the reference trajectory ------------
z <- merge(long[variable %in% pca_vars], traj[, .(variable, t_grid, mu, s)],
           by = c("variable", "t_grid"))          # times beyond the grid drop out
z[, value := (value - mu) / s]
X <- dcast(z, batch + t_grid ~ variable, value.var = "value")
X <- merge(X, unique(dt[, .(batch, role, strategy)]), by = "batch")
X <- X[complete.cases(X[, ..pca_vars])]

Xref <- X[batch %in% ref_batches]
cat("Reference matrix:", nrow(Xref), "rows x", length(pca_vars), "variables\n")

# ---- 3. PCA on the reference rows ------------------------------------------
pca <- prcomp(as.matrix(Xref[, ..pca_vars]), center = TRUE, scale. = FALSE)
ev  <- pca$sdev^2
p   <- length(ev)
comp <- data.table(pc = seq_len(p), eigenvalue = ev,
                   pct = 100 * ev / sum(ev), cum_pct = 100 * cumsum(ev) / sum(ev),
                   broken_stick_pct = 100 * rev(cumsum(1 / rev(seq_len(p)))) / p)

# ---- 4. Leave-batch-out check: does each component explain held-out batches? -
# In-sample variance always rises with more components; a component that is
# real structure should also explain variance in a batch the model never saw.
amax <- min(10, p)
lbo <- rbindlist(lapply(ref_batches, function(b) {
  tr <- as.matrix(Xref[batch != b, ..pca_vars])
  te <- as.matrix(Xref[batch == b, ..pca_vars])
  m  <- prcomp(tr, center = TRUE, scale. = FALSE, rank. = amax)
  E0 <- sweep(te, 2, m$center)
  data.table(batch = b, pc = seq_len(amax), ss0 = sum(E0^2),
             resid_ss = vapply(seq_len(amax), function(a) {
               P <- m$rotation[, seq_len(a), drop = FALSE]
               sum((E0 - E0 %*% P %*% t(P))^2)
             }, numeric(1)))
}))
cv <- lbo[, .(cum_pct_lbo = 100 * (1 - sum(resid_ss) / sum(ss0))), by = pc]
comp <- merge(comp, cv, by = "pc", all.x = TRUE)
comp[, `:=`(gain_in = c(cum_pct[1], diff(cum_pct)),
            gain_lbo = c(cum_pct_lbo[1], diff(cum_pct_lbo)))]
print(comp[pc <= amax], digits = 3)

# ---- 5. Figures --------------------------------------------------------------
sc <- melt(comp[pc <= amax], id.vars = "pc",
           measure.vars = c("pct", "broken_stick_pct", "gain_lbo"))
sc[, variable := factor(variable, c("pct", "gain_lbo", "broken_stick_pct"),
                        c("In-sample", "Leave-batch-out", "Broken stick"))]
p_scree <- ggplot(sc, aes(pc, value, colour = variable)) +
  geom_line() + geom_point() +
  scale_colour_manual(values = c(col_strat[["recipe"]], col_strat[["apc_raman"]], col_ref),
                      name = NULL) +
  scale_x_continuous(breaks = seq_len(amax)) +
  labs(title = "IndPenSim (simulated): variance explained per component",
       subtitle = paste0("Reference: ", ref_set, " (", length(ref_batches), " batches)"),
       x = "Principal component", y = "% variance")
print(p_scree)

# Do the control strategies separate in the reference? If so, a pooled model
# mixes three operating modes and that has to be said in the report.
bs <- Xref[, c("batch", "strategy"), with = FALSE][, `:=`(PC1 = pca$x[, 1], PC2 = pca$x[, 2])][
  , .(PC1 = mean(PC1), PC2 = mean(PC2)), by = .(batch, strategy)]
p_strat <- ggplot(bs, aes(PC1, PC2, colour = strategy, shape = strategy)) +
  geom_point(size = 2) +
  geom_text(aes(label = batch), size = 2.5, vjust = -0.9, show.legend = FALSE) +
  scale_colour_manual(values = col_strat) +
  labs(title = "IndPenSim (simulated): batch-mean scores by control strategy",
       subtitle = "Reference batches only", x = "Mean PC1 score", y = "Mean PC2 score")
print(p_strat)

# ---- 6. Choose k, then save --------------------------------------------------
k <- 1L  # set after reading the table and figure, and record why in m2_decisions.md
if (!is.na(k)) {
  print(round(pca$rotation[, seq_len(k)], 2))   # loadings for interpretation
  dir.create(here::here("results"), showWarnings = FALSE)
  fwrite(comp, here::here("results", paste0("pca_components_", ref_set, ".csv")))
  ggsave(here::here("figures", paste0("pca_scree_", ref_set, ".png")), p_scree, width = 7, height = 4.5, dpi = 150)
  ggsave(here::here("figures", paste0("pca_strategy_", ref_set, ".png")), p_strat, width = 6, height = 4.5, dpi = 150)
  # Model for M2.2 (derived, small; stays in the ignored data folder)
  saveRDS(list(ref_set = ref_set, ref_batches = ref_batches, vars = pca_vars, traj = traj,
               center = pca$center, rotation = pca$rotation[, seq_len(k), drop = FALSE],
               sdev = pca$sdev, k = k, n_ref_rows = nrow(Xref)),
          here::here("data", "processed", paste0("pca_model_", ref_set, ".rds")))
  saveRDS(X, here::here("data", "processed", paste0("pca_X_", ref_set, ".rds")))
}