\name{build_control_pool}
\alias{build_control_pool}
\alias{pmr_controls}
\alias{print.pmr_controls}
\alias{summary.pmr_controls}
\title{Build a matched control pool for pleiotropy enrichment testing}
\usage{
build_control_pool(sentinel, pool, n_controls = 10L, maf_tol = 0.03,
  min_dist = 5e+05, exclude_p = 5e-08, ld_scores = NULL,
  ldscore_strata = 5L, seed = 1L, verbose = TRUE, ...)

\method{print}{pmr_controls}(x, ...)

\method{summary}{pmr_controls}(object, ...)
}
\arguments{
  \item{sentinel}{Data.frame of exposure index variants (see
    \code{\link{import_sumstats}} for accepted columns).}
  \item{pool}{Data.frame of variants from which controls are sampled
    (typically the outcome GWAS).}
  \item{n_controls}{Number of controls per sentinel (default 10).}
  \item{maf_tol}{Absolute MAF tolerance for matching (default 0.03).}
  \item{min_dist}{Minimum physical distance (bp) between a sentinel and its
    controls (default 5e5, i.e. 500 kb).}
  \item{exclude_p}{Outcome p-value threshold below which pool variants are
    excluded from serving as controls (default 5e-8). Set to \code{NULL} to
    disable.}
  \item{ld_scores}{Optional data.frame with a SNP identifier column and an
    LD-score column (\code{ldscore}, \code{score} or \code{l2}).}
  \item{ldscore_strata}{Number of LD-score quantile strata per chromosome
    (default 5).}
  \item{seed}{Random seed for reproducible sampling.}
  \item{verbose}{Print a short matching summary.}
  \item{...}{Reserved for future arguments.}
  \item{x, object}{A \code{pmr_controls} object.}
}
\value{
A \code{pmr_controls} object: a list with \code{sentinel} (canonical
sentinel table), \code{controls} (one row per matched variant, with
\code{sentinel_id}, \code{dist_sentinel}, \code{maf_diff},
\code{ldscore_diff} and \code{stratum}), \code{diagnostics} (per-sentinel
coverage/balance and notes) and \code{call}.
}
\description{
For each sentinel locus, samples matched "null" variants from a reference
pool (usually the outcome GWAS) using genome-aware criteria: same
chromosome, MAF tolerance, physical distance \code{> min_dist} from the
sentinel, and exclusion of outcome genome-wide-significant variants. When
\code{ld_scores} are supplied, controls are additionally required to fall in
the same within-chromosome LD-score stratum as the sentinel, making case and
control variant sets comparable in local LD density (a proxy for genomic
background polygenicity).
}
\examples{
set.seed(1)
sent <- data.frame(snp = paste0("rs", 1:5), chr = 1,
                   pos = seq(1e6, 9e6, 2e6), ea = "A", oa = "G",
                   eaf = runif(5, 0.2, 0.8), beta = rnorm(5), se = 0.05,
                   p = 1e-10)
pool <- data.frame(snp = paste0("g", 1:5000), chr = 1,
                   pos = seq(1e4, 1e8, length.out = 5000),
                   ea = sample(c("A", "C"), 5000, TRUE),
                   oa = sample(c("G", "T"), 5000, TRUE),
                   eaf = runif(5000), beta = rnorm(5000), se = 0.05,
                   p = runif(5000))
ctrl <- build_control_pool(sent, pool, n_controls = 8, seed = 42)
ctrl
}
\seealso{\code{\link{pleio_test}}, \code{\link{stratify_by_pathway}}}
