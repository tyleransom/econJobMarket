## Scrapes job postings from econjobmarket.org
## uses the code from http://freigeist.devmag.net

## Clear out memory
rm(list = ls())
gc()

## Load required packages
require(gdata)
require(XML)
require(rvest)
require(stringr)
options(stringsAsFactors=FALSE)

## Function to grab nth through last components of a string:
substrEnd <- function(x, n){
  substr(x, n, nchar(x))
}

## Number of pages of listings (user needs to adjust each time)
nwebpages <- 5

for (j in 1:nwebpages) {
	## Do initial extraction from EJM website
	ejmurl   <- paste0("https://econjobmarket.org/postings.php?region=0&field=0&search=0&refined=0&limit=50&page=",j)
	temp     <- read_html(ejmurl)
	alldata  <- temp %>% html_nodes("#right_col") %>% as.character() #returns listings as character vector

	## Capture listing titles
	listings <- sapply(getNodeSet(htmlParse(alldata), "//a"), xmlValue)
	tester   <- sapply(getNodeSet(htmlParse(alldata), "//strong"), xmlValue)
	tester1  <- sapply(getNodeSet(htmlParse(alldata), "//span"), xmlValue)
	tester2  <- sapply(getNodeSet(htmlParse(alldata), "//br"), xmlValue)

	## Create URL for each listing
	alldata  <- gsub("<div id=\"right_col\">\n  <span>\n    ","",alldata)
	urls     <- matrix("https://econjobmarket.org/postings.php",length(alldata),1) 
	urlsuffx <- as.matrix(substr(alldata,10,20))
	urlfinal <- paste0(urls,urlsuffx)

	## Capture employer names and full text of listing
	employers <- matrix("",length(alldata),1)
	fulltext <- matrix("",length(alldata),1)
	for (i in 1:length(alldata)) {
		temp1        <- read_html(urlfinal[i])
		temp2 <- temp1 %>% html_nodes("span")
		employers[i] <- xmlValue(getNodeSet(htmlParse(as.character(temp2[3])), "//span")[[1]])
		fulltext[i] <- temp1 %>% html_nodes("#contentLeft p") %>% as.character()
	}
	fulltext <- sapply(getNodeSet(htmlParse(fulltext), "//p"), xmlValue)

	## Capture application deadlines
	deadlines <- temp %>% html_nodes("span span") %>% as.character()
	deadlines <- deadlines[seq(2,length(deadlines),2)]
	deadlines <- sapply(getNodeSet(htmlParse(deadlines), "//span"), xmlValue)
	deadlines <- as.POSIXct(strptime(deadlines, format="%b %d, %Y"))

	## Concatenate into final data frame
	nam <- paste0("EJM", j)
	assign(nam, data.frame(employers,listings,deadlines,urlfinal,fulltext))
}

EJM <- rbind(EJM1,EJM2,EJM3,EJM4,EJM5) #,EJM6
colnames(EJM) <- c("Institution","Position","Deadline","URL","full_text")

## Capture the number of listings printed on EJM homepage, for error-checking purposes
nlistings <- temp %>% html_nodes("br+ h2") %>% as.character()
nlistings <- substr(nlistings,5,7)
nlistings <- gsub(" ","",nlistings)
nlistings <- as.integer(nlistings)

## Check for errors
stopifnot(nlistings==length(EJM$Deadline))

## Export to CSV
write.csv(EJM, paste0('../Output/All_EJM_jobs_',Sys.Date(), '_raw.csv'))

##--------------------------------------------------------------------------------------------------------------------------
## User should fill in the next section of the script with his or her preferences. I give examples of the many possibilities
##--------------------------------------------------------------------------------------------------------------------------

# Drop non-full-time/non-qualifying listings
EJM <- EJM[!grepl(paste(c("postdoc","distinguished","lecture","chair","professorship"), collapse="|"),EJM$Position, ignore.case=TRUE, perl=TRUE, useBytes=TRUE),]
# EJM <- EJM[grepl("assistant",EJM$Position, ignore.case=TRUE, perl=TRUE, useBytes=TRUE) & !grepl(paste(c("associate","full"), collapse="|"),EJM$Position, ignore.case=TRUE, perl=TRUE, useBytes=TRUE) ,]

# Drop listings from specific institutions
EJM <- EJM[!grepl(paste(c("dhabi","dalian","shenzhen","shanghai","tokyo","dubai"), collapse="|"),
                          EJM$Institution, ignore.case=TRUE, perl=TRUE, useBytes=TRUE),]

##--------------------------------------------------------------------------------------------------------------------------
## End of user customization section
##--------------------------------------------------------------------------------------------------------------------------

write.csv(EJM, paste0('../Output/All_EJM_jobs_',Sys.Date(), '_processed.csv'))
