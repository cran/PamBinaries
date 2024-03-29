% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dateNumToMillis.R
\name{dateNumToMillis}
\alias{dateNumToMillis}
\title{Convert Date Number to Milliseconds}
\usage{
dateNumToMillis(datenum)
}
\arguments{
\item{datenum}{Numeric value of a date.}
}
\value{
Date as milliseconds
}
\description{
Converts numeric date to millisecond date.
}
\note{
Conversion to milliseconds to match how Java stores
  dates. Doesn't appear to ever be used.
}
\author{
Taiki Sakai \email{taiki.sakai@noaa.gov}
}
