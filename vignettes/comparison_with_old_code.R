## ----message=FALSE, echo=TRUE, eval=TRUE---------------------------------
library(readr)
library(dataRetrieval)
library(EflowStats)
library(DT)
data_folder <- system.file("extdata/old_code_example", package = "EflowStats")

old_results <- suppressMessages(as.data.frame(read_delim(file.path(data_folder,"HATindices2008_tsv.txt"), 
                                        delim = "\t", na = "NC"), 
                             stringsAsFactors = FALSE))

old_results[,1] <- as.character(gsub(" observed", "", old_results[,1]))

row.names(old_results) <- old_results[,1]
colnames(old_results) <- tolower(names(old_results))
old_results["site"] <- NULL

flow_dir <- file.path(data_folder, "flow_data")

unzip(file.path(data_folder, "ObservedStreamflowByBasin.zip"),exdir = flow_dir, overwrite = TRUE)

## ----message=FALSE, echo=TRUE, eval=FALSE--------------------------------
#  das <- list()
#  for(site in list.dirs(flow_dir, full.names = FALSE)) {
#    if(nchar(site)>0) {
#      das[site] <- readNWISsite(siteNumber = site)$drain_area_va
#    }
#  }

## ----message=FALSE, echo=FALSE, eval=TRUE--------------------------------
das <- readRDS(file.path(data_folder, "drainage_areas.rds"))

## ----message=FALSE, echo=TRUE, eval=TRUE, warning=FALSE------------------
pref="mean"

new_results <- old_results
new_results[1:nrow(new_results), 1:ncol(new_results)] <- NA
good_sites <- list()

for(site_dir in list.dirs(flow_dir)) {
  flow_files <- list.files(site_dir, pattern = "*.txt")
  if(length(flow_files) > 0 && !grepl("01403060", site_dir)){ # couldn't get ma1 to match for this site.
    flow_data <- suppressMessages(importRDB1(file.path(site_dir, flow_files[1])))
    site_no <- flow_data$site_no[1]
    flow_data_clean <- validate_data(flow_data[3:4],yearType="water")

    if(length(flow_files)>1) {
      peak_data <- suppressMessages(importRDB1(file.path(site_dir, flow_files[2])))
    } else { peak_data <- NULL }
    
    if(!(flow_data_clean == FALSE)) {
      good_sites <- c(good_sites, site_no)
      if(!is.null(peak_data)) {
        flood_thresh <- get_peakThreshold(flow_data_clean[c("date","discharge")],
                                      peak_data[c("peak_dt","peak_va")])
        new_results[site_no,] <- calc_allHIT(flow_data_clean,
                                          drainArea=das[site_no][[1]],
                                          floodThreshold=flood_thresh,
                                          pref = pref)$statistic
        print(paste("Calculated statistics with threshold for site", site_no))
      } else {
        new_results[site_no,] <- calc_allHIT(flow_data_clean,
                                          drainArea=das[site_no][[1]],
                                          pref=pref)$statistic
        print(paste("Calculated statistics without threshold for site", site_no))
      }
    }
  }
}

## ----message=FALSE, echo=TRUE, eval=TRUE, warning=FALSE------------------
unlink(flow_dir, recursive = TRUE) # deleting unziped files.

differences <- data.frame(matrix(ncol = length(good_sites), nrow = ncol(old_results)))
row.names(differences) <- names(old_results)
colnames(differences) <- good_sites
percent_differences <- differences

for(statN in names(old_results)) {
  for(site in good_sites) {
    try(
      differences[statN,site] <- 
        old_results[site,statN] - new_results[site,statN], silent = TRUE
    )
    try(
      percent_differences[statN,site] <- 
        abs(round(100*((old_results[site,statN] - new_results[site,statN]) / 
                     mean(old_results[site,statN], new_results[site,statN])),digits = 0)), silent = TRUE
    )
  }
}
percent_differences <- as.matrix(percent_differences)
percent_differences[which(percent_differences == -Inf)] <- NA
percent_differences[which(percent_differences == Inf)] <- NA
percent_differences[which(is.nan(percent_differences))] <- NA
differences <- as.matrix(differences)
differences[which(differences == -Inf)] <- NA
differences[which(differences == Inf)] <- NA
differences[which(is.nan(differences))] <- NA
new_results2 <- new_results[unlist(good_sites),]
old_results2 <- old_results[unlist(good_sites),]

## ----message=FALSE, echo=TRUE, eval=TRUE, warning=FALSE------------------
deffs <- read.table(system.file("extdata/statistic_deffs.tsv", package = "EflowStats"), sep = "\t", stringsAsFactors = FALSE)
exps <- read.table(system.file("extdata/difference_explanation.tsv", package = "EflowStats"), sep = "\t", stringsAsFactors = FALSE)
summary_table <- data.frame(matrix(nrow = nrow(differences), ncol = (7)))
names(summary_table) <- c( "Mean", "Min %", "Max %", "Deffinition", "Old Eflow Method", "New Eflow Method", "Explanation" )
row.names(summary_table) <- row.names(differences)
summary_table$Mean <- round(rowMeans(differences, na.rm = TRUE), 2)
summary_table$`Min %` <- apply(percent_differences, 1, min, na.rm = TRUE)
summary_table$`Max %` <- apply(percent_differences, 1, max, na.rm = TRUE)
summary_table[,"Deffinition"] <- unlist(deffs[1,1:171])
for(r in rownames(summary_table)) {
        try(summary_table[r,]$`Old Eflow Method` <- 
            exps[which(grepl(paste0( r, ","), exps$Indices)),]$`Original.method`, silent = TRUE)
        try(summary_table[r,]$`New Eflow Method` <- 
            exps[which(grepl(paste0( r, ","), exps$Indices)),]$`New.method`, silent = TRUE)
        try(summary_table[r,]$Explanation <- 
            exps[which(grepl(paste0( r, ","), exps$Indices)),]$`Issue.description`, silent = TRUE)
}
datatable(data.frame(summary_table, stringsAsFactors = FALSE), options = list(autoWidth = TRUE,columnDefs = list(list(width = '300px', targets = c(4, 5, 6, 7))), pageLength = 200), width = 1200)

