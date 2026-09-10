# PleioMatchR 0.2.0 (2026-09-09)

## AI plotting-skills suite (`inst/skills/paper-plot-skills`, v2)

* Vendored upgrade of paper-plot-skills: 11 Codex/AI skills for academic
  figures with tagged style catalog, colour-blind-safe palettes, layered
  figure parsing with reverse data estimation to CSV, LaTeX label conversion,
  cross-library style transfer (matplotlib / seaborn / ggplot2 / origin-py),
  batch rcParams unification and journal-compliance checking.
* Statistics-aware plotting: paired bar + paired t-test with significance
  stars, meta-analysis forest with fixed/random effects and I2, volcano +
  BH-FDR, Kaplan-Meier + log-rank.
* `plot-with-table` renders a figure and its supplementary table from one
  method-level CSV (TwoSampleMR `mr()` compatible).
* PleioMatchR linkage: `pmr_pleio` `locus_table` exports directly to the
  forest-meta contract (see `inst/skills/paper-plot-skills/data-contracts.md`
  and `vignettes/plotting-skills.Rmd`).

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
