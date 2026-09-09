\name{read_plink_clump}
\alias{read_plink_clump}
\title{Read a PLINK `--clump` output file}
\usage{
read_plink_clump(file, ...)
}
\arguments{
  \item{file}{Path to a \file{.clumped} file produced by PLINK 1.9
    \code{--clump}.}
  \item{...}{Passed to \code{\link[utils]{read.table}}.}
}
\value{
A data.frame with columns \code{chr}, \code{index_snp}, \code{bp},
\code{p}, \code{n_total}, \code{n_sig}, \code{sp2_snps} and \code{n_sp2}.
}
\description{
Parses a \file{.clumped} file produced by PLINK 1.9 (\code{--clump}) into a
tidy data.frame, returning index variants and the variants listed in the
\code{SP2} column.
}
\examples{
f <- system.file("extdata", "example.clumped", package = "PleioMatchR")
if (nzchar(f)) read_plink_clump(f)
}
\seealso{\code{\link{clump_by_distance}}}
