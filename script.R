
################################################################################
######### Estimate and visualize expected Covid19 burden in Madagascar #########
############################ 03-31-2020 ########################################
################################################################################

setwd('/home/mbruijning/Dropbox/Work/Manuscripts/Covid19Madagascar/')

# load packages
require(raster)
require(rgdal)

################################################################################
##### Without age structure (just to test/explore)
# Load demographic data (combining all ages) (data from: https://www.worldpop.org/geodata/summary?id=6396)
mat <- raster('Data/mdg_ppp_2020.tif')

# Create new map with decreased resolution
decrReso <- 20
mat <- aggregate(mat,fact=decrReso,fun=sum)

# Plot results
plot(mat)
plot(log(mat))

# Mutiply with infection probability and overall mortality rate (currently just arbitary numbers)
pinf <- 0.4
pmort <- 0.05
plot(mat * pinf * pmort)


################################################################################
##### Including age structure
# load all datas (all datasets from https://www.worldpop.org/geodata/summary?id=16870)
# So far only including women!
allfiles <- as.list(list.files('Data/AgeSpecific',full.names=TRUE))
dat <- lapply(allfiles,raster)

# Decrease resolution (takes a while)
decrReso <- 10
dat <- lapply (dat,function(x) {
  mat <- aggregate(x,fact=decrReso,fun=sum)
  cat('Done \n')
  return(mat)
} )

# get age classes from file names
ageclasses <- unlist(lapply(dat,function(x) {
  a <- names(x)
  sub(".*_f_ *(.*?) *_.*", "\\1", a)
}))

# arbitrary linear age-specific mortalility (just to test! Replace with real estimates)
pmort <- matrix(NA,nrow=81,ncol=2)
colnames(pmort) <- c('Age','Mortality')
pmort[,1] <- 0:80
pmort[,2] <- 0.01 + pmort[,1]/100
pmortInc <- pmort[match(ageclasses,pmort[,1]),2] # age-specific mortality per file

# Numbers from: https://www.imperial.ac.uk/media/imperial-college/medicine/sph/ide/gida-fellowships/Imperial-College-COVID19-NPI-modelling-16-03-2020.pdf
# Table 1, column Infection Fatality Ratio
pmort <- matrix(ncol=3,nrow=9)
colnames(pmort) <- c('minage','maxage','fatality')
pmort[,1] <- seq(0,80,10)
pmort[,2] <- c(seq(9,80,10),120)
pmort[,3] <- c(0.00002,0.00006,0.0003,0.0008,0.0015,0.006,0.022,0.051,0.093)
# age-specific mortality per map
pmortInc <- sapply(as.numeric(ageclasses),function(x)
                   pmort[data.table::between(x,pmort[,1],pmort[,2]),3])
names(pmortInc) <- as.numeric(ageclasses)


# Infection probability
pinf <- 0.4

# Multiply age-specific pop density with age-specific mortality and infection probability
finalMap <- mapply(function(x,y) x*y*pinf,dat,pmortInc)
#plot(stack(finalMap)) # plot all maps
plot(finalMap[[1]]) # or just one of the maps

# Sum over age classes
sumMap <- Reduce('+', finalMap) # Total burden
plot(sumMap) ## Plot final burden
