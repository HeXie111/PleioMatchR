# PleioMatchR 0.1.0 (2026-09-08)

## MVP release

* `import_sumstats()`: canonical import of GWAS summary statistics with
  `TwoSampleMR`-style column aliases and a `pmr_sumstats` S3 class.
* `harmonise_sumstats()`: allele-aware harmonisation with palindromic
  variant handling.
* `build_control_pool()`: genome-aware matched control pool (chromosome,
  MAF tolerance, physical-distance buffer, outcome-significant exclusion),
  with optional within-chromosome LD-score stratified matching and
  per-sentinel balance diagnostics.
* `pleio_test()`: shared-control paired permutation enrichment test
  (enrichment index, empirical one/two-sided p-values, MC standard error,
  permutation CI) plus a two-sided exact sign-flip direction test.
* `direction_heterogeneity()`: precision-weighted direction consistency
  (WDC) with sign-flip p-value and random-effects Q/tau2/I2 diagnostics
  (descriptive; simulation calibration required for formal use).
* `stratify_by_pathway()`: per-pathway enrichment and direction tests that
  reveal internally consistent subgroups with opposite directions.
* `cross_ancestry_check()`: allele-frequency drift and strand-ambiguity
  diagnostics between ancestries (diagnostic only).
* `read_plink_clump()` and `clump_by_distance()`: PLINK clump parsing and a
  dependency-free greedy distance clumper.
* `plot.pmr_pleio()`: null-distribution, forest, and "butterfly"
  (enrichment + direction + PRS-suitability flag) plots.
* Simulated T2D-to-breast-cancer style demo data, vignette, and
  type-I-error/power calibration tests.
