# econJobMarket
This repository contains `R` scripts and file structure to automate the collection of job listings from the primary aggregation websites for economics PhD job candidates: the AEA's JOE network, and EconJobMarket.org. The purpose of this repository is to help job candidates save time by allowing candidates to assert their job preferences ex ante and have the computer do the work of producing a list of jobs that match the candidate's stated preferences. The file structure is as follows:

## Inputs
To process JOE listings, the user needs to download the current listings as an XLS file from the main JOE listings webpage, <https://www.aeaweb.org/joe/listings.php?>. From there, click on "Download Options" and "Native XLS." Then place this .xls file in the "RawDownloads" folder of the repository, and rename the file to include the corresponding date. 

## Outputs
The outputs of the scripts are CSV files which contain the full set of information from each listing.

For JOE:
* `All_JOE_jobs_YYYY-MM-DD_processed.csv`, which is the set of "matched" listings
* `All_JOE_jobs_YYYY-MM-DD_bad_matches_processed.csv`, which is the set of "unmatched" listings. Note that the union of this set and the matched set is the full set of JOE postings.
* `All_JOE_jobs_YYYY-MM-DD_all_processed.csv`, which is the full set of JOE postings
* `All_JOE_jobs_YYYY-MM-DD_clean.csv`, which is an abbreviated version of the set of matches.

For EJM:
* `All_EJM_jobs_YYYY-MM-DD_processed.csv`, which is the set of "matched" listings
* `All_EJM_jobs_YYYY-MM-DD_raw.csv`, which is the full set of listings

## Scripts
There are three `R` scripts in the Rscripts folder:
1. `JOEprocessor.R`, which takes as an input the .xls file referenced above
2. `EJMprocessor.R`, which automatically downloads listings 
3. `updateJOEprocessor.R`, which uses the output from two different JOE .xls files to produce a list of new postings since the last date.

The code is fairly well commented, but there are a few things users should remember befor running the scripts:
* **`JOEprocessor.R`**: Be sure to change the filename on line 34 to match with the date that corresponds to your most recent listings file.
* **`EJMprocessor.R`**: You may need to adjust the variable `nwebpages` because EJM splits their listings URLs into groups of 50. At the same time, you will need to adjust the concatenation of the page-specific dataframes on line 63 to equal the number of webpages. I was unable to figure out a way to program this step.
* **`updateJOEprocessor.R`**: Change the dates corresponding to the "new" and "old" files so that the listings will correctly update.

Note that the JOE code in particular takes awhile because it scrapes each and every URL. The user can prevent this from happening by changing the want.scrape variable on line 29 to be `FALSE`.

Also note that EJM posts much less information about listings than does JOE. Therefore the output for EJM listings is much less customizable. Also, the EJM script might take awhile to run because it is entirely scraped. Finally, the EJM script will issue a number of warnings, which the user should ignore.

# Troubleshooting
This code has been extensively tested. If you encounter errors they are likely the following:
* If you receive an error message in the JOE file that mentions the phrase "POSIX", it is likely to be due to a listing that is un-parse-able. In this case, do your best to manually search for the listing and then add it to the conditions in line 45.
* If you don't see any updated listings between two given dates, it is likely because you forgot to update the dates as mentioned above.
* If you encounter an error in the EJM file, it is likely because you need to adjust the variable `nwebpages` to match with the current number of EJM listings.

# Disclaimer
Along with the standard GNU-style disclaimers, I add that the scraping code is written to be compatible with these websites as of Dec 1, 2016. Any future changes to the style and/or structure of these websites might invalidate the code as presently written.

# Acknowledgements
This repository is largely made possible by the generosity of Eduardo Jardim and Katya Roschina, who originally shared their R code with me. They engineered their version using some code from <http://freigeist.devmag.net>, which I also gratefully acknowledge.