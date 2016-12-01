## This file reads in the "All_jobs" CSV file created by _process_jobs.r, merges it to the
## CSVs with the earlier job postings that have already been ranked, and save a new, updated CSV file

## Clear out memory
rm(list = ls())
gc()

Sys.setlocale('LC_ALL','C')

## Load required packages
library(data.table)
options(stringsAsFactors=FALSE)
require(zoo)

## Old and New dates
olddate <- '10_21_2016'
date    <- '10_25_2016'

## Old and New filenames
old.file <- '../Output/All_JOE_jobs_2016-10-21_processed.csv'
new.file <- '../Output/All_JOE_jobs_2016-10-25_processed.csv'
    
## Load new.file
new.file <- data.table(read.csv(new.file))

## Load new.file
old.file <- data.table(read.csv(old.file))

## Rbind old and new files
all.file <- rbind(old.file,new.file)

## Merge files
new.file$new_listing <- TRUE
new.file$new_listing[new.file$jp_id %in% old.file$jp_id] <- FALSE
newest.file <- new.file[new.file$new_listing==TRUE,]

## Print number of new postings
cat('The number of new postings since last update is', newest.file[ , .N ], '\n')

## Save new file with all postings as csv and xls
write.csv(newest.file, paste0('../Output/Newest_jobs_list_',date,'_since',olddate,'.csv'))
