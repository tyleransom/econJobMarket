## Reads XLS files downloaded from JOE website. The files should be in the same folder. Be attentive to how the files should be named.
## Job listings (JOE)
## uses the code from http://freigeist.devmag.net

## Clear out memory
rm(list = ls())
gc()

Sys.setlocale('LC_ALL','C')

## Load required packages
require(countrycode)
require(gdata)
require(rvest)
require(data.table)
require(stringr)
require(xlsx)
options(stringsAsFactors=FALSE)
require(zoo)

## Function to scrape JOE application requirements/instructions
scrapeJOE <- function(url){
    temp <- read_html(url)
    out  <- temp %>% html_nodes("br+ .dialog_text > div") %>% html_text()
    return(out)
}

## Does the user want to invoke scraping?
want.scrape <- FALSE

## Convert downloaded JOE file from XLS to CSV (easier to turn into R data table)
warning("Make sure you change the date on line 34 of this script!")
warning("Note: You may have to manually delete certain listings because of unreadable characters")
rawfile <- "../RawDownloads/joe_resultsetOct25.xls"
date <- substr(file.mtime(rawfile),1,10)
JOBS <- read.xls(rawfile,sheet=1) #,quote = ""
outfname <- paste0('../RawDownloads/jobs',date)
write.csv(JOBS,paste0(outfname,'.csv'))

print(paste("Processing",outfname))

## Import CSV to R data table
JOBS <- data.table(read.csv(file=paste0(outfname, ".csv")))
print(dim(JOBS))

## Manually delete problematic listings (that for some reason have characters that cause the parsing to fail)
flag <- (JOBS$jp_institution=="Federal Reserve Bank of San Francisco") | (JOBS$jp_institution=="St. Norbert College") | (is.na(JOBS$jp_id))
JOBS <- JOBS[!flag,]
print(dim(JOBS))

## If deadline is missing --> put 11/01/2016
JOBS$Application_deadline[JOBS$Application_deadline==""] <- "2016-11-01"
JOBS$Application_deadline <- as.POSIXct(JOBS$Application_deadline)

## Split out the country
JOBS$domestic <- grepl("UNITED STATES",JOBS$locations)
JOBS$country  <- gsub("([A-Z]*)( [A-Z]{2,})?(.*)","\\1\\2", JOBS$locations)
## Get harmonized country codes
JOBS$iso3 <- countrycode(JOBS$country, "country.name", "iso3c", warn = FALSE)

## Convert full text field to character
JOBS$jp_full_text <- as.character(JOBS$jp_full_text)

## Create "other date" field which is any other Oct, Nov, or Dec date mentioned in the full text
JOBS$otherdate <- ""
whichare <- regexpr("(October|November|December) ([0-9]{1,2})(,)? (2016)?",JOBS$jp_full_text, perl=TRUE, useBytes=TRUE)
JOBS[whichare[1:nrow(JOBS)]!=-1]$otherdate <- regmatches(JOBS$jp_full_text,whichare)
whichare <- regexpr("([0-9]{1,2}) (October|November|December)(,)? (2016)?",JOBS$jp_full_text, perl=TRUE, useBytes=TRUE)
JOBS[whichare[1:nrow(JOBS)]!=-1]$otherdate <- regmatches(JOBS$jp_full_text,whichare)
whichare <- regexpr("([0-9\\.\\/]{1,+})([1-9]\\.\\/]{1,+})(2016)?",JOBS$jp_full_text, perl=TRUE, useBytes=TRUE)
JOBS[whichare[1:nrow(JOBS)]!=-1]$otherdate <- regmatches(JOBS$jp_full_text,whichare)

## Add the JOB LISTING URL
JOBS$url <- JOBS[, paste("https://www.aeaweb.org/joe/listing.php?JOE_ID=",joe_issue_ID,"_",jp_id,sep="")]

if (want.scrape==TRUE) {
	## Scrape application instructions from job listing URL
	JOBS <- cbind(JOBS,matrix("",dim(JOBS)[1],1))
	colnames(JOBS)[length(JOBS)] <- "instructions"
	for (i in 1:dim(JOBS)[1]) {
		JOBS$instructions[i] <- scrapeJOE(JOBS$url[i])
	}
	JOBS$instructions <- gsub("\\n\\n\\t\\tApplication Requirements","Application Requirements: " ,JOBS$instructions)
	JOBS$instructions <- gsub("\\t\\n\\t"                           ,""                           ,JOBS$instructions)
	JOBS$instructions <- gsub("\\r\\n"                              ," "                          ,JOBS$instructions)
	JOBS$instructions <- gsub("Instructions Below"                  ,"Instructions Below. : "     ,JOBS$instructions)
	JOBS$instructions <- gsub("Application Instructions"            ," Application Instructions: ",JOBS$instructions)

	## Generate the application system (i.e. JOE, EJM, AJO, native institution website, email, etc.)
	url_pattern <- "http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+"

	JOBS$ApplicationURL <- ""
	whichare <- regexpr(url_pattern,JOBS$jp_full_text, perl=TRUE, useBytes=TRUE)
	JOBS[whichare[1:nrow(JOBS)]!=-1]$ApplicationURL <- regmatches(JOBS$jp_full_text,whichare)

	JOBS[ , EJM := as.integer(grepl("econjobmarket\\.org"     ,ApplicationURL,ignore.case=TRUE) | grepl("econjobmarket\\.org"     ,instructions,ignore.case=TRUE))]
	JOBS[ , JOE := as.integer(grepl("aeaweb\\.org"            ,ApplicationURL,ignore.case=TRUE) | grepl("aeaweb\\.org"            ,instructions,ignore.case=TRUE))]
	JOBS[ , AJO := as.integer(grepl("academicjobsonline\\.org",ApplicationURL,ignore.case=TRUE) | grepl("academicjobsonline\\.org",instructions,ignore.case=TRUE))]
	JOBS[ , Electronic := as.integer(grepl("email",instructions, ignore.case=TRUE))]
	JOBS[ , Interfolio := 1 - EJM - JOE - AJO - Electronic ]
	JOBS[ , Other := (AJO | Electronic) ]
}

## Extract e-mail address for inquiries
email_pattern <- "([_a-z0-9-]+(\\.[_a-z0-9-]+)*@[a-z0-9-]+(\\.[a-z0-9-]+)*(\\.[a-z]{2,4}))"
JOBS$InquiryEmail <- ""
whichare <- regexpr(email_pattern,JOBS$jp_full_text, perl=TRUE, useBytes=TRUE)
JOBS[whichare[1:nrow(JOBS)]!=-1]$InquiryEmail <- regmatches(JOBS$jp_full_text,whichare)

## Remove year and comma from "other date"
JOBS[grepl(", 2016",otherdate) , otherdate_noyear := gsub(", 2016","",otherdate)]
JOBS[grepl(" 2016",otherdate) , otherdate_noyear := gsub(" 2016","",otherdate_noyear)]
JOBS[grepl(", ",otherdate) , otherdate_noyear := gsub(", ","",otherdate_noyear)]

## Convert "other date" to POSIX format
JOBS[ , otherdate_day := as.numeric(gsub("[^\\d]+", "", otherdate_noyear, perl=TRUE)) ]
JOBS[ grepl("November",otherdate_noyear), otherdate_month := 11]
JOBS[ grepl("October",otherdate_noyear), otherdate_month := 10]
JOBS[ grepl("December",otherdate_noyear), otherdate_month := 12]

JOBS[is.na(otherdate_month)==F & is.na(otherdate_day)==F, otherdate_asDate_ready := paste0("2016-",otherdate_month,"-",otherdate_day)]
JOBS[ , deadline_other := as.Date(otherdate_asDate_ready)]

## Generate "effective" deadline
JOBS[ , true_deadline := as.Date(Application_deadline)]
JOBS[ is.na(deadline_other)==F, true_deadline := as.Date(deadline_other)]
JOBS <- JOBS[order(true_deadline)]

## Print number of listings
print(dim(JOBS))

##--------------------------------------------------------------------------------------------------------------------------
## User should fill in the next section of the script with his or her preferences. I give examples of the many possibilities
##--------------------------------------------------------------------------------------------------------------------------

## Geography (countries)
iso3.to.keep <- c("USA","CAN","MEX","ESP")
JOBS <- JOBS[is.element(iso3,iso3.to.keep)==T | JOBS$domestic==T, ]

## Keep only permanent jobs
JOBS$ft <- grepl("Full-Time", JOBS$jp_section)

## Keep job listings only for a specific set of JEL codes: note that the user should favor Type II errors over Type I errors here
toMatch <- c("00 - Default: Any Field",
             "A - General Economics and Teaching",
             "C - Mathematical and Quantitative Methods",
             "D - Microeconomics",
             "K - Law and Economics",
             "L - Industrial Organization",
             "R - Urban, Rural, Regional, Real Estate, and Transportation Economics",
             "A0","A1","A2","A3","A4","A5","A6","A7","A8","A9",
             "C0","C1","C2","C3","C4","C5","C6","C7","C8","C9",
             "D0","D1","D2","D3","D4","D5","D6","D7","D8","D9",
             "K0","K1","K2","K3","K4","K5","K6","K7","K8","K9",
             "L0","L1","L2","L3","L4","L5","L6","L7","L8","L9",
             "R0","R1","R2","R3","R4","R5","R6","R7","R8","R9")
JOBS$myfields <- grepl("Any field",JOBS$jp_full_text, ignore.case=TRUE, useBytes=TRUE) | 
                 grepl(paste(toMatch, collapse="|"),JOBS$JEL_Classifications, perl=TRUE, useBytes=TRUE)


## Keep only eligible tenure-track jobs for junior candidates (i.e. no Deans, Dept Chairs, etc.)
JOBS$positionsToKeep <- !grepl(paste(c("Dean","Chair","Visiting","Professorship",
                                       "Professor of the Practice","Research Assistant",
                                       "Lecturer","Staff Fellow","Department Head of Economics",
                                       "Director of School of Public Policy"), collapse="|"), JOBS$jp_title, perl=TRUE, useBytes=TRUE)

## Drop listings in medical schools or public health schools
JOBS$positionsToKeep[grepl(paste(c("Public Health","School of Medicine"), collapse="|"),JOBS$jp_division, perl=TRUE, useBytes=TRUE)] <- FALSE

## Drop Ag Econ jobs
JOBS$positionsToKeep[grepl(("Agricultural"),JOBS$jp_title, perl=TRUE, useBytes=TRUE)] <- FALSE

## Drop jobs for unqualified positions for first-time job marketeers (note the leading/trailing spaces for some of these)
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Professor of Economics "                                                       ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Professor of Economics"                                                        ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Full Professor of Economics "                                                  ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Full Professor of Economics"                                                   ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Full Professor "                                                               ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Full Professor"                                                                ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Professor "                                                                    ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate Professor"                                                                        ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate or Professor"                                                                     ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate Professor, Economics"                                                             ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate Professor / Professor"                                                            ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate Professor/ Professor"                                                             ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate Professor or Professor"                                                           ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Associate Professor or Professor "                                                          ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Professor and Department Head"                                                              ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Director of Undergraduate Studies"                                                          ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Professor "                                                                                 ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Professor"                                                                                  ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Clinical Assistant Professor"                                                               ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Director, School of Public Policy"                                                          ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_title=="Professor of Public Policy and Economics"                                                   ] <- FALSE

## Drop other jobs that aren't a good fit (these could be certain institutions, certain departments, certain divisions, etc.)
JOBS$positionsToKeep[(JOBS$jp_institution=="Microsoft") & (JOBS$jp_title=="Senior Research Economist ") ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_department=="Mathematics"                                                  ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_division=="Wilson Sheehan Lab for Economic Opportunities"                  ] <- FALSE
JOBS$positionsToKeep[JOBS$jp_institution=="Consumer Financial Protection Bureau"                        ] <- FALSE

##--------------------------------------------------------------------------------------------------------------------------
## End of user customization section
##--------------------------------------------------------------------------------------------------------------------------

## Divide listings into separate data tables for matched (JOBS) and unmatched (JOBSfalse)
print(dim(JOBS))
JOBSall <- JOBS
JOBS <- JOBSall[JOBSall$ft==TRUE & JOBSall$myfields==TRUE & JOBSall$positionsToKeep==TRUE, ]
JOBSfalse <- JOBSall[JOBSall$ft==FALSE | JOBSall$myfields==FALSE | JOBSall$positionsToKeep==FALSE, ]
print(dim(JOBSall))

# ## Save to Excel spreadsheet
# write.xlsx(JOBS, paste0('../Output/', outfname,'_processed.xlsx'))
# write.xlsx(JOBSfalse, paste0('../Output/', outfname,'false_processed.xlsx'))
# write.xlsx(JOBSall, paste0('../Output/', outfname,'all_processed.xlsx'))

## Keep only most important columns (for the "clean" CSV)
JOBSabbrev <- JOBS[,c("jp_id","jp_institution","jp_keywords","url","true_deadline"), with=FALSE]

## Output the files
write.csv(JOBS      , paste0('../Output/All_JOE_jobs_', date, '_processed.csv'))
write.csv(JOBSabbrev, paste0('../Output/All_JOE_jobs_', date, '_clean.csv'))
write.csv(JOBSfalse , paste0('../Output/All_JOE_jobs_', date, '_bad_matches_processed.csv'))
write.csv(JOBSall   , paste0('../Output/All_JOE_jobs_', date, '_all_processed.csv'))
