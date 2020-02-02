suppressMessages({suppressWarnings({
  library(csv)
  library(data.table)
  library(e1071)  #for skewness
  library(ggplot2)
  library(tidyr)
  library(grid)
  library(gridExtra)  #output dataframe in neat table
  library(reshape2) #for corr matrices into heatmaps
  library(plyr)  #plot titles in grid
  library(glmnet)  #LASSO
  library(ggfortify)  #regression assumption checking
  library(lmtest)  #durbin watson test
})})

getwd()
setwd("..")
setwd("./Datasets") #location of data files
options(scipen = 2)  #get rid of scientific notation display using "e"
par(mfrow=c(1,1))  #reset how plots are displayed
while (!is.null(dev.list()))  dev.off()  #rmv prev plots if there are any

######### LOAD AND CLEAN DATA ######### 
raw_data <- read.csv("game_mentions_data_months.csv", stringsAsFactors=FALSE)
num_samples <- data.frame(matrix(ncol = 1, nrow = 5))
num_samples[1,1] <- nrow(raw_data)
paste("Initial # of samples: ", nrow(raw_data))

#Remove outliers that have no mentions and thus weren't even participating
vg_data <- raw_data[raw_data$normalized.mentions.before != 0,  ]  #get rid of games with 0 mentions
vg_data <- vg_data[vg_data$normalized.mentions.after != 0,  ]
num_samples[2,1] <- nrow(vg_data)
paste("# after rmv samples w/ no mentions: ", nrow(vg_data))

# Check which variables have missing data NAs
apply(apply(raw_data, 2, is.na), 2, any)

# Remove samples with missing data
user_score <- as.numeric(vg_data$User_Score)  #else most will be NA
paste("% samples w/ NA user scores", sum(is.na(user_score)) / nrow(vg_data) * 100)
paste("% samples w/ NA critic scores", sum(is.na(vg_data$Critic_Score)) / nrow(vg_data) * 100)
vg_data <- vg_data[!is.na(user_score),  ]  #remove all data with N/A user scores
vg_data <- vg_data[!is.na(vg_data$Critic_Score),  ]
num_samples[3,1] <- nrow(vg_data)
paste("# after rmv samples w/ NA scores: ", nrow(vg_data))

# Remove games whose popularity was erroneously scraped due to wrongly attributed keywords
#First identify any games w/ '&', as & lead to wrongly attributed keywords
nrow(vg_data[!grepl("&", vg_data$Name), ])  #found no more games w/ & after rmv outliers
nrow(vg_data[!grepl("Game", vg_data$Name), ])  #rmv only Back to Future
vg_data <- vg_data[!grepl("Game", vg_data$Name), ]
# Manually look at the list and identify games that should not be as popular
tempdf <- vg_data
tempdf$ments <- round(tempdf$normalized.mentions.before + tempdf$normalized.mentions.after, 3)
tempdf <- tempdf[order(-tempdf$ments), ]
tempdf <- data.frame(tempdf$Name, tempdf$ments)
colnames(tempdf) <- c("Game", "Mentions Before + After")
write.csv(tempdf,'mentions_error_check.csv')
# No unusual discrepencies found, so no outliers were further removed 
num_samples[4,1] <- nrow(vg_data)
paste("# after rmv samples w/ 'Game' in title: ", nrow(vg_data))

### SELECT NUMERICAL VARS TO USE IN ANALYSIS
model_data <- subset(vg_data, select=c("normalized.mentions.before", "normalized.mentions.after",
                         "upvotes.before", "upvotes.after","User_Score","Critic_Score",
                         "NA_Sales"))
model_data$User_Score <- as.numeric(vg_data$User_Score)
setnames(model_data, old = c('normalized.mentions.before','normalized.mentions.after', 'NA_Sales'), 
         new = c('mentions_b','mentions_a', 'sales'))

#########  DISTRIBUTIONS AND TRANSFORMS #########  
log_to_apply <- function(var){
  if (mean(var) < 1){
    log_var <- log(var)
  } else {
    log_var <- log1p(var)
  }
  return(log_var)
}

log_model_data <- data.frame(apply(model_data, 2, log_to_apply))

before <- apply(model_data, 2, skewness)
after <- apply(log_model_data, 2, skewness)
skewness_table <- data.frame(round(cbind(before, after),2))
colnames(skewness_table) <- c("Skewness Before", "Skewness After")
grid.newpage()  # prevent plots from overlapping
grid.table(skewness_table) #Skewness Before & After log()

#Histogram for each log() variable. Put all in one plot.
unlogged <- model_data[, apply(log_model_data, 2, skewness) < 1 & apply(log_model_data, 2, skewness) > 0]
log_normed <- log_model_data[, apply(log_model_data, 2, skewness) < 1 & apply(log_model_data, 2, skewness) > 0]
suppressMessages({
  p<- ggplot(melt(unlogged), aes(x = value)) + facet_wrap(~variable,scales = "free") +
    geom_histogram() + theme(axis.title.x=element_blank())
  suppressMessages(print(p))  #suppress stat-bin warning
  
  p<- ggplot(melt(log_normed), aes(x = value)) + facet_wrap(~variable,scales = "free") +
    geom_histogram() + theme(axis.title.x=element_blank())
  suppressMessages(print(p))  #suppress stat-bin warning
})

#Compare normal distributions of before and after log()
suppressMessages({
  ggplot(melt(unlogged), aes(sample = value)) + facet_wrap(~variable,scales = "free") +
    geom_qq(distribution = stats::qnorm) + theme(axis.title.x=element_blank()) +
    scale_y_continuous(limit=NULL)
  ggplot(melt(log_normed), aes(sample = value)) + facet_wrap(~variable,scales = "free") +
    geom_qq(distribution = stats::qnorm) + theme(axis.title.x=element_blank()) +
    scale_y_continuous(limit=NULL)
})

# Scores vars found to have negative skewness, so try transforming them
#log(0) is -inf, so +1 prevents that
critic_score <- model_data$Critic_Score
transf_critic <- (max(critic_score) + 1) - critic_score 
skewness(critic_score); skewness(transf_critic); skewness(log( transf_critic))

User_Score <- model_data$User_Score
transf_user <- log(max(User_Score)+1 - User_Score)
skewness(User_Score); skewness(transf_user)

# Did not improve critic_score skewness, only user_score skewness
log_model_data$User_Score <- transf_user

######### HEATMAP CORRELATION MATRIX ######### 
corr <- round(cor(log_model_data, method = c("pearson")), 2)
melted_cormat <- melt(corr)
ggplot(data = melted_cormat, aes(x=Var1, y=Var2, fill=value)) + geom_tile() +
        theme(axis.title.x=element_blank(), axis.title.y=element_blank()) + 
        geom_text(aes(label = value)) + scale_fill_gradient(low = "white", high = "red") +
        scale_x_discrete(position = "top") + ylim(rev(colnames(corr)))

#Use corr matrix to select numerical vars to be used in regression

# mentions_b transforms comparisons
vg_data_subset <- cbind(vg_data$mentions.before, model_data$mentions_b, log_model_data$mentions_b, 
                        model_data$sales, log_model_data$sales)
vg_data_subset <- data.frame(vg_data_subset[complete.cases(vg_data_subset), ])
setnames(vg_data_subset, old = c('X1','X2', 'X3', 'X4', 'X5'), 
         new = c('unnorm mentions.b','norm mentions.b', 'norm & log mentions.b', 'no log sales', 'log sales'))
corr <- round(cor(vg_data_subset, method = c("pearson")), 2)
melted_cormat <- melt(corr)
ggplot(data = melted_cormat, aes(x=Var1, y=Var2, fill=value)) + geom_tile() +
  theme(axis.title.x=element_blank(), axis.title.y=element_blank()) + 
  geom_text(aes(label = value)) + scale_fill_gradient(low = "white", high = "red") +
  scale_x_discrete(position = "top") + ylim(rev(colnames(vg_data_subset))) 

######### ASSOCIATIONS B/W CATG AND DEPENDENT VARS #########  
# Categorical variables
catg_vars <- subset(vg_data, select=c("Genre", "Rating", "Publisher", "month"))
catg_vars <- apply(catg_vars, 2, factor)
model_data <- cbind(model_data, catg_vars)

catg_assocs <- data.frame(matrix(ncol = 1, nrow = 4))
# If r.squared > 0.5, then there's sufficient association, so select for regression
fit1 <- lm(log_model_data$sales ~ model_data$Genre); catg_assocs[1,1] <- sqrt(summary(fit1)$r.squared)
fit2 <- lm(log_model_data$sales ~ model_data$Rating); catg_assocs[2,1] <- sqrt(summary(fit2)$r.squared)
fit3 <- lm(log_model_data$sales ~ model_data$Publisher); catg_assocs[3,1] <- sqrt(summary(fit3)$r.squared)
fit4 <- lm(log_model_data$sales ~ model_data$month); catg_assocs[4,1] <- sqrt(summary(fit4)$r.squared)
rownames(catg_assocs) <- c("Genre","Rating","Publisher","Month")
colnames(catg_assocs) <- c("Corr Coef")
grid.newpage()  # prevent plots from overlapping
grid.table(round(catg_assocs, 3))

# Add selected catg vars to data to be fitted on
log_model_data$Publisher <- model_data$Publisher

### Try both removing and keeping outliers out of distr range and compare results
# outliers <- boxplot(log_model_data$sales)$out
# nrow(log_model_data[which(log_model_data$sales %in% outliers),])  #identify which samples are outliers
# log_model_data <- log_model_data[-which(log_model_data$sales %in% outliers),] #remove outliers
# nrow(log_model_data)
# outliers <- boxplot(log_model_data$sales)$out
# nrow(log_model_data[which(log_model_data$sales %in% outliers),])
# skewness(log_model_data$sales)
# hist(log_model_data$sales)

######### DESCRIPTIVE STATS AND SCATTER PLOTS #########  
# Make table of summary stats for selected numerical vars
vars_to_analyze <- subset(log_model_data, select=c("mentions_b", "User_Score", "Critic_Score", "sales"))
summary_vars <- round(apply(vars_to_analyze, 2, summary), 2)
grid.newpage()  # prevent plots from overlapping
grid.table(summary_vars) 

# SCATTER PLOTS for every pair of vars
pairs(vars_to_analyze)

ggplot(data = melted_cormat, aes(x=Var1, y=Var2, fill=value)) + geom_tile() +
  theme(axis.title.x=element_blank(), axis.title.y=element_blank()) + 
  geom_text(aes(label = value)) + scale_fill_gradient(low = "white", high = "red") +
  scale_x_discrete(position = "top") + ylim(rev(colnames(corr)))

plot(vars_to_analyze$mentions_b, vars_to_analyze$sales, xlab="Mentions.B", ylab="Sales")
abline(lm(sales ~ mentions_b, data=vars_to_analyze), col="red")
title(main = "Mentions.B vs Sales")

plot(vars_to_analyze$Critic_Score, vars_to_analyze$sales, xlab="Critic Score", ylab="Sales")
abline(lm(sales ~ Critic_Score, data=vars_to_analyze), col="red")
title(main = "Critic Score vs Sales")

par(mfrow = c(2, 2))  #next plots will be on 2x2 grid
boxplot_w_titles <- function(x, data, ...) {
  c(boxplot(data[[x]], main = names(data)[x], ...) )
}
l_ply(seq_len(ncol(vars_to_analyze)), boxplot_w_titles, data = vars_to_analyze)
par(mfrow=c(1,1))  #reset how plots are displayed

get_num_bp_outliers <- function(x) {
  return(length(boxplot(x)$out))
}
num_outliers <- data.frame(apply(vars_to_analyze, 2, get_num_bp_outliers))
colnames(num_outliers) <- c("Number of boxplot outliers")
grid.newpage(); grid.table(num_outliers)

######### RAND SPLIT DATA #########
vars_to_analyze$Publisher <- log_model_data$Publisher
set.seed(66)  #for sampling
sample_size <- floor(0.95*length(vars_to_analyze$sales))
in_train <- sample(seq_len(length(vars_to_analyze$sales)),size = sample_size)
train_data <- vars_to_analyze[in_train,]
test_data <- vars_to_analyze[-in_train,]
num_samples[5,1] <- nrow(train_data)
paste("# Training samples: ", nrow(train_data))

# train data must contain all levels that test data contains
paste("# Testing samples: ", nrow(test_data))
diff_publ <- setdiff(unique(test_data$Publisher), unique(train_data$Publisher))
for (pub in diff_publ){
  test_data <- test_data[test_data$Publisher != pub,  ]
}
paste("# Testing samples after removing samples w/ publ not in train: ", nrow(test_data))
setdiff(unique(test_data$Publisher), unique(train_data$Publisher))  #should be no diffs

######### Reduction Progress of # Samples in Examined Data ######### 
rownames(num_samples) <- c("Initial # of samples: ","# after rmv samples w/ no mentions:",
                           "# after rmv samples w/ NA scores:", "# after rmv samples w/ 'Game' in title ", 
                           "# Training samples: ")
colnames(num_samples) <- c("Num Samples after Rmv")
grid.newpage()  # prevent plots from overlapping
grid.table(num_samples)

######### LASSO AND MODEL SELECTION ######### 
lambda_seq <- 10^seq(2, -2, by = -.1)  #lambdas to try
x_train <- data.matrix(train_data[ , !(names(train_data) == "sales")])
y_train <- data.matrix(train_data$sales)
glm_out <- cv.glmnet(x_train, y_train, alpha = 1, lambda = lambda_seq, family = "gaussian") 
best_lam <- glm_out$lambda.min # best lambda, used to train better model
lasso_best <- glmnet(x_train, y_train, alpha = 1, lambda = best_lam)

betas <- round(coef(lasso_best), 2) #feature selection using coeffs
colnames(betas) <- c("Lasso beta coeffs")
grid.newpage()  # prevent plots from overlapping
grid.table(betas) 

#LASSO gives coeff of 0 to Publisher, indicating it should be dropped

x_test <- data.matrix(test_data[ , !(names(test_data) == "sales")])
preds <- data.matrix(predict(lasso_best, s = best_lam, newx = x_test))
actual <- data.matrix(test_data$sales)
test.mse <- mean(( preds - actual )^2)  #mse. Smaller is better.
ss.error <- sum(( preds - actual )^2)  # smaller is better
total.ss <- sum((actual - mean(actual)) ^ 2)
test.r.squared <- 1 - ss.error/total.ss  #higher is better

# test data estimates
test.mse
test.r.squared

# Comparing results if Publisher was not dropped
all_fit <- lm(sales ~ mentions_b + User_Score + Critic_Score + Publisher, data = train_data)
no_lasso_coeff <- round(head(data.frame(all_fit$coeff), 5), 2)
colnames(no_lasso_coeff) <- c("No Lasso Betas")
grid.newpage()  # prevent plots from overlapping
grid.table(no_lasso_coeff) 

# FINAL MODEL
fit <- lm(sales ~ mentions_b + User_Score + Critic_Score, data = train_data)
no_lasso_coeff <- round(head(data.frame(fit$coeff), 5), 2)
colnames(no_lasso_coeff) <- c("Final Model Betas")
grid.newpage()  # prevent plots from overlapping
grid.table(no_lasso_coeff) 

preds_intvs <- as.data.frame(predict(fit, newdata = test_data, 
                                     interval = "prediction", type="response"))
preds <- data.matrix(preds_intvs$fit)
actual <- data.matrix(test_data$sales)
test.mse <- mean(( preds - actual )^2)  #mse. Smaller is better.
ss.error <- sum(( preds - actual )^2)  # smaller is better
total.ss <- sum((actual - mean(actual)) ^ 2)
test.r.squared <- 1 - ss.error/total.ss  #higher is better

# test data estimates
test.mse
test.r.squared

# summary stats
summary(fit)

# indp var rankings
b <- summary(fit)$coef[2:4, 1]
sy <- apply(fit$model[1], 2, sd)
sx <- apply(fit$model[2:4], 2, sd)
final_std_betas <- b * (sx/sy)
final_std_betas <- sort(final_std_betas, decreasing = TRUE)
final_std_betas <- data.frame(round(final_std_betas, 2))
colnames(final_std_betas) <- c("Std. Coeff")
grid.newpage()  # prevent plots from overlapping
grid.table(final_std_betas)

#prediction points and intervals
preds_out <- round(cbind(test_data$sales, preds_intvs), 2)
colnames(preds_out) <- c("Actual", "Preds", "lower bound", "upper bound")
grid.newpage()  # prevent plots from overlapping
grid.table(head(preds_out, 10), rows=NULL)

######### FINAL MODEL ASSUMPTIONS CHECKING #########  
#PLOTS TO CHECK REGRESSION ASSUMPTIONS
autoplot(fit)

#Check Assmp 4: Errors should be independent. DW should be around 2.
dwtest(fit)
