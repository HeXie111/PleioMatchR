# PleioMatchR
PleioMatchR matches pleiotropic variants across GWAS summary data for MR and comorbidity studies (TNBC &amp; T2D). Automates harmonization, SNP alignment, allele flipping and pleiotropy scoring. Produces visual diagnostics and clean outputs compatible with TwoSampleMR, MR-PRESSO and colocalization.

## 🎨 Built-in AI plotting-skill suite (feat/paper-plot-skills-upgrade)

This branch vendors the upgraded **paper-plot-skills v2** suite under
[`inst/skills/paper-plot-skills/`](inst/skills/paper-plot-skills/README.md) — 11
Codex/AI skills for academic figures, statistics-aware plotting and
journal-grade export. Highlights:

- Natural-language style search (`plot-style-search`) with a tagged catalog;
- layered figure parsing + reverse data estimation to CSV (`plot-from-image` v2);
- integrated statistics workflows (`plot-with-stats`: paired t-test, meta-analysis
  forest with I², DESeq2 volcano with BH-FDR);
- figure + supplementary-table in one command (`plot-with-table`), multi-panel
  assembly (`plot-panel`), CVD colour checks (`check-colorblind`),
  matplotlib ↔ seaborn ↔ ggplot2 ↔ origin-py transfer (`plot-style-transfer`),
  batch rcParams unification (`plot-batch-style`) and journal compliance checks
  (`plot-check-journal`, Nature/Cell/PLOS/BMJ/Lancet/...).

PleioMatchR integration: `x$locus_table` from `pleio_test()` maps directly to
the meta-analysis forest contract — see
[`data-contracts.md`](inst/skills/paper-plot-skills/data-contracts.md) and the
[`plotting-skills` vignette](vignettes/plotting-skills.Rmd).

> R package code is untouched by this feature; the suite ships as package data
> under `inst/` and is used by AI/agent workflows outside `R CMD check`.
