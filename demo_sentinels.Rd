\name{demo_sentinels}
\alias{demo_sentinels}
\alias{demo_outcome}
\alias{demo_ld_scores}
\docType{data}
\title{Synthetic T2D-to-breast-cancer style demonstration data}
\usage{
data(demo_sentinels)
data(demo_outcome)
data(demo_ld_scores)
}
\format{
\code{demo_sentinels}: a data.frame of 30 exposure index variants
(\code{snp}, \code{chr}, \code{pos}, \code{ea}, \code{oa}, \code{eaf},
\code{beta}, \code{se}, \code{p}, \code{pathway}) split into an
\code{"obesity_axis"} and an \code{"islet_axis"} (15 loci each).

\code{demo_outcome}: an outcome GWAS with 36,030 variants on chromosomes
1-10 (\code{snp}, \code{chr}, \code{pos}, \code{ea}, \code{oa},
\code{maf}, \code{eaf}, \code{beta}, \code{se}, \code{p}, \code{n}).
Ten sentinels per axis reach outcome genome-wide significance; the
remaining sentinels carry weaker axis-consistent effects. Outcome
directions are perfectly consistent within each axis and opposite between
axes.

\code{demo_ld_scores}: per-variant LD scores (\code{snp}, \code{ldscore})
for LD-score stratified matching.
}
\description{
Synthetic data mirroring the East-Asian T2D-to-breast-cancer analysis
described in the package paper: global enrichment is present, global
direction looks random, and direction becomes perfectly consistent after
pathway stratification. The data are fully simulated and are provided only
for examples, tests and vignettes.
}
\keyword{datasets}
