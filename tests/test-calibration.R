## Simulation calibration of the shared-control paired permutation:
## (a) type-I error: p-values must look Uniform(0,1) under exchangeable
##     case/control hit probabilities;
## (b) power: strong case-side enrichment must give p below 0.05.
library(PleioMatchR)

make_grid <- function(n_sent = 12L, per_ctrl = 6L) {
  ## One outcome/pool variant per position. Sentinel rows and 6 decoy rows
  ## per sentinel are spaced so that no window contains more than one row.
  pos_sent <- seq(2e6, by = 3e6, length.out = n_sent)
  pos_ctrl <- as.vector(vapply(pos_sent, function(pp) {
    pp + c(0.7, 1.0, 1.5, 2.0, 2.5, 2.7) * 1e6
  }, numeric(per_ctrl)))
  rows <- rbind(
    data.frame(snp = paste0("s", seq_len(n_sent)), chr = 1L,
               pos = pos_sent, stringsAsFactors = FALSE),
    data.frame(snp = paste0("d", seq_along(pos_ctrl)), chr = 1L,
               pos = pos_ctrl, stringsAsFactors = FALSE))
  rows$ea <- sample(c("A", "C", "G", "T"), nrow(rows), replace = TRUE)
  rows$oa <- sample(c("A", "C", "G", "T"), nrow(rows), replace = TRUE)
  rows$eaf <- runif(nrow(rows), 0.1, 0.9)
  rows$se <- 0.035
  rows
}

sentinels <- function(rows, n_sent = 12L) {
  data.frame(snp = paste0("s", seq_len(n_sent)), chr = 1L,
             pos = seq(2e6, by = 3e6, length.out = n_sent),
             ea = rows$ea[seq_len(n_sent)],
             oa = rows$oa[seq_len(n_sent)],
             eaf = rows$eaf[seq_len(n_sent)],
             beta = 0.1, se = 0.03, p = 1e-10,
             stringsAsFactors = FALSE)
}

set.seed(20260908)
## Type I error: p-values from 20 null simulations ----------------------------
pvals <- numeric(20)
for (sim in seq_len(20)) {
  rows <- make_grid(12L, 6L)
  rows$p <- runif(nrow(rows), 0, 0.06)     ## no case enrichment
  sent <- sentinels(rows)
  ctrl <- build_control_pool(sent, rows, n_controls = 6L,
                             maf_tol = 0.5, seed = sim, verbose = FALSE)
  r <- pleio_test(sent, rows, controls = ctrl, p_threshold = 0.03,
                  window_kb = 100, n_perm = 199L, seed = sim,
                  verbose = FALSE)
  pvals[sim] <- r$enrichment$p_upper
}
cat("null mean p:", mean(pvals), "\n")
stopifnot(mean(pvals) > 0.2, mean(pvals) < 0.8,
          sum(pvals < 0.05) <= 3)

## Power: sentinel rows driven below threshold ---------------------------------
p_power <- numeric(10)
for (sim in seq_len(10)) {
  rows <- make_grid(12L, 6L)
  rows$p <- runif(nrow(rows), 0, 0.06)
  rows$p[seq_len(12L)] <- 1e-9
  sent <- sentinels(rows)
  ctrl <- build_control_pool(sent, rows, n_controls = 6L,
                             maf_tol = 0.5, seed = sim, verbose = FALSE)
  r <- pleio_test(sent, rows, controls = ctrl, p_threshold = 0.03,
                  window_kb = 100, n_perm = 199L, seed = sim,
                  verbose = FALSE)
  p_power[sim] <- r$enrichment$p_upper
}
cat("power p-values:", paste(p_power, collapse = ", "), "\n")
stopifnot(all(p_power < 0.05))
cat("test-calibration.R: type-I-error and power sanity checks passed\n")
