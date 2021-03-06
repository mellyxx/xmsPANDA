varimp_parallel <-
function (object, mincriterion = 0, conditional = FALSE, threshold = 0.2,
                           nperm = 1, OOB = TRUE, pre1.0_0 = conditional)
{
  response <- object@responses
  if (length(response@variables) == 1 && inherits(response@variables[[1]],
                                                  "Surv"))
    return(varimpsurv(object, mincriterion, conditional,
                      threshold, nperm, OOB, pre1.0_0))
  input <- object@data@get("input")
  xnames <- colnames(input)
  inp <- initVariableFrame(input, trafo = NULL)
  y <- object@responses@variables[[1]]
  if (length(response@variables) != 1)
    stop("cannot compute variable importance measure for multivariate response")
  if (conditional || pre1.0_0) {
    if (!all(complete.cases(inp@variables)))
      stop("cannot compute variable importance measure with missing values")
  }
  CLASS <- all(response@is_nominal)
  ORDERED <- all(response@is_ordinal)
  if (CLASS) {
    error <- function(x, oob) mean((levels(y)[sapply(x, which.max)] !=
                                      y)[oob])
  }
  else {
    if (ORDERED) {
      error <- function(x, oob) mean((sapply(x, which.max) !=
                                        y)[oob])
    }
    else {
      error <- function(x, oob) mean((unlist(x) - y)[oob]^2)
    }
  }
  w <- object@initweights
  if (max(abs(w - 1)) > sqrt(.Machine$double.eps))
    warning(sQuote("varimp"), " with non-unity weights might give misleading results")
  perror <- matrix(0, nrow = nperm * length(object@ensemble),
                   ncol = length(xnames))
  colnames(perror) <- xnames
  
  l1<-lapply(1:length(object@ensemble),function(b){
    # for (b in 1:length(object@ensemble)) {
    tree <- object@ensemble[[b]]
    if (OOB) {
      oob <- object@weights[[b]] == 0
    }
    else {
      oob <- rep(TRUE, length(y))
    }
    p <- predict(tree, inp, mincriterion, -1L)
    eoob <- error(p, oob)
    #for (j in unique(varIDs(tree))) {
    l2<-lapply(unique(varIDs(tree)),function(j){
      for (per in 1:nperm) {
        if (conditional || pre1.0_0) {
          tmp <- inp
          ccl <- create_cond_list(conditional, threshold,
                                  xnames[j], input)
          if (length(ccl) < 1) {
            perm <- sample(which(oob))
          }
          else {
            perm <- conditional_perm(ccl, xnames, input,
                                     tree, oob)
          }
          tmp@variables[[j]][which(oob)] <- tmp@variables[[j]][perm]
          p <- predict(tree, tmp, mincriterion, -1L)
        }
        else {
          p <- predict(tree, inp, mincriterion, as.integer(j))
        }
        #perror[(per + (b - 1) * nperm), j] <- (error(p,oob) - eoob)
        perror[(per), j] <- (error(p,oob) - eoob)
      }
      return(perror)
    })
    perror<-ldply(l2,rbind)
    return(perror)
  })
  perror<-ldply(l1,rbind)
  perror <- as.data.frame(perror)
  return(MeanDecreaseAccuracy = colMeans(perror))
}
