## Functional tests of the core PleioMatchR workflow.
library(PleioMatchR)

data(demo_sentinels, package = "PleioMatchR")
data(demo_outcome, package = "PleioMatchR")
data(demo_ld_scores, package = "PleioMatchR")

## 1. import / canonicalisation -----------------------------------------------
s <- import_sumstats(demo_sentinels)
stopifnot(inherits(s, "pmr_sumstats"), nrow(s) == 30L,
          all(c("snp", "chr", "pos", "ea", "oa", "beta", "se", "p",
                "eaf", "maf") %in% names(s)))

## 2. harmonisation ------------------------------------------------------------
y <- demo_outcome[match(demo_sentinels$snp[1:20], demo_outcome$snp), ]
y$beta <- -y$beta
y$eaf <- 1 - y$eaf
nms <- names(y)
nms[nms == "ea"] <- ".tmp_ea"; nms[nms == "oa"] <- "ea"
nms[nms == ".tmp_ea"] <- "oa"
names(y) <- nms
h <- harmonise_sumstats(s[1:20, ], y)
stopifnot(h$report[["harmonised"]] == 20L)

## 3. control pool with LD-score stratification --------------------------------
ctrl <- build_control_pool(demo_sentinels, demo_outcome, n_controls = 8,
                           ld_scores = demo_ld_scores, seed = 42,
                           verbose = FALSE)
stopifnot(inherits(ctrl, "pmr_controls"),
          nrow(ctrl$controls) == 240L,
          ctrl$diagnostics$ld_stratified,
          ctrl$diagnostics$balance[["coverage"]] == 1,
          mean(abs(ctrl$controls$maf_diff)) <= 0.03)

## 4. enrichment + direction ----------------------------------------------------
res <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
                  n_perm = 500, seed = 1, verbose = FALSE)
stopifnot(inherits(res, "pmr_pleio"),
          res$enrichment$hits_observed == 20L,
          res$enrichment$enrichment_index > 5,
          res$enrichment$p_upper < 0.01,
          res$direction$n_directional == 30L,
          res$direction$n_positive == 15L,
          is.finite(res$heterogeneity$I2))

res_hits <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
                       n_perm = 200, direction_on = "hits", seed = 1,
                       verbose = FALSE)
stopifnot(res_hits$direction$n_directional == 20L,
          res_hits$direction$n_positive == 10L)

## 5. stratification -------------------------------------------------------------
annot <- data.frame(snp = demo_sentinels$snp,
                    pathway = demo_sentinels$pathway)
st <- stratify_by_pathway(res_hits, annot, n_perm = 200, seed = 2)
stopifnot(inherits(st, "pmr_stratified"),
          nrow(st$results) == 2L,
          all(abs(st$results$WDC) > 0.9),
          all(st$results$binom_p < 0.01))

## 6. ancestry ------------------------------------------------------------------
a <- demo_sentinels[1:10, c("snp", "ea", "oa", "eaf")]
b <- a
b$eaf <- a$eaf + runif(10, -0.02, 0.02)
b$eaf[1] <- 0.55
ac <- cross_ancestry_check(a, b, label_x = "EAS", label_y = "EUR")
stopifnot(inherits(ac, "pmr_ancestry"), nrow(ac$table) == 10L)

## 7. plink clump ---------------------------------------------------------------
f <- system.file("extdata", "example.clumped", package = "PleioMatchR")
if (nzchar(f)) {
  cl <- read_plink_clump(f)
  stopifnot(nrow(cl) >= 1L, all(c("chr", "index_snp", "bp", "p",
                                  "n_sp2") %in% names(cl)))
}
cd <- clump_by_distance(c("a", "b", "c"), c(1, 1, 1),
                        c(100, 900, 3e5), p = c(0.5, 1e-8, 1e-9),
                        kb = 500)
stopifnot(sum(cd$keep) == 2L)

cat("test-core.R: all assertions passed\n")
