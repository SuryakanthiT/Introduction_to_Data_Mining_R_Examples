#' ---
#' title: "R Code for Chapter 3 of Introduction to Data Mining: Classification: Basic Concepts and Techniques"
#' author: "Michael Hahsler"
#' output:
#'  html_document:
#'    toc: true
#' ---

#' This code covers chapter 3 of _"Introduction to Data Mining"_
#' by Pang-Ning Tan, Michael Steinbach and Vipin Kumar.
#' __See [table of contents](https://github.com/mhahsler/Introduction_to_Data_Mining_R_Examples#readme) for code examples for other chapters.__
#'
#' ![CC](https://i.creativecommons.org/l/by/4.0/88x31.png)
#' This work is licensed under the
#' [Creative Commons Attribution 4.0 International License](http://creativecommons.org/licenses/by/4.0/). For questions please contact
#' [Michael Hahsler](http://michael.hahsler.net).
#'

library(tidyverse)
library(ggplot2)

#' # Prepare Zoo Data Set
data(Zoo, package="mlbench")
head(Zoo)

#' _Note:_ data.frames in R can have row names. The Zoo data set uses the animal name as the row names. tibbles from `tidyverse` do not support row names. To keep the animal name you can add a column with the animal name.
as_tibble(Zoo, rownames = "animal")
#' You will have to remove the animal column before learning a model! In the following I use the data.frame.
#'
#'
#' I translate all the TRUE/FALSE values into factors (nominal). This is often needed for building models. Always check `summary()` to make sure the data is ready for model learning.
Zoo <- Zoo %>%
  modify_if(is.logical, factor, levels = c(TRUE, FALSE)) %>%
  modify_if(is.character, factor)
Zoo %>% summary()

#' # Decision Trees
#'
#' Recursive Partitioning (similar to CART) uses the Gini index to make
#' splitting decisions and early stopping (pre-pruning).

library(rpart)

#' ## Create Tree With Default Settings (uses pre-pruning)
tree_default <- Zoo %>% rpart(type ~ ., data = .)
tree_default



#' __Notes:__
#' - `%>%` supplies the data for `rpart`. Since `data` is not the first argument of `rpart`, the syntax `data = .` is used to specify where the data in `Zoo` goes. The call is equivalent to `tree_default <- rpart(type ~ ., data = Zoo)`.
#' - The formula models the `type` variable by all other features represented by `.`. `data = .`
#'   means that the data provided by the pipe (`%>%`) will be passed to rpart as the
#'   argument `data`.
#'
#' - the class variable needs a factor (nominal) or rpart
#'   will create a regression tree instead of a decision tree. Use `as.factor()`
#'   if necessary.
#'
#' Plotting

library(rpart.plot)
rpart.plot(tree_default, extra = 2)

#' _Note:_ `extra=2` prints for each leaf node the number of correctly
#' classified objects from data and the total number of objects
#' from the training data falling into that node (correct/total).
#'
#' ## Create a Full Tree
#'
#' To create a full tree, we set the complexity parameter cp to 0 (split even
#' if it does not improve the tree) and we set the minimum number of
#' observations in a node needed to split to the smallest value of 2
#' (see: `?rpart.control`).
#' _Note:_ full trees overfit the training data!
tree_full <- Zoo %>% rpart(type ~., data = ., control = rpart.control(minsplit = 2, cp = 0))
rpart.plot(tree_full, extra = 2, roundint=FALSE)
tree_full

#' Training error on tree with pre-pruning
predict(tree_default, Zoo) %>% head ()

pred <- predict(tree_default, Zoo, type="class")
head(pred)

confusion_table <- with(Zoo, table(type, pred))
confusion_table

correct <- confusion_table %>% diag() %>% sum()
correct
error <- confusion_table %>% sum() - correct
error

accuracy <- correct / (correct + error)
accuracy

#' Use a function for accuracy
accuracy <- function(truth, prediction) {
    tbl <- table(truth, prediction)
    sum(diag(tbl))/sum(tbl)
}

accuracy(Zoo %>% pull(type), pred)

#' Training error of the full tree
accuracy(Zoo %>% pull(type), predict(tree_full, Zoo, type="class"))

#' Get a confusion table with more statistics (using caret)
library(caret)
confusionMatrix(data = pred, reference = Zoo %>% pull(type))

#' ## Make Predictions for New Data
#'
#' Make up my own animal: A lion with feathered wings

my_animal <- tibble(hair = TRUE, feathers = TRUE, eggs = FALSE,
  milk = TRUE, airborne = TRUE, aquatic = FALSE, predator = TRUE,
  toothed = TRUE, backbone = TRUE, breathes = TRUE, venomous = FALSE,
  fins = FALSE, legs = 4, tail = TRUE, domestic = FALSE,
  catsize = FALSE, type = NA)

#' Fix columns to be factors like in the training set.
my_animal <- my_animal %>% modify_if(is.logical, factor, levels = c(TRUE, FALSE))
my_animal

#' Make a prediction using the default tree
predict(tree_default , my_animal, type = "class")

#' # Model Evaluation with Caret
#'
#' see http://cran.r-project.org/web/packages/caret/vignettes/caret.pdf
library(caret)

#' Cross-validation runs are independent and can be done in parallel. We need to enable multi-core support for `caret` using packages `foreach` and `doParallel`.
library(doParallel)
registerDoParallel()
getDoParWorkers()
#'
#' ## Hold out test data
#'
#' Partition data 80%/20%.
inTrain <- createDataPartition(y = Zoo$type, p = .8, list = FALSE)
training <- Zoo %>% slice(inTrain)
testing <- Zoo %>% slice(-inTrain)

#'
#' ## Learn model and tune hyperparameters
#'
#' caret packages training and validation for hyperparameter tuning into a single function called `train()`.
#' It internally splits the data into training and validation sets and thus will
#' provide you with error estimates for different hyperparameter settings. `trainControl` is used
#' to choose how testing is performed.
#'
#' For rpart, train tries to tune the cp parameter (tree complexity)
#' using accuracy to chose the best model. I set minsplit to 2 since we have
#' not much data.
#' __Note:__ Parameters used for tuning (in this case `cp`) need to be set using
#' a data.frame in the argument `tuneGrid`! Setting it in control will be ignored.
fit <- training %>%
  train(type ~ .,
    data = . ,
    method = "rpart",
    control = rpart.control(minsplit = 2),
    trControl = trainControl(method = "cv", number = 10),
    tuneLength = 5)
fit
#' __Note:__ Train has built 10 trees and the reported values for accuracy and Kappa are the averages.

ggplot(fit)

#' A model using the best tuning parameters
#' and using all the data supplied to `train()` is available as `fit$finalModel`.

rpart.plot(fit$finalModel, extra = 2)

#' caret also computes variable importance. By default it uses competing splits
#' (splits which would be runners up, but do not get chosen by the tree)
#' for rpart models (see `? varImp`). Toothed is the
#' runner up for many splits, but it never gets chosen!
varImp(fit)

#' Here is the variable importance without competing splits.
imp <- varImp(fit, compete = FALSE)
imp
ggplot(imp)

#' __Note:__ Not all models provide a variable importance function. In this case caret might calculate varImp by itself and ignore the model (see `? varImp`)!

#'
#' ## Testing: Confusion Matrix and Confidence Interval for Accuracy
#'
#' Use the best model on the test data
pred <- predict(fit, newdata = testing)
head(pred)
#'
#' Caret's `confusionMatrix()` function calculates accuracy, confidence intervals, kappa and many more evaluation metrics. You need to use separate test data to create a confusion matrix based on the generalization error.
confusionMatrix(data = pred, ref = testing$type)

#'
#' __Some notes__
#'
#' * Many classification algorithms and `train` in caret do not deal well
#'   with missing values.
#'   If your classification model can deal with missing values (e.g., `rpart`) then use `na.action = na.pass` when you call `train` and `predict`.
#'   Otherwise, you need to remove observations with missing values with
#'   `na.omit` or use imputation to replace the missing values before you train the model. Make sure that
#'   you still have enough observations left.
#' * Make sure that nominal variables (this includes logical variables)
#'   are coded as factors.
#' * The class variable for train in caret cannot have level names that are
#'   keywords in R (e.g., `TRUE` and `FALSE`). Rename them to, for example,
#'    "yes" and "no."
#' * Make sure that nominal variables (factors) have examples for all possible
#'   values. Some methods might have problems with variable values
#'   without examples. You can drop empty levels using `droplevels` or `factor`.
#' * Sampling in train might create a sample that does not
#'   contain examples for all values in a nominal (factor) variable. You will get
#'   an error message. This most
#'   likely happens for variables which have one very rare value. You may have to
#'   remove the variable.
#'
#' # Model Comparison
#'
#' We will compare decision trees with a k-nearest neighbors (kNN) classifier.
library(caret)

#' Create fixed sampling scheme (10-folds) so we compare the different models
#' using exactly the same folds. It iis specified as `trControl` during training.
train <- createFolds(Zoo$type, k = 10)

#' Build models
rpartFit <- Zoo %>% train(type ~ .,
  data = .,
  method = "rpart",
  tuneLength = 10,
  trControl = trainControl(method = "cv", indexOut = train)
  )

#' __Note:__ for kNN you might want to scale the data first. Logicals will
#' be used as 0-1 variables in Euclidean distance calculation.
knnFit <- Zoo %>% train(type ~ .,
  data = .,
  method = "knn",
	tuneLength = 10,
	trControl = trainControl(method = "cv", indexOut = train)
  )

#' Compare accuracy
resamps <- resamples(list(
		CART = rpartFit,
		kNearestNeighbors = knnFit
		))
summary(resamps)

#' Plot the accuracy of the two models for each resampling (e.g., fold). If the
#' models are the same then all points will fall on the diagonal.
xyplot(resamps)
#'
#' Find out if one models is statistically better than the other (is
#' the difference in accuracy is not zero).
difs <- diff(resamps)
difs
summary(difs)
#' p-values tells you the probability of seeing an even more extreme value (difference between accuracy) given that the null hypothesis (difference = 0) is true. For a better classifier p-value should be less than .05 or 0.01. `diff` automatically applies Bonferroni correction for multiple comparisons. In this case, the classifiers do not perform statistically differently.
#'
#' # Feature Selection and Feature Preparation

#' Decision trees implicitly select features for splitting, but we can also
#' select features manually.
library(FSelector)
#' see: http://en.wikibooks.org/wiki/Data_Mining_Algorithms_In_R/Dimensionality_Reduction/Feature_Selection#The_Feature_Ranking_Approach
#'
#' ## Univariate Feature Importance Score
#' These scores measure how related
#' each feature is to the class variable.
#' For discrete features (as in our case), the chi-square statistic can be used
#' to derive a score.
weights <- training %>% chi.squared(type ~ ., data = .) %>%
  as_tibble(rownames = "feature") %>%
  arrange(desc(attr_importance))
weights


#' plot importance in descending order (using `reorder` to order factor levels used by `ggplot`).
ggplot(weights,
  aes(x = attr_importance, y = reorder(feature, attr_importance))) +
  geom_bar(stat = "identity") +
  xlab("Importance score") + ylab("Feature")

#' Get the 5 best features
subset <- cutoff.k(weights %>% column_to_rownames("feature"), 5)
subset

#' Use only the best 5 features to build a model (`Fselector` provides `as.simple.formula`)
f <- as.simple.formula(subset, "type")
f

m <- training %>% rpart(f, data = .)
rpart.plot(m, extra = 2, roundint=FALSE)

#' There are many alternative ways to calculate univariate importance
#' scores (see package FSelector). Some of them (also) work for continuous
#' features. One example is the information gain ratio based on entropy as used in decision tree induction.
training %>% gain.ratio(type ~ ., data = .) %>%
  as_tibble(rownames = "feature") %>%
  arrange(desc(attr_importance))


#' ## Feature Subset Selection
#' Often features are related and calculating importance for each feature
#' independently is not optimal. We can use greedy search heuristics. For
#' example `cfs` uses correlation/entropy with best first search.
training %>% cfs(type ~ ., data = .)

#' Black-box feature selection uses an evaluator function (the black box)
#' to calculate a score to be maximized.
#' First, we define an evaluation function that builds a model given a subset
#' of features and calculates a quality score. We use here the
#' average for 5 bootstrap samples (`method = "cv"` can also be used instead), no tuning (to be faster), and the
#' average accuracy as the score.
evaluator <- function(subset) {
  model <- training %>% train(as.simple.formula(subset, "type"),
    data = ., method = "rpart",
    trControl = trainControl(method = "boot", number = 5),
    tuneLength = 0)
  results <- model$resample$Accuracy
  cat("Trying features:", paste(subset, collapse = " + "), "\n")
  m <- mean(results)
  cat("Accuracy:", round(m, 2), "\n\n")
  m
}

#' Start with all features (but not the class variable `type`)
features <- training %>% colnames() %>% setdiff("type")

#' There are several (greedy) search strategies available. These run
#' for a while!
#subset <- backward.search(features, evaluator)
#subset <- forward.search(features, evaluator)
#subset <- best.first.search(features, evaluator)
#subset <- hill.climbing.search(features, evaluator)
#subset

#'
#' ## Using Dummy Variables for Factors
#'
#' Nominal features (factors) are often encoded as a series of 0-1 dummy variables.
#' For example, let us try to predict if an animal is a predator given the type.
#' First we use the original encoding of type as a factor with several values.

tree_predator <- training %>% rpart(predator ~ type, data = .)
rpart.plot(tree_predator, extra = 2, roundint = FALSE)

#' __Note:__ Some splits use multiple values. Building the tree will become
#' extremely slow if a factor has many levels (different values) since the tree has to check all possible splits into two subsets. This situation should be avoided.
#'
#' Recode type as a set of 0-1 dummy variables using `class2ind`. See also
#' `? dummyVars` in package `caret`.
library(caret)
training_dummy <- as_tibble(class2ind(training$type)) %>% mutate_all(as.factor) %>%
  add_column(predator = training$predator)
training_dummy

tree_predator <- training_dummy %>% rpart(predator ~ ., data = .,
  control = rpart.control(minsplit = 2, cp = 0.01))
rpart.plot(tree_predator, extra = 2, roundint = FALSE)

#' Using `caret` on the original factor encoding automatically translates factors
#' (here type) into 0-1 dummy variables (e.g., `typeinsect = 0`).
#' The reason is that some models cannot
#' directly use factors and `caret` tries to consistently work with
#' all of them.
fit <- training %>% train(predator ~ type, data = ., method = "rpart",
  control = rpart.control(minsplit = 2),
  tuneGrid = data.frame(cp = 0.01))
fit

rpart.plot(fit$finalModel, extra = 2)
#' _Note:_ To use a fixed value for the tuning parameter `cp`, we have to
#' create a tuning grid that only contains that value.
#'
#' # Class Imbalance
#'
#' Classifiers have a hard time to learn from data where we have much more observations for one class (called the majority class). This is called the class imbalance problem.
#'
#' Here is a very good [article about the problem and solutions.](http://www.kdnuggets.com/2016/08/learning-from-imbalanced-classes.html)
#'
library(rpart)
library(rpart.plot)
data(Zoo, package="mlbench")

#' Class distribution
ggplot(Zoo, aes(y = type)) + geom_bar()

#' To create an imbalanced problem, we want to decide if an animal is an reptile.
#' First, we change the class variable
#' to make it into a binary reptile/no reptile classification problem.
#' __Note:__ We use here the training data for testing. You should use a
#' separate testing data set!

Zoo_reptile <- Zoo %>% mutate(
  type = factor(Zoo$type == "reptile", levels = c(FALSE, TRUE),
    labels = c("nonreptile", "reptile")))

#' Do not forget to make the class variable a factor (a nominal variable)
#' or you will get a regression tree instead of a classification tree.

summary(Zoo_reptile)

#' See if we have a class imbalance problem.
ggplot(Zoo_reptile, aes(y = type)) + geom_bar()

#' Create test and training data. I use here a 50/50 split to make sure that the test set has some samples of the rare reptile class.
set.seed(1234)
inTrain <- createDataPartition(y = Zoo_reptile$type, p = .5, list = FALSE)
training_reptile <- Zoo_reptile %>% slice(inTrain)
testing_reptile <- Zoo_reptile %>% slice(-inTrain)

#' the new class variable is clearly not balanced. This is a problem
#' for building a tree!
#'
#' ## Option 1: Use the Data As Is and Hope For The Best

fit <- training_reptile %>% train(type ~ .,
  data = .,
  method = "rpart",
  trControl = trainControl(method = "cv"))
#'__Warnings:__ "There were missing values in resampled performance measures."
#'means that some test folds did not contain examples of both classes.
#'This is very likely with class imbalance and small datasets.

fit
rpart.plot(fit$finalModel, extra = 2)
#' the tree predicts everything as non-reptile. Have a look at the error on
#' the training set.

confusionMatrix(data = predict(fit, testing_reptile),
  ref = testing_reptile$type, positive = "reptile")
#' The accuracy is exactly the same as the no-information rate
#' and kappa is zero. Sensitivity is also zero, meaning that we do not identify
#' any positive (reptile). If the cost of missing a positive is much
#' larger than the cost associated with misclassifying a negative, then accuracy
#' is not a good measure!
#' By dealing with imbalance, we are __not__ concerned
#' with accuracy, but we want to increase the
#' sensitivity, i.e., the chance to identify positive examples.
#'
#' __Note:__ The positive class value (the one that
#' you want to detect) is set manually to reptile.
#' Otherwise sensitivity/specificity will not be correctly calculated.
#'
#' ## Option 2: Balance Data With Resampling
#'
#' We use stratified sampling with replacement (to oversample the
#' minority/positive class).
#' You could also use SMOTE (in package __DMwR__) or other sampling strategies (e.g., from package __unbalanced__). We
#' use 50+50 observations here (__Note:__ many samples will be chosen several times).
library(sampling)
set.seed(1000) # for repeatability

id <- strata(training_reptile, stratanames = "type", size = c(50, 50), method = "srswr")
training_reptile_balanced <- training_reptile %>% slice(id$ID_unit)
table(training_reptile_balanced$type)

fit <- training_reptile_balanced %>% train(type ~ .,
  data = .,
  method = "rpart",
  trControl = trainControl(method = "cv"),
  control = rpart.control(minsplit = 5))
fit
rpart.plot(fit$finalModel, extra = 2)

#' Check on the unbalanced testing data.
confusionMatrix(data = predict(fit, testing_reptile),
  ref = testing_reptile$type, positive = "reptile")

#' __Note__ that the accuracy is below the no information rate!
#' However, kappa (improvement of accuracy over randomness) and
#' sensitivity (the ability to identify reptiles) have increased.
#'
#' There is a tradeoff between sensitivity and specificity (how many of the identified animals are really reptiles)
#' The tradeoff can be controlled using the sample
#' proportions. We can sample more reptiles to increase sensitivity at the cost of
#' lower specificity.

id <- strata(training_reptile, stratanames = "type", size = c(50, 100), method = "srswr")
training_reptile_balanced <- training_reptile %>% slice(id$ID_unit)
table(training_reptile_balanced$type)

fit <- training_reptile_balanced %>% train(type ~ .,
  data = .,
  method = "rpart",
  trControl = trainControl(method = "cv"),
  control = rpart.control(minsplit = 5))

confusionMatrix(data = predict(fit, testing_reptile),
  ref = testing_reptile$type, positive = "reptile")


#' ## Option 3: Build A Larger Tree and use Predicted Probabilities
#'
#' Increase complexity and require less data for splitting a node.
#' Here I also use AUC (area under the ROC) as the tuning metric.
#' You need to specify the two class
#' summary function. Note that the tree still trying to improve accuracy on the
#' data and not AUC! I also enable class probabilities since I want to predict
#' probabilities later.

fit <- training_reptile %>% train(type ~ .,
  data = .,
  method = "rpart",
  tuneLength = 10,
  trControl = trainControl(method = "cv",
    classProbs = TRUE,                 ## necessary for predict with type="prob"
    summaryFunction=twoClassSummary),  ## necessary for ROC
  metric = "ROC",
  control = rpart.control(minsplit = 3))
fit

rpart.plot(fit$finalModel, extra = 2)

confusionMatrix(data = predict(fit, testing_reptile),
  ref = testing_reptile$type, positive = "reptile")
#' __Note:__ Accuracy is high, but it is close or below to the no-information rate!
#'
#' ### Create A Biased Classifier
#'
#' We can create a classifier which will detect more reptiles
#' at the expense of misclassifying non-reptiles. This is equivalent
#' to increasing the cost of misclassifying a reptile as a non-reptile.
#' The usual rule is to predict in each node
#' the majority class from the test data in the node.
#' For a binary classification problem that means a probability of >50%.
#' In the following, we reduce this threshold to 1% or more.
#' This means that if the new observation ends up in a leaf node with 1% or
#'  more reptiles from training then the observation
#'  will be classified as a reptile.
#'  The data set is small and this works better with more data.
#'
prob <- predict(fit, testing_reptile, type = "prob")
tail(prob)
pred <- as.factor(ifelse(prob[,"reptile"]>=0.01, "reptile", "nonreptile"))

confusionMatrix(data = pred,
  ref = testing_reptile$type, positive = "reptile")
#' __Note__ that accuracy goes down and is below the no information rate.
#' However, both measures are based on the idea that all errors have the same
#' cost. What is important is that we are now able to find more
#' reptiles.
#'

#' ### Plot the ROC Curve
#' Since we have a binary classification problem and a classifier that predicts
#' a probability for an observation to be a reptile, we can also use a
#' [receiver operating characteristic (ROC)](https://en.wikipedia.org/wiki/Receiver_operating_characteristic)
#' curve. For the ROC curve all different cutoff thresholds for the probability
#' are used and then connected with a line.
library("pROC")
r <- roc(testing_reptile$type == "reptile", prob[,"reptile"])
r

plot(r)
#' This also reports the area under the curve.
#'

#' ## Option 4: Use a Cost-Sensitive Classifier
#'
#' The implementation of CART in `rpart` can use a cost matrix for making splitting
#' decisions (as parameter `loss`). The matrix has the form
#'
#'  TP FP
#'  FN TN
#'
#' TP and TN have to be 0. We make FN very expensive (100).

cost <- matrix(c(
  0,   1,
  100, 0
), byrow = TRUE, nrow = 2)
cost


fit <- training_reptile %>% train(type ~ .,
  data = .,
  method = "rpart",
  parms = list(loss = cost),
  trControl = trainControl(method = "cv"))
#' The warning "There were missing values in resampled performance measures"
#' means that some folds did not contain any reptiles (because of the class imbalance)
#' and thus the performance measures could not be calculates.

fit

rpart.plot(fit$finalModel, extra = 2)

confusionMatrix(data = predict(fit, testing_reptile),
  ref = testing_reptile$type, positive = "reptile")
#' The high cost for false negatives results in a classifier that does not miss any reptile.
#'
#' __Note:__ Using a cost-sensitive classifier is often the best option. Unfortunately, the most classification algorithms (or their implementation) do not have the ability to consider misclassification cost.
