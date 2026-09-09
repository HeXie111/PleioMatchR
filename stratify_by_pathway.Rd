\name{stratify_by_pathway}
\alias{stratify_by_pathway}
\alias{pmr_stratified}
\alias{print.pmr_stratified}
\title{Pathway-stratified pleiotropy diagnostics}
\usage{
stratify_by_pathway(x, annotation, min_loci = 2L, n_perm = 1000L,
  seed = NULL, ...)

\method{print}{pmr_stratified}(x, ...)
}
\arguments{
  \item{x}{A \code{pmr_pleio} object from \code{\link{pleio_test}}.}
  \item{annotation}{A named character vector (\code{snp = pathway}) or a
    data.frame with SNP and pathway columns.}
  \item{min_loci}{Minimum number of sentinel loci required to report a
    stratum (default 2).}
  \item{n_perm}{Permutations for the per-stratum enrichment p-value
    (default 1000).}
  \item{seed}{Random seed.}
  \item{...}{Reserved for future arguments.}
}
\value{
A \code{pmr_stratified} object: a list with \code{results} (one row per
pathway: enrichment index and p-value, direction counts, binomial p, WDC, I2
and Q p), \code{global} and \code{warnings}.
}
\description{
Re-runs enrichment and direction diagnostics within user-defined subgroups
of sentinel loci (e.g. "obesity axis" versus "islet axis" loci defined
through nearby-gene annotation). A global signal that looks directionally
random can hide two internally consistent subgroups with opposite
directions; stratification makes that structure explicit.
}
\examples{
data(demo_sentinels, package = "PleioMatchR")
data(demo_outcome, package = "PleioMatchR")
ctrl <- build_control_pool(demo_sentinels, demo_outcome, n_controls = 6,
                           seed = 42, verbose = FALSE)
res <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
                  n_perm = 200, seed = 1, verbose = FALSE)
annot <- data.frame(snp = demo_sentinels$snp,
                    pathway = demo_sentinels$pathway)
stratify_by_pathway(res, annot, n_perm = 100, seed = 1)
}
\seealso{\code{\link{pleio_test}}, \code{\link{direction_heterogeneity}}}
