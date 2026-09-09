\name{plot.pmr_pleio}
\alias{plot.pmr_pleio}
\title{Plot methods for `pmr_pleio` objects}
\usage{
\method{plot}{pmr_pleio}(x, which = c("butterfly", "null", "forest"), ...)
}
\arguments{
  \item{x}{A \code{pmr_pleio} object.}
  \item{which}{Which plot to draw: \code{"butterfly"} (default),
    \code{"null"} or \code{"forest"}.}
  \item{...}{Graphical parameters passed to underlying plotting calls.}
}
\value{Invisibly, \code{x}.}
\description{
Three diagnostic plots are available: \code{"null"} (permutation null
distribution of the enrichment index with the observed value marked),
\code{"forest"} (aligned per-locus outcome effects with 95\% confidence
intervals), and \code{"butterfly"} (two-panel diagnostic combining
enrichment with per-locus direction, including a heuristic PRS suitability
flag).
}
\examples{
data(demo_sentinels, package = "PleioMatchR")
data(demo_outcome, package = "PleioMatchR")
ctrl <- build_control_pool(demo_sentinels, demo_outcome, n_controls = 6,
                           seed = 42, verbose = FALSE)
res <- pleio_test(demo_sentinels, demo_outcome, controls = ctrl,
                  n_perm = 200, seed = 1, verbose = FALSE)
if (interactive()) plot(res, which = "null")
}
\seealso{\code{\link{pleio_test}}}
