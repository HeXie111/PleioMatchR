\name{direction_heterogeneity}
\alias{direction_heterogeneity}
\title{Weighted direction consistency and effect-size heterogeneity}
\usage{
direction_heterogeneity(beta, se, method = c("both", "I2", "WDC"),
  n_perm = 9999L, seed = NULL, ...)
}
\arguments{
  \item{beta}{Numeric vector of aligned effect sizes.}
  \item{se}{Numeric vector of standard errors (same length as \code{beta},
    strictly positive).}
  \item{method}{One of \code{"both"}, \code{"I2"} or \code{"WDC"}.}
  \item{n_perm}{Number of sign-flip permutations for the WDC null
    distribution (default 9999).}
  \item{seed}{Random seed for WDC permutation.}
  \item{...}{Reserved for future arguments.}
}
\value{
A list with \code{n}, \code{mean_effect}, \code{WDC} and \code{wdc_p}
(two-sided sign-flip p-value), \code{Q}, \code{Q_df}, \code{Q_p},
\code{tau2}, \code{I2}, and a note that these statistics are descriptive and
should be calibrated by simulation before use as formal tests.
}
\description{
For aligned outcome effect estimates (one per locus), computes the
precision-weighted direction consistency (\code{WDC}, centred on 0 under
random orientations and approaching +/-1 under perfect consistency) and the
Cochran Q / DerSimonian-Laird tau-squared / I2 heterogeneity statistics from
a random-effects meta-analysis. High I2 indicates per-locus effects that
cannot be pooled into a single cross-trait effect.
}
\examples{
set.seed(1)
direction_heterogeneity(rnorm(20, 0.05, 0.05), rep(0.02, 20), n_perm = 999)
}
\seealso{\code{\link{pleio_test}}}
