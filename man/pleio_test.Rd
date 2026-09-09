\name{pleio_test}
\alias{pleio_test}
\alias{pmr_pleio}
\alias{print.pmr_pleio}
\alias{summary.pmr_pleio}
\title{Pleiotropy enrichment and direction test}
\usage{
pleio_test(sentinel, outcome, controls = NULL, p_threshold = 5e-08,
  window_kb = 500, n_perm = 10000L, direction_on = c("all", "hits"),
  control_args = list(), seed = NULL, verbose = TRUE, ...)

\method{print}{pmr_pleio}(x, ...)

\method{summary}{pmr_pleio}(object, ...)
}
\arguments{
  \item{sentinel}{Data.frame of exposure index variants.}
  \item{outcome}{Data.frame of outcome GWAS summary statistics.}
  \item{controls}{A \code{pmr_controls} object from
    \code{\link{build_control_pool}}, or \code{NULL} to build controls on
    the fly from \code{outcome} (see \code{control_args}).}
  \item{p_threshold}{Outcome p-value threshold defining a hit
    (default 5e-8).}
  \item{window_kb}{Half-width (kb) of the sentinel window used for hit
    calling and lead-variant extraction (default 500).}
  \item{n_perm}{Number of shared-control paired permutations
    (default 10000).}
  \item{direction_on}{Whether the direction test uses all sentinels with an
    alignable lead variant (\code{"all"}, default) or only sentinels whose
    window contains an outcome hit (\code{"hits"}).}
  \item{control_args}{Optional list of arguments passed to
    \code{\link{build_control_pool}} when \code{controls = NULL}.}
  \item{seed}{Random seed; \code{NULL} leaves the RNG state untouched.}
  \item{verbose}{Print a one-line summary.}
  \item{...}{Reserved for future arguments.}
  \item{x, object}{A \code{pmr_pleio} object.}
}
\value{
An object of class \code{pmr_pleio} with \code{enrichment} (EI, observed and
expected hits, empirical p-values, permutation CI), \code{direction} (test
summary), \code{heterogeneity} (weighted direction diagnostics from
\code{\link{direction_heterogeneity}}), \code{locus_table} (per-sentinel
detail), \code{permutation} (null EI vector), \code{sets} (per-sentinel
matched-set hit values), \code{controls} and \code{call}.
}
\description{
For a predefined set of exposure loci, tests whether these loci are enriched
for association with an outcome trait and whether their outcome effect
directions are consistent or random.

\strong{Enrichment.} A sentinel is a "hit" when the outcome GWAS contains at
least one variant with \code{p <= p_threshold} inside its
\code{+/- window_kb} window; matched controls receive identical windows and
thresholds. The enrichment index is observed over expected hits, and an
empirical p-value is obtained by randomly assigning the "case" label within
each sentinel-control matched set across \code{n_perm} permutations
(shared-control paired permutation).

\strong{Direction.} The lead outcome variant in each window is aligned to the
exposure effect allele; a two-sided exact binomial test evaluates whether
the proportion of positive aligned effects deviates from 0.5.
}
\examples{
data(demo_sentinels, package = "PleioMatchR")
data(demo_outcome, package = "PleioMatchR")
ctrl <- build_control_pool(demo_sentinels, demo_outcome,
                           n_controls = 8, seed = 42, verbose = FALSE)
res <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
                  n_perm = 500, seed = 1)
res
}
\seealso{\code{\link{build_control_pool}}, \code{\link{direction_heterogeneity}},
  \code{\link{stratify_by_pathway}}, \code{\link{plot.pmr_pleio}}}
