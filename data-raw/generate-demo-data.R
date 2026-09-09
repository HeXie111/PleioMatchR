## Reproducible synthetic data used in examples, vignette and tests.
## The simulation mirrors the T2D -> breast-cancer setting described in the
## package paper: 30 exposure sentinels split into two pathway axes with
## opposite, internally consistent outcome directions, an outcome GWAS with
## genome-wide signal only at a subset of sentinel loci, and per-variant
## LD scores.
set.seed(20260908)

n_sent <- 30L
chr_sent <- rep(1:6, each = 5L)
pos_sent <- unlist(lapply(1:6, function(cc) {
  start <- 1e6 + (cc - 1L) * 8e6
  cumsum(c(start, rep(4e6, 4L))) + round(runif(5, -2e5, 2e5))
}))
ea <- sample(c("A", "C", "G", "T"), n_sent, replace = TRUE)
oa <- vapply(ea, function(a) {
  pool <- c("A", "C", "G", "T")
  pool <- setdiff(pool, a)
  pool[1L]
}, character(1))
oa[sample(seq_len(n_sent), round(n_sent * 0.15))] <- "T"
## ensure no accidental A/T or C/G pairs from the simple complement logic:
for (i in seq_len(n_sent)) {
  if (paste(sort(c(ea[i], oa[i])), collapse = "/") %in%
      c("A/T", "C/G")) oa[i] <- "G"
}
eaf_sent <- runif(n_sent, 0.05, 0.95)
pathway <- rep(c("obesity_axis", "islet_axis"), each = 15L)
## All exposure betas positive; outcome effects follow the axis.
beta_exp <- runif(n_sent, 0.05, 0.15)
se_exp <- runif(n_sent, 0.015, 0.03)
z_exp <- beta_exp / se_exp
p_exp <- 10^(-runif(n_sent, 9, 25))

demo_sentinels <- data.frame(
  snp = paste0("rsT2D", seq_len(n_sent)),
  chr = chr_sent, pos = pos_sent,
  ea = ea, oa = oa, eaf = eaf_sent,
  beta = beta_exp, se = se_exp, p = p_exp,
  pathway = pathway,
  stringsAsFactors = FALSE
)

## ---------------- outcome GWAS ---------------------------------------------
chr_all <- c(1:10)
variants <- lapply(chr_all, function(cc) {
  n_var <- if (cc <= 6L) 4000L else 3000L
  pos <- sort(sample(seq(1e5, 1.2e8, by = 100L), n_var))
  ea_v <- sample(c("A", "C", "G", "T"), n_var, replace = TRUE)
  oa_v <- vapply(ea_v, function(a) {
    pool <- c("A", "C", "G", "T")
    setdiff(pool, a)[1L]
  }, character(1))
  data.frame(
    snp = sprintf("rs%06d", seq_len(n_var) + cc * 1e5),
    chr = cc, pos = pos, ea = ea_v, oa = oa_v,
    stringsAsFactors = FALSE)
})
gwas <- do.call(rbind, variants)
rm(variants)

## MAF ~ U(0.02, 0.5) with a floor to keep matching feasible
gwas$maf <- runif(nrow(gwas), 0.03, 0.5)
gwas$eaf <- ifelse(runif(nrow(gwas)) < 0.5, gwas$maf, 1 - gwas$maf)
## outcome effect under the global null
gwas$beta <- rnorm(nrow(gwas), 0, 0.035)
gwas$se <- 0.035
gwas$p <- runif(nrow(gwas))
gwas$n <- 100000L

## Add sentinel rows to the outcome panel: exposure loci are present in the
## outcome GWAS with sub-threshold axis-consistent effects before the
## genome-wide-significant injection at the hit loci.
sent_rows <- data.frame(
  snp = demo_sentinels$snp,
  chr = demo_sentinels$chr,
  pos = demo_sentinels$pos,
  ea = demo_sentinels$ea,
  oa = demo_sentinels$oa,
  maf = pmin(demo_sentinels$eaf, 1 - demo_sentinels$eaf),
  eaf = demo_sentinels$eaf,
  beta = rep(NA_real_, n_sent),
  se = 0.035,
  p = rep(NA_real_, n_sent),
  n = 100000L,
  stringsAsFactors = FALSE)
gwas <- rbind(gwas, sent_rows)

## 10 hit sentinels per axis reach outcome genome-wide significance; the
## remaining sentinels carry weaker, still axis-consistent sub-threshold
## effects.  Outcome directions are perfectly consistent within each axis and
## opposite between axes, reproducing the "globally random, stratified
## consistent" scenario the package is designed to reveal.
axis_dir <- ifelse(demo_sentinels$pathway == "obesity_axis", 1, -1)
hit_loci <- c(1:10, 16:25)
z_out <- axis_dir * runif(n_sent, 3.5, 4.5)      ## sub-threshold, suggestive
z_out[hit_loci] <- axis_dir[hit_loci] * runif(length(hit_loci), 5.8, 7.5)
mi <- match(demo_sentinels$snp, gwas$snp)
gwas$beta[mi] <- z_out * gwas$se[mi]
gwas$p[mi] <- 2 * stats::pnorm(-abs(z_out))
demo_outcome <- gwas

## ---------------- LD scores ------------------------------------------------
ld <- data.frame(
  snp = demo_outcome$snp,
  ldscore = 1 +
    demo_outcome$chr * 0.8 +
    3 * demo_outcome$maf +
    rgamma(nrow(demo_outcome), shape = 2, rate = 1.4)
)
## keep some correlation structure: smooth over nearby positions is not
## needed for the demo; strata are quantiles within chromosome.
demo_ld_scores <- ld

save(demo_sentinels, file = "data/demo_sentinels.rda",
     compress = "xz", version = 3)
save(demo_outcome, file = "data/demo_outcome.rda",
     compress = "xz", version = 3)
save(demo_ld_scores, file = "data/demo_ld_scores.rda",
     compress = "xz", version = 3)
unlink("data/demo-data.rda")

## example PLINK clump output used by read_plink_clump() examples
dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)
cl <- demo_outcome[order(demo_outcome$chr, demo_outcome$pos), ]
cl <- cl[cl$p < 1e-5, ]
if (nrow(cl) < 3L) stop("need clump example rows")
cl <- cl[seq_len(min(nrow(cl), 5L)), ]
sp2 <- vapply(seq_len(nrow(cl)), function(i) {
  paste(sprintf("%s(1)", cl$snp[seq_len(2L)]), collapse = ",")
}, character(1))
clump_tab <- data.frame(
  CHR = cl$chr, F = "ADD", SNP = cl$snp, BP = cl$pos, P = cl$p,
  TOTAL = 5L, NSIG = 2L, S05 = "rs", S01 = "rs", S001 = "rs",
  S0001 = "rs", SP2 = sp2,
  check.names = FALSE, stringsAsFactors = FALSE)
write.table(clump_tab, file = "inst/extdata/example.clumped",
            sep = "\t", row.names = FALSE, quote = FALSE)

cat("Demo data written:",
    nrow(demo_sentinels), "sentinels;",
    nrow(demo_outcome), "outcome variants;",
    nrow(demo_ld_scores), "LD scores\n")
