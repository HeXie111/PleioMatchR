#!/usr/bin/env Rscript
# DESeq2 differential-expression runner for the volcano pipeline.
#
# Usage:
#   Rscript volcano_deseq2.R counts.csv design.csv de_table.csv
#
#   counts.csv : rows = genes, columns = samples (first column = gene id)
#   design.csv : columns `sample`, `group` (exactly two group levels)
#
# Output columns follow the volcano_de.py contract:
#   gene, baseMean, log2FoldChange, lfcSE, stat, pvalue, padj

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) {
  stop("usage: Rscript volcano_deseq2.R counts.csv design.csv de_table.csv")
}
counts_file <- args[1L]
design_file <- args[2L]
out_file <- args[3L]

if (!requireNamespace("DESeq2", quietly = TRUE)) {
  stop("DESeq2 is not installed; run BiocManager::install('DESeq2') first")
}
if (!requireNamespace("utils", quietly = TRUE)) {
  stop("utils is required")
}

counts <- utils::read.csv(counts_file, row.names = 1L, check.names = FALSE)
design <- utils::read.csv(design_file)
design$sample <- as.character(design$sample)
design$group <- factor(design$group)
if (nlevels(design$group) != 2L) {
  stop("design must contain exactly two group levels")
}
design <- design[match(colnames(counts), design$sample), , drop = FALSE]
if (any(is.na(design$group))) {
  stop("counts columns and design$sample must match")
}

dds <- DESeq2::DESeqDataSetFromMatrix(
  countData = counts,
  colData = design,
  design = ~group
)
dds <- DESeq2::DESeq(dds, quiet = TRUE)
res <- DESeq2::results(dds, contrast = c("group", levels(design$group)[2L], levels(design$group)[1L]))

out <- data.frame(
  gene = rownames(res),
  baseMean = res$baseMean,
  log2FoldChange = res$log2FoldChange,
  lfcSE = res$lfcSE,
  stat = res$stat,
  pvalue = res$pvalue,
  padj = res$padj,
  row.names = NULL
)
utils::write.csv(out, out_file, row.names = FALSE)
message(sprintf("DESeq2 results written to %s", out_file))
