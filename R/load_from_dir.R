##' Function to load each file from a directory.
##'
##' dirpath expects a valid path to a directory, default is current directory.
##' pat expects a valid search pattern, default is '*.csv$'
##' NOTE: adding '$' to end prevents catching '.bak' files.
##' returns a data.frame of all cases from requested directory.
##' Also accepts arguments to be passed to [load_from_file].
load_from_dir <- function(dirpath=".", pat="*.csv$", header=FALSE, delimiter=",", quoteChar="\"", colTypes=c("numeric", "numeric", "character", "character"), parseDates=c(T,T,F,F), dateFmt="ms") {

  if(!dir.exists(dirpath)) {
      stop(paste("Could not find directory: ", dirpath, sep=""))
  }

  files <- list.files(dirpath, pattern=pat)
  if(length(files) < 1){
    stop(paste("Could not find file(s) at location: ", dirpath, sep=""))
  }
  all_data <- data.frame(matrix(ncol=2, nrow=0))
  colnames(all_data) <- c("fname", "codes")
  for (f in files){
    print(f)
    d <- load_from_file(file.path(dirpath,f), header=header, delimiter=delimiter, quoteChar=quoteChar, colTypes=colTypes, parseDates=parseDates, dateFmt=dateFmt)
    all_data <- rbind(all_data, data.frame(fname=f, codes=d))
  }
  return(all_data)
}
