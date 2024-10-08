## Global vars
## These hold data across multiple/all cases loaded

# This hash acts like a lookup to convert codes to unique numerical ID
# Initialize empty as global, or user can hardcode values like example below.
code2num <- hash::hash()

# code2num_fixed <- hash::hash(keys=c("orienting", "3d manipulation",
#                                     "tool usage", "feature",
#                                     "reviewing", "excitement",
#                                     "frustration", "confidence",
#                                     "mental model", "planning",
#                                     "path finding", "confirmation",
#                                     "team dynamics", "risk",
#                                     "limitation", "uncertainty",
#                                     "anatomy"),
#                              values=c(1,4,5,2,3,7,8,9,10,11,12,13,14,15,16,17,6))


# string replacements to be made for code densification.
# List of vector pairs of strings, where the first string will be replaced with the second.
# If left like this, code will detect the wrong size (should be 2*n)
# and load the list from file. User can hardcode as well, as in example below.
replacements <- list("load")

# replacements <- list(c("anatomy landmark", "anatomy"),
#                      c("[-–—]", ""),
#                      c("intrigue", "excitement"),
#                      c("disappointment", "frustration"),
#                      c("investigating", "anatomy"),
#                      c("examining", "anatomy"))


# Reads in a csv with codes (column 1) mapped to unique integers (column 2).
# Loads data.frame to hash.
load_codekeys <- function(path=".", delimiter=",", quoteChar="\"", header=FALSE){
  codekeys <- read.csv(path, header=header, sep=delimiter, quote=quoteChar)
  code2num <- hash::hash()
  for(row in 1:nrow(codekeys)){
    code2num[[as.character(codekeys[row,1])]] <- as.integer(codekeys[row,2])
  }
  return(code2num)
}

# Reads in a csv with column 1 = search term, column 2 = replace term.
# Coverts data.frame to list of vectors for simplicity later.
load_replacements <- function(path=".", delimiter=",", quoteChar="\"", header=FALSE){
  to_replace <- read.csv(path, header=header, sep=delimiter, quote=quoteChar)
  replacements <- vector("list", nrow(to_replace))
  for(row in 1:nrow(to_replace)){
    replacements[[row]] <- c(to_replace[row,1], to_replace[row,2])
  }
  return(replacements)
}



preprocess_case <- function(caseDirPath=".", relReplacementPath="/../replacements.csv", relCodekeyPath="/../codekeys.csv", startCol=1, endCol=2, codeCol=4, pat="*.csv$", header=FALSE, delimiter=",", quoteChar="\"", colTypes=c("numeric", "numeric", "character", "character"), parseDates=c(T,T,F,F), dateFmt="ms"){

  case <- load_from_dir(caseDirPath,
                        pat=pat,
                        header=header,
                        delimiter=delimiter,
                        quoteChar=quoteChar,
                        colTypes=colTypes,
                        parseDates=parseDates,
                        dateFmt=dateFmt)

  # In load_from_dir we added a column at the beginning for the filename.
  codeloc <- colnames(case)[codeCol+1]
  startloc <- colnames(case)[startCol+1]
  endloc <- colnames(case)[endCol+1]

  # Lowercase codestr, trim leading and trailing white space
  case[[codeloc]] <- tolower(trimws(case[[codeloc]]))

  # We need a user defined mapping of codes to numbers. If not hardcoded,
  # load it from file
  if (length(code2num) < 1){
    tryCatch({code2num <- load_codekeys(paste(caseDirPath, relCodekeyPath, sep=""))},
             error = function(cond) {
                warning("Failed to load codekeys.csv.
                        Defaulting to building map from single case.
                        THIS MEANS EACH CASE MAY HAVE DIFFERENT VALUES FOR THE SAME CODE!")

               codecount <- 1
                # if failed to load from file, build map from single case
                for (el in unique(case[[codeloc]])){
                  code2num[[el]] <- codecount
                  codecount <- length(code2num) + 1
                }
              })
  }

  # If the user wants to clean up codes/condense codes. If not hardcoded,
  # load it from file. Should always be even length (search,replace), or len = 0
  if (length(replacements[[1]]) == 1){
    try(replacements <- load_replacements(paste(caseDirPath,
                                                relReplacementPath, sep="")),
        silent=TRUE)
  }


  # make substitutions if required
  if (length(replacements[[1]]) > 1) {
    for (each in replacements){
      case[[codeloc]] <- stringr::str_replace(case[[codeloc]], each[1], each[2])
    }
  }

  # calculate timedeltas for stop-start+1
  # used to use these for statistics on avg code duration. Depricated.
  # case['delta'] <- lapply(case[endloc]-case[startloc], function(k) seconds_to_period(period_to_seconds(k)) + lubridate::seconds(1))

  # convert start and stop to lubridate interval for overlap checking
  # initialize interval vector to avoid casting interval to numeric (seconds)
  intv <- rep(lubridate::interval("1970-01-01 00:00:00",
                                  "1970-01-01 00:00:00"), nrow(case))
  # TODO Catch and fix case where time is only in seconds!!
  for (row in 1:nrow(case)){
    if(case[row,endloc] < case[row,startloc]){
      # We need to un-merge all cases to point the user
      # to the case and code which were the problem.
      splits <- split(case, case$fname)
      lens = vector("numeric", length(splits))
      index <- 1
      for (book in splits){
        lens[index] <- nrow(book)
        index <- index + 1
      }
      # Now that we have the length of each user's case,
      # we can report the row of that user's codebook which caused the issue
      clens <- cumsum(lens)
      bookrow <- tail(clens[clens<=row], 1)
      stop(paste("Time range undefined; start ",
                 as.character(case[row,startloc]),
                 " comes after end ",
                 as.character(case[row,endloc]),
                 " in user ", case[row,1],
                 " at row ", as.character(row-bookrow),  sep=""))
    }
    intv[row] <- lubridate::interval(start=case[row,startloc],
                                     end=case[row,endloc], tz='UTC')
  }
  case[['interval']] <- intv

  # convert code strings to code numbers
  case[['codeId']] <- lapply(case[[codeloc]],
                             function (x) hash::values(code2num[tolower(trimws(x))]))

  # split out cases by user/filename
  codebooks <- split(case, case$fname)

  return(codebooks)
}


stat_mode <- function(data){
  # previously tried this with a hash, but hash::hash does not preserve insert
  # order and sorts by value, which differs from python's mode()
  # initialize named vector
  counter <- c("NA"=0)
  for(each in data){
    # names for named vector should be char
    nextkey <- as.character(each)
    # indexing named vector with char not in names will return NA
    if( !is.na(counter[nextkey]) ){
      counter[nextkey] <- counter[nextkey] + 1
    } else {
      # This is not efficient, but we expect to be dealing with small
      # numbers of codes, so it will work fine.
      counter <- c(counter, setNames(1,nextkey))
    }
  }

  # remove the NA element. Not strictly needed, but may help with debugging.
  counter <- counter[counter!=0]

  # in Python, mode() returns the first element seen if all are equally present.
  if (max(counter) == min(counter)){
    return(as.integer(names(counter[1])))
  }
  # if still multiple ties for most seen in window, return the lowest code.
  else{
    return(as.integer(names(counter[counter==max(counter)])[1]))
  }
}


get_overlap <- function(codebook, code, codeCol, interval, intCol, window){
  lubridate::int_start(interval) <- lubridate::int_start(interval) - window
  lubridate::int_end(interval) <- lubridate::int_end(interval) + window

  # matches <- codebook[codebook[codeCol]==code,]
  # find codes which overlap the given window
  overlaps <- lubridate::int_overlaps(interval, codebook[,intCol])
  # if no codes during this code's interval, code as 0
  if (sum(overlaps) == 0){
    return(0)
  # if there are overlaps and at least one of them is the same code, return the code
  }else if (sum(codebook[overlaps, codeCol]==code) > 0){
    return(code)
  # if there are overlaps but none of them match the code, grab the most common code found in the window or the first found
  } else {
    # WARNING: This will return the mode, but for the occasions where there is
    # no single mode, it returns the minumum instead of the first by index.
    # This caused conflicts with other mode() functions which return the
    # first element in case of equally present values.
    # return(as.numeric(sort(table(unlist(codebook[overlaps, codeCol])),decreasing=TRUE)[1]))
    othercodes <- codebook[overlaps, codeCol]
    return(stat_mode(sort(unlist(othercodes))))
  }

}

single_kappa <- function(codebooks, reference=1, windowSec=10, startCol=2, endCol=3, codeCol='codeId', intCol='interval'){
  # # find max length of codes
  # maxlen <- 0
  # for (j in 1:length(codebooks)){
  #   maxlen <- max(maxlen, nrow(codebooks[[j]]))
  # }

  # refbook serves to define time windows for agreement
  refbook <- codebooks[[reference]]

  res_len <- nrow(refbook)

  # remove reference
  rest <- codebooks[-reference]
  # define window; +/- offset checked for code agreement
  window <- lubridate::seconds(windowSec)

  # initialize results of coding with reference as first column
  all_results <- unlist(refbook[,codeCol])
  # TODO check comparison of ref to book for all codes
  for (book in rest){
    results <- vector("list", res_len)
    for (row in 1:res_len){
      code <- as.numeric(refbook[row,codeCol])

      start <- refbook[row,startCol]
      interval <- refbook[row,intCol]
      # get a matching code for this reference codebook to the test codebook
      # 0 = no codes in ref code interval +/- window
      # code = code match in ref code interval +/- window
      # other number = most prevalent code found in ref code interval +/- window if no code match.
      match <- get_overlap(book, code, codeCol, interval, intCol, window)

      results[row] <- match
    }

    # remove any remaining null from vector
    results <- results[1:length(unlist(results))]
    # add this codebook to the rest of the results and increment counter
    all_results <- cbind(all_results, unlist(results))
  }

  kappa <- irr::kappam.fleiss(all_results)
  return(kappa$value)

}

all_kappa <- function(codebooks, windowSec=10, startCol=2, endCol=3, codeCol='codeId', intCol='interval'){
  # initialize kappas
  kappas <- vector("list", length(codebooks))
  for (ref in 1:length(codebooks)){
    kappas[ref] <- single_kappa(codebooks,
                                ref,
                                windowSec,
                                startCol,
                                endCol,
                                codeCol,
                                intCol)
  }
  return(kappas)
}


