\name{import_sumstats}
\alias{import_sumstats}
\alias{pmr_sumstats}
\title{Import and canonicalise GWAS summary statistics}
\usage{
import_sumstats(x, ...)
}
\arguments{
  \item{x}{A data.frame of summary statistics, or a path to a plain-text
    (optionally \file{.gz}-compressed) file with a header row.}
  \item{...}{Reserved for future arguments.}
}
\value{
A data.frame with class \code{c("pmr_sumstats", "data.frame")} and canonical
columns \code{snp}, \code{chr}, \code{pos}, \code{ea}, \code{oa},
\code{beta}, \code{se}, \code{p}, \code{eaf}, \code{maf}, \code{n}.
}
\description{
The standard entry point for GWAS summary statistics in PleioMatchR. Column
names used by the GWAS literature and by \pkg{TwoSampleMR} (e.g.
\code{SNP}, \code{effect_allele}, \code{other_allele}, \code{beta},
\code{se}, \code{pval}, \code{eaf}, \code{chr}, \code{pos}) are recognised
automatically. Allele frequencies are interpreted as the frequency of the
effect allele.
}
\examples{
x <- data.frame(SNP = c("rs1", "rs2"), chr = c(1, 1), pos = c(1000, 9000),
                EA = c("A", "C"), OA = c("G", "T"), beta = c(0.1, -0.2),
                se = c(0.03, 0.04), p = c(0.001, 0.01),
                eaf = c(0.4, 0.6))
str(import_sumstats(x))
}
