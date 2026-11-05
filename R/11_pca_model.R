# M2.2: Hotelling's T2 and Q (SPE) for every sample, 99% limits, Phase I review.
# Rule (docs/m2_decisions.md): remove a reference batch if T2 or Q exceeds its
# 99% limit for > 10% of its time points; refit once, no further iterations.
# IndPenSim (simulated), Goldrick et al., DOI 10.17632/pdnjz7zz5x.2
#
# Run order: 10_ -> 11_ (writes Phase I exclusions) -> 10_ again (refit,
# re-check broken stick) -> 11_ again (final limits; no new removals).

library(data.table); library(ggplot2)
source(here::here("R", "theme_portfolio.R"))

ref_set <- "all_train"
alpha   <- 0.99
p1_max  <- 10   # % of a batch's time points beyond a limit

m <- readRDS(here::here("data", "processed", paste0("pca_model_", ref_set, ".rds")))
X <- readRDS(here::here("data", "processed", paste0("pca_X_", ref_set, ".rds")))
vars <- m$vars; k <- m$k; n <- as.numeric(m$n_ref_rows)   # numeric: n^2 overflows an integer

# ---- T2 and Q for every sample, all batches -----------------------------------
Xc  <- sweep(as.matrix(X[, ..vars]), 2, m$center)
Tsc <- Xc %*% m$rotation
lam <- m$sdev[seq_len(k)]^2
X[, T2 := rowSums(sweep(Tsc^2, 2, lam, "/"))]
X[, Q  := rowSums((Xc - Tsc %*% t(m$rotation))^2)]

# ---- Limits -------------------------------------------------------------------
# Primary: theoretical. T2 from the F distribution; Q from Box's approximation
# (g * chi2(h), matched to the mean and variance of reference Q).
# Empirical 99th percentiles of the reference are printed as a check: a large
# gap means the theoretical assumptions (independent, normal rows) don't hold.
ref <- X[batch %in% m$ref_batches]
mq <- mean(ref$Q); vq <- var(ref$Q)
lim <- data.table(
  stat        = c("T2", "Q"),
  theoretical = c(k * (n^2 - 1) / (n * (n - k)) * qf(alpha, k, n - k),
                  (vq / (2 * mq)) * qchisq(alpha, 2 * mq^2 / vq)),
  empirical   = c(quantile(ref$T2, alpha), quantile(ref$Q, alpha)))
print(lim)
stopifnot(!anyNA(lim$theoretical))   # put this right after print(lim)
T2_lim <- lim[stat == "T2", theoretical]
Q_lim  <- lim[stat == "Q",  theoretical]
cat("Reference rows beyond limit: T2", round(100 * mean(ref$T2 > T2_lim), 2),
    "%, Q", round(100 * mean(ref$Q > Q_lim), 2), "% (nominal", 100 * (1 - alpha), "%)\n")

# ---- Phase I review -------------------------------------------------------------
p1 <- ref[, .(pct_T2 = 100 * mean(T2 > T2_lim), pct_Q = 100 * mean(Q > Q_lim)),
          by = .(batch, strategy)]
p1[, remove := pct_T2 > p1_max | pct_Q > p1_max]
p1 <- merge(p1, fread(here::here("results", "fb_ceiling_hours.csv"))[, .(batch, h_Fb_max)],
            by = "batch")
print(p1[order(-pmax(pct_T2, pct_Q))][1:12])

f_p1 <- here::here("results", paste0("phase1_excluded_", ref_set, ".csv"))
if (!file.exists(f_p1)) {
  # First pass: record the removals, then refit with 10_
  fwrite(p1[remove == TRUE, .(batch, strategy, pct_T2, pct_Q, h_Fb_max)], f_p1)
  fwrite(p1, here::here("results", paste0("phase1_review_", ref_set, ".csv")))
  
  pl <- melt(p1, id.vars = c("batch", "strategy"), measure.vars = c("pct_T2", "pct_Q"))
  pl[, variable := factor(variable, c("pct_T2", "pct_Q"), c("T²", "Q"))]
  p_p1 <- ggplot(pl, aes(factor(batch), value, colour = strategy, shape = strategy)) +
    geom_point(size = 2) +
    geom_hline(yintercept = p1_max, linetype = 2, colour = col_ref) +
    scale_colour_manual(values = col_strat) +
    facet_wrap(~ variable, ncol = 1) +
    labs(title = "IndPenSim (simulated): Phase I review of the PCA reference batches",
         subtitle = paste0("% of time points beyond the 99% limit; dashed line = ", p1_max,
                           "% removal rule"),
         x = "Reference batch", y = "% time beyond limit") +
    theme(axis.text.x = element_text(size = 6, angle = 90, vjust = 0.5))
  print(p_p1)
  ggsave(here::here("figures", paste0("pca_phase1_", ref_set, ".png")), p_p1,
         width = 9, height = 5, dpi = 150)
  message("Phase I: ", p1[remove == TRUE, .N], " batch(es) removed: ",
          paste(p1[remove == TRUE, batch], collapse = ", "),
          ". Re-run 10_ (re-check broken stick), then this script once more.")
} else {
  # Second pass on the refit model: report only, no new removals (refit once)
  message("Refit model: Phase I already applied; no further removals.")
  fwrite(p1, here::here("results", paste0("phase1_check_refit_", ref_set, ".csv")))
  fwrite(lim, here::here("results", paste0("pca_limits_", ref_set, ".csv")))
  saveRDS(X[, .(batch, t_grid, role, strategy, T2, Q)],
          here::here("data", "processed", paste0("pca_stats_", ref_set, ".rds")))
}