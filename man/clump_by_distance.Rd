\name{clump_by_distance}
\alias{clump_by_distance}
\title{Greedy distance-based LD clumping}
\usage{
clump_by_distance(snp, chr, pos, p = NULL, kb = 500)
}
\arguments{
  \item{snp}{Character vector of variant identifiers.}
  \item{chr, pos}{Genomic coordinates.}
  \item{p}{Optional p-values used for ranking (lower = higher priority).}
  \item{kb}{Window size in kb (default 500).}
}
\value{
A data.frame with input columns plus \code{clump_id} (integer) and
\code{keep} (logical: \code{TRUE} for the index variant of each clump).
}
\description{
A dependency-free proxy for LD clumping that keeps, per \code{kb} window, the
variant with the smallest p-value (or, if p is missing, the first variant in
input order). For real data prefer PLINK \code{--clump} on a matched
reference panel; this function is intended for quick data cleaning and
reproducible examples.
}
\examples{
d <- data.frame(snp = paste0("s", 1:6), chr = 1,
                pos = c(100, 200, 800, 1200, 4000, 4300),
                p = c(0.5, 1e-8, 0.01, 0.9, 1e-6, 0.3))
clump_by_distance(d$snp, d$chr, d$pos, d$p, kb = 500)
}
\seealso{\code{\link{read_plink_clump}}}
