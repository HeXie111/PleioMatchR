\name{harmonise_sumstats}
\alias{harmonise_sumstats}
\alias{pmr_harmonised}
\title{Harmonise two summary-statistics tables by allele alignment}
\usage{
harmonise_sumstats(x, y, max_maf_ambiguous = 0.42, maf_tol = 0.08,
  action = c("drop_ambiguous", "keep_ambiguous"))
}
\arguments{
  \item{x, y}{Objects of class \code{pmr_sumstats} (or data.frames accepted
    by \code{\link{import_sumstats}}).}
  \item{max_maf_ambiguous}{Palindromic variants with MAF above this value
    are considered strand-ambiguous and dropped (default 0.42).}
  \item{maf_tol}{Tolerance for declaring palindromic MAF values concordant.}
  \item{action}{One of \code{"drop_ambiguous"} (default) or
    \code{"keep_ambiguous"}.}
}
\value{
A list of class \code{pmr_harmonised} with elements \code{x}, \code{y}
(harmonised and row-aligned), \code{dropped}, \code{report} (counts) and
\code{call}.
}
\description{
Aligns the effect allele of \code{y} to that of \code{x} so effect sizes are
directly comparable. Matching is on \code{snp} when available and on
\code{chr:pos} otherwise. Non-palindromic allele mismatches are dropped;
palindromic (A/T, C/G) variants are kept when MAF is informative
(\code{<= max_maf_ambiguous}) and dropped otherwise, mirroring common
\pkg{TwoSampleMR} practice.
}
\examples{
x <- data.frame(snp = c("rs1", "rs2"), ea = c("A", "C"), oa = c("G", "T"),
                beta = c(0.2, -0.1), se = c(0.03, 0.04),
                p = c(1e-8, 1e-3), eaf = c(0.4, 0.6))
y <- data.frame(SNP = c("rs1", "rs2"), EA = c("G", "T"), OA = c("A", "C"),
                BETA = c(0.25, 0.05), SE = c(0.03, 0.04),
                P = c(1e-9, 0.01), EAF = c(0.6, 0.4))
h <- harmonise_sumstats(x, y)
h$report
}
