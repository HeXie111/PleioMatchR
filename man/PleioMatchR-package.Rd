\name{PleioMatchR-package}
\alias{PleioMatchR}
\alias{PleioMatchR-package}
\docType{package}
\title{Diagnostic Tools for Cross-Trait GWAS Sharing}
\description{
PleioMatchR is a matched-control, permutation-based framework for
diagnosing whether a predefined set of trait-associated loci shows
association enrichment, consistent effect direction, or
pathway-stratified sharing in a second GWAS. It is designed as a
\emph{diagnostic toolbox} rather than an instrumental-variable causal
estimation package: every result is association-level evidence, and the
package never reports causal conclusions.
}
\details{
The main workflow is:
\enumerate{
  \item Import and harmonise summary statistics with
    \code{\link{import_sumstats}} and \code{\link{harmonise_sumstats}}.
  \item Build a genome-aware matched control pool with
    \code{\link{build_control_pool}} (same chromosome, MAF tolerance,
    physical-distance buffer, exclusion of outcome-significant variants,
    and optional LD-score stratified matching).
  \item Run the shared-control paired permutation enrichment test and the
    sign-flip direction test with \code{\link{pleio_test}}.
  \item Stratify by pathway/annotation with
    \code{\link{stratify_by_pathway}}, inspect effect-direction
    heterogeneity with \code{\link{direction_heterogeneity}}, check
    cross-ancestry allele-frequency drift with
    \code{\link{cross_ancestry_check}}, and visualise with
    \code{\link{plot.pmr_pleio}}.
}
}
\author{
PleioMatchR developers.
}
\keyword{package}
