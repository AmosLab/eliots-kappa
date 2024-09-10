##' load filename to table, parsing requested date columns
##'
##' fname is expected to be a valid pathname to a text file containing the data.
##' delimiter is passed to [utils::read.table] as 'sep'.
##' quoteChar is passed to [utils::read.table] as 'quote'.
##' colTypes is passed to [utils::read.table] as 'colClasses'.
##' dateFmt expects a string corresponding to a [lubridate] parsing function.
##' parseDates argument expects a logical array of length equal to columns of data in fname.
##'
##' With defaults, expects a CSV file with three columns (no header):
##'   Col 1: start time (numeric) = MM.SS
##'   Col 2: stop  time (numeric) = MM.SS
##'   Col 3: code  tag  (string ) = someCode
##'
##' Returns:
##'   Table with first two columns converted to lubridate time objects and codes.
##' @export
load_from_file <- function(fname, header=FALSE, delimiter=",", quoteChar="\"", colTypes=c("character", "character", "character", "character"), parseDates=c(T,T,F,F), dateFmt="ms") {
  tabl <- utils::read.table(fname, header=header, sep=delimiter, colClasses=colTypes, quote=quoteChar)
  # fill missing end times from left with T(colfill(T(data)))
  tabl <- t(zoo::na.locf(t(tabl)))
  # select appropriate parser format
  dataparser <-
    if (dateFmt == "ms") lubridate::ms else
    if (dateFmt == "hms") lubridate::hms else
    if (dateFmt == "hm") lubridate::hm else
    if (dateFmt == "ymd") lubridate::ymd else
    if (dateFmt == "mdy") lubridate::mdy else
    if (dateFmt == "my") lubridate::my else
    if (dateFmt == "ymd_hms") lubridate::ymd_hms else
    if (dateFmt == "mdy_hms") lubridate::ymd_hms else
      warning("Format not recognized; defaulting to 'as_hms'. Choose from: ms, hms, hm, ymd, mdy, my, ymd_hms, mdy_hms.")
      lubridate::hms
  tabl[,parseDates] <- apply(tabl[,parseDates], 2, function(d) as.character(lubridate::as_date(dataparser(d))))
  return(data.frame(tabl))
}

