
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

# Create empty raster with decreased resolution (decrReso times)
decrReso <- 20
mat2 <- raster(nrow=round(nrow(mat)/decrReso),ncol=round(ncol(mat)/decrReso))

# Assign same properties
crs(mat2) <- crs(mat) # coordinate reference system
extent(mat2) <- extent(mat) # ranges

# Create new map with decreased resolution
mat <- resample(mat,mat2)

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
allfiles <- as.list(list.files('Data/AgeSpecific',full.names=TRUE))
dat <- lapply(allfiles,raster)

# Decrease resolution (takes a while)
dat <- lapply (dat,function(x) {

  # Create empty raster with decreased resolution (decrReso times)
  decrReso <- 100
  mat2 <- raster(nrow=round(nrow(x)/decrReso),ncol=round(ncol(x)/decrReso))

  # Assign same properties
  crs(mat2) <- crs(x) # coordinate reference system
  extent(mat2) <- extent(x) # ranges

  # Create new map with decreased resolution
  return(resample(x,mat2))

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

# age-specific mortality per file
pmortInc <- pmort[match(ageclasses,pmort[,1]),2]

# Infection probability
pinf <- 0.4

# Multiply age-specific pop density with age-specific mortality and infection probability
finalMap <- mapply(function(x,y) x*y*pinf,dat,pmortInc)
#plot(stack(finalMap)) # plot all maps
plot(finalMap[[1]]) # or just one of the maps

# Sum over age classes
sumMap <- Reduce('+', finalMap) # Total burden
plot(sumMap) ## Plot final burden
