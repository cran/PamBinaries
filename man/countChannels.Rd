% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/countChannels.R
\name{countChannels}
\alias{countChannels}
\title{Count Number of Active Channels}
\usage{
countChannels(channelMap)
}
\arguments{
\item{channelMap}{Mapping of channels as a binary number}
}
\value{
The number of active channels (number of ones)
}
\description{
Counts the number of active channels
  given a channel mapping
}
\note{
Altered from original script to loop through 30 instead
  32 because R stores only 32 bit integers. Should not ever have
  enough channels for this to matter.
}
\author{
Taiki Sakai \email{taiki.sakai@noaa.gov}
}
