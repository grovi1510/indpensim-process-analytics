library(data.table)
set.seed(20261031)

disturbed <- c(6, 18, 27, 32, 42, 44, 64, 68, 70, 89, 100)

split <- data.table(batch = 1:100)
split[, strategy := fcase(batch <= 30, "recipe",
                          batch <= 60, "operator",
                          batch <= 90, "apc_raman",
                          default = "fault")]
split[, disturbance_90h := batch %in% disturbed]
split[, role := fcase(strategy == "fault", "test_fault",
                      disturbance_90h,     "test_disturbance",
                      default = NA_character_)]
split[is.na(role), role := {
  r <- rep("train", .N); r[sample(.N, round(.N / 3))] <- "test"; r
}, by = strategy]

split[, .N, by = .(strategy, role)][order(strategy, role)]  # sanity check

dir.create(here::here("splits"), showWarnings = FALSE)
fwrite(split, here::here("splits", "batch_split.csv"))