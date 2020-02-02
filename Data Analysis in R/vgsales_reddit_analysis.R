### It is recommended you run each analyze_mentions() line at a time, instead of all at once

suppressMessages({suppressWarnings({
  library(csv)
  library(grid)
  library(gridExtra)
  library(stringr)  #truncate chars
})})

getwd()
setwd("..")
setwd("./Datasets") #location of data files
options(scipen = 2)  #get rid of scientific notation display using "e"
while (!is.null(dev.list()))  dev.off()  #rmv prev plots if there are any

tt3 <- ttheme_default(
  core=list(bg_params = list(fill = blues9[3:4]),
            fg_params=list(fontface="bold")),
  colhead=list(fg_params=list(col="navyblue", fontface=2L)))

analyze_mentions <- function(category, data) {
  levels <- unique(data[[category]])
  print(paste0("Num levels: ", length(levels)))  # Number of levels
  
  freq_df <- data.frame(sort(table(data[[category]]), decreasing = TRUE)) #Num games in Catg
  freq_df <- freq_df[c(2,1)]  #switch freq and catg col positions
  
  sales_per_catg <- data.frame(matrix(ncol = 0, nrow = 0))
  for(i in seq_along(levels)){
    temp <- data[data[[category]] == levels[i],  ]
    sales_per_catg[i, category] <- levels[i]
    sales_per_catg[i, "TotalSales"] <- sum(temp[["NA_Sales"]])
  }
  sales_sorted <- sales_per_catg[order(sales_per_catg$TotalSales, decreasing = TRUE),] #sort by $

  ment_per_catg <- data.frame(matrix(ncol = 0, nrow = 0))
  for(i in seq_along(levels)){  #get popularity of each category
    tempdf <- data[data[[category]] == levels[i],  ]
    ment_per_catg[i, category] <- levels[i]
    ment_per_catg[i, "Popularity"] <- round(sum(tempdf$normalized.mentions.before + tempdf$normalized.mentions.after), 3)
  }
  ment_sorted <- ment_per_catg[order(ment_per_catg$Popularity, decreasing = TRUE),] #sort by popul.
  
  spacer <- data.frame(  "  " = seq(1, length(levels) ))
  combined <- cbind(freq_df, spacer, ment_sorted, spacer, sales_sorted)
  colnames(combined) <- c("Num. of games", "Num. Games Rank", "  ", 
                          "Reddit Rank", "Reddit Popularity", "  ",
                          "Sales Rank", "Total Sales ($ mil)")
  grid.newpage()  # prevent plots from overlapping
  if (nrow(combined) < 20) {grid.table(combined, theme=tt3, rows=NULL)
    } else { grid.table(head(combined, n = 10), theme=tt3, rows=NULL) }
}

data <- read.csv("game_mentions_data_months.csv", stringsAsFactors=FALSE)  
data$Rating[data$Rating == ""] <- "NR"
data$Publisher <- str_trunc(data$Publisher, 15)  #12 chars and 3 dots. 2 games rmvd but they were not used in this analysis so inconsequential

analyze_mentions("Rating", data)
# NR unusually high popularity, so check for outliers
tempdf <- data[data$Rating == "NR",]
tempdf <- data
tempdf$ments <- round(tempdf$normalized.mentions.before + tempdf$normalized.mentions.after, 3)
tempdf <- tempdf[order(-tempdf$ments), ]
tempdf <- data.frame(tempdf$Name, tempdf$ments)
colnames(tempdf) <- c("Game", "Mentions Before + After")
grid.newpage()
grid.table(head(tempdf, n = 10))
# "Game & Wario" overrepr due to "&" error in post scraping. Rmv all games w/ "&"
data <- data[!grepl("&", data$Name), ]
data <- data[!grepl("Game", data$Name), ]
nrow(data)

analyze_mentions("Rating", data)
analyze_mentions("Genre", data)
analyze_mentions("Publisher", data)

#after reinstating by platform using script OR delete those that are not platform exclusive (have names repeated twice)
data_plat <- read.csv("game_mentions_platform_split.csv", stringsAsFactors=FALSE)  
data_plat <- data_plat[!grepl("&", data_plat$Name), ]
data_plat <- data_plat[!grepl("&", data_plat$Name), ]
analyze_mentions("Platform", data_plat)

analyze_mentions("Year_of_Release", data)
analyze_mentions("month", data)

data$month = factor(data$month, levels = month.abb)  #order months chronologically
barplot(table(data[["month"]]), main = "Number of Games Released in Month", xlab="Release Month")

levels <- levels(data[["month"]])
sales_per_catg <- data.frame(matrix(ncol = 0, nrow = 0))
for(i in seq_along(levels)){
  temp <- data[data[["month"]] == levels[i],  ]
  sales_per_catg[i, "month"] <- levels[i]
  sales_per_catg[i, "TotalSales"] <- sum(temp[["NA_Sales"]])
}
barplot(sales_per_catg[["TotalSales"]], main = "Sales ($ mil) by Release Month", 
        xlab="Release Month", names.arg = levels)
