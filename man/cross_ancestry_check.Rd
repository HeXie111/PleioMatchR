\name{cross_ancestry_check}
\alias{cross_ancestry_check}
\alias{pmr_ancestry}
\alias{print.pmr_ancestry}
\title{Cross-ancestry allele-frequency drift check}
\usage{
cross_ancestry_check(x, y, label_x = "population 1",
  label_y = "population 2", drift_threshold = 0.05,
  max_maf_ambiguous = 0.42, ...)

\method{print}{pmr_ancestry}(x, ...)
}
\arguments{
  \item{x, y}{Data.frames of summary statistics with an allele-frequency
    column (\code{eaf}/\code{maf}) and SNP identifier.}
  \item{label_x, label_y}{Ancestry/population labels for reporting.}
  \item{drift_threshold}{Absolute allele-frequency difference above which a
    variant is flagged as drifting (default 0.05).}
  \item{max_maf_ambiguous}{Palindromic variants with MAF above this value
    are flagged as strand-unreliable (default 0.42).}
  \item{...}{Reserved for future arguments.}
}
\value{
A \code{pmr_ancestry} list with \code{table} (per-variant drift and risk
flags), \code{summary}, \code{high_risk} (variants recommended for
exclusion), and \code{verdict} (human-readable text).
}
\description{
When exposure and outcome GWAS come from different ancestral populations,
effect-allele frequencies may drift and strand-ambiguous (palindromic)
variants become unreliable. The module quantifies allele-frequency drift
between two aligned tables and flags variants at risk. It is diagnostic
only: it does not correct LD-tag flipping or effect sizes.
}
\examples{
a <- data.frame(snp = c("rs1", "rs2"), ea = c("A", "C"), oa = c("G", "T"),
                eaf = c(0.45, 0.20), p = 1e-8)
b <- data.frame(snp = c("rs1", "rs2"), ea = c("A", "C"), oa = c("G", "T"),
                eaf = c(0.42, 0.55), p = 0.2)
cross_ancestry_check(a, b, label_x = "EAS", label_y = "EUR")
}
\seealso{\code{\link{harmonise_sumstats}}}
