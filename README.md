# Preprocessing for a Modified Kappa Calculation
Functions are provided for loading csv files containing start and stop times, codes, and descriptions/notes.
Each case should be contained in its own directory, with each rater's codes in a separate csv file like so:
<br>
\[Case Folder\] <br>
&emsp;  |\_\_>  \(case_rater1.csv\) <br>
&emsp;  |\_\_>  \(case_rater2.csv\) <br>
&emsp;  |\_\_> ... <br>

In ```preprocess_codebooks.R```, load a case with the ```preprocess_case()``` function. This function takes in the following parameters:

* ```caseDirPath```   - string representing a valid file path to a folder containing each rater's coding files. DEFAULT: "."
* ```startCol```      - integer representing the column in each rater's coding file containing the code start times. DEFAULT: 1
* ```endCol```        - integer representing the column in each rater's coding file containing the code end times. DEFAULT: 2
* ```codeCol```       - integer representing the column in each rater's coding file containing the code labels, parsed as strings. DEFAULT: 4
* ```pat```           - a valid regex string containing the search pattern for valid rater's files. DEFAULT: "*.csv$"
* ```header```        - boolean, whether or not each rater's coding file contains a header (labels) in the first row. DEFAULT: FALSE
* ```delimiter```     - a string with the delimiter used to separate columns in each rater's coding file. DEFAULT: ","
* ```quoteChar```     - a string with the character(s) to be used to identify quotes. When parsing, text between the quote characters will not by parsed directly. DEFAULT: "\\"" (a doube quote)
* ```colTypes```      - a vector of string types to infer each column from each rater's coding file as it's read in. DEFAULT: c("numeric", "numeric", "character", "character")
* ```parseDates```    - a logical vector where each value indicates whether to parse that column in the rater's coding file as a datetime object. DEFAULT: c(TRUE, TRUE, FALSE, FALSE)
* ```dateFmt```       - a string corresponding to a ```lubridate``` parser. DEFAULT: "ms" Options include:
  * "ms"      - minutes and seconds
  * "hms"     - hours, minutes, seconds
  * "hm"      - hours and minutes
  * "ymd"     - year, month, day
  * "mdy"     - month, day, year
  * "my"      - month and year
  * "ymd_hms" - year, month, day and hour, minute, second
  * "mdy_hms" - month, day, year and hour, minute, second
  * Any other string is passed, will throw a warning and default to "hms"

With these parameters, you should be able to adapt this function call to meet your coding format.
This function will read in each rater's codes, clean up codes by stripping trailing and leading spaces then casting to lowercase, making regex substitutions from a global var called ```replacements```, 
creates a column with time interval objects for each code, and creates a hash map of each code string to a unique integer starting from 1 and counting up. 
Each rater's codes are then separated according to the file name, so each rater's coding file should have a unique name within each case.

This function returns a list of data frames, where each data frame is a different rater's codes.

Next, run the function ```all_kappa()``` to calculate the kappa scores for the case. This function takes the following parameters:

* ```codebooks```    - a list of data frames pre-processed as above
* ```windowSec```    - integer representing a window on either side of each code to allow for agreement when raters are slightly misaligned. DEFAULT: 10
* ```startCol```     - integer representing the column in each rater's data frame containing the parsed start times for codes. During ```preprocess_case()```, the first column is added as the rater's file name (string). DEFAULT: 2
* ```endCol```       - integer representing the column in each rater's data frame containing the parsed end times for codes. Will be offset by one column for the same reason as ```startCol```. DEFAULT: 3
* ```codeCol```      - string representing the column name in each rater's data frame containing the parsed codes as integers. In ```preprocess_case()```, this column will be named 'codeId'. DEFAULT: "codeId"
* ```intCol```       - string representing the column name in each rater's data frame containing the parsed ```lubridate::interval``` objects. In ```preprocess_case()```, this column will be named 'interval'. DEFAULT: "interval"

This funtion will loop over the list of data frames in ```codebooks```, and each rater will then be used as a reference against which each code of theirs is checked for agreement with every other rater.
In a future release, extra parameters will be added to give finer-grained control over what constitutes agreement. For now, each code interval in the reference rater's codes has ```windowSec``` subtracted from the start and adde to the end times, widening the interval by ```2 * windowSec```. 
Then, each other rater's codebook is checked for any codes which overlap that interval, endpoint inclusive. For example, "00\:05\:15" - "00\:06\:10" WOULD overlap with "00\:06\:10" - "00\:07\:40". 
If the same code is found overlapping the reference rater's code, agreement is recorded. If only different code(s) are found for the reference rater's code interval, the first or most common code identified in that interval is recorded as disagreement. If no other codes were identified during the referenec rater's code interval, a '0' is recorded as a NULL code to indicate disagreement.

This function returns a list of kappa scores, where each score represents the agreement of the raters when calculated against the reference rater's codes, in order. So for three raters, A, B, and C, a list of Kappas \[0.554, 0.467, 0.632\] indicate the Fleiss' kappa when using raters A, B, and C to define the unit of analysis, respectively, according to the rules outlined above.




