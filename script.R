
################################################################################
######### Estimate and visualize expected Covid19 burden in Madagascar #########
############################ 03-31-2020 ########################################
################################################################################

setwd('/home/mbruijning/Dropbox/Work/Manuscripts/Covid19Africa/')

# load packages
require(raster)
require(rgdal)

################################################################################
# Load data
## Maybe somehow incorporate this code into africa_10x10.R code, or replace parts?
allfiles <- as.list(list.files('wp_data/africa_10km_2020',full.names=TRUE))

## Use Mal's maps and combine into one brick file
dat <- lapply(allfiles,raster)
namess <- lapply(dat,names) # file names
uniquenames <- substr(namess,6,21) # exl gender

# Sum M + F
datsubs <- list()
for (i in 1:14) {
  datsubs[[i]] <- dat[[i]] + dat[[which(uniquenames == uniquenames[i])[2]]]
}

agelower <- substr(namess[1:14],8,9)
ageupper <- substr(namess[1:14],10,11)
ageclasses <- as.numeric(agelower) + 2
names(datsubs) <- paste(agelower,ageupper)

dat <- brick(datsubs)
# save output
writeRaster(dat, filename='demoMapAfrica2020.tif', format="GTiff",
             overwrite=TRUE,options=c("INTERLEAVE=BAND","COMPRESS=LZW"))


########################################################
## Run analysis and create plots 
## (functions/calculations used for Shinyapp)
######## Put all of this in a separate file, which we can load to run the subsequent analysis / plots?
########################################################

## Load data and input
dat <- brick('demoMapAfrica2020.tif')
admin0 <- readOGR("shapefiles/country.shp")
admin1 <- readOGR("shapefiles/admin1.shp")

## Calculate CFR per age class
age.upper <- c(9, 19, 29, 39, 49, 59, 69, 79, 89)
N.cases <- c(416, 549, 3619, 7600, 8571, 10008, 8583, 3918, 1408)
N.deaths <- c(0, 1, 7, 18, 38, 130, 309, 312, 208)
CFR <- N.deaths/N.cases
fit.cfr <- smooth.spline(age.upper - 4.5, (N.deaths/ N.cases)) # mid-point of age bracket & cases/deaths

## age classes from data
# (dput from matrix created above)
ageclasses <- structure(c(0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60,
                              65, 4, 9, 14, 19, 24, 29, 34, 39, 44, 49, 54, 59, 64, NA), .Dim = c(14L,
                              2L))
ageclasses <- matrix(NA,ncol=2,nrow=length(agelower))
ageclasses[,1] <- as.numeric(agelower)
ageclasses[,2] <- as.numeric(ageupper)
cfr <- pmax(predict(fit.cfr, ageclasses[,1] + 2.5)$y, 0) ## predict age-specific mortality

countries <- c("All","Algeria", "Angola", "Benin", "Botswana", "Burkina Faso", "Burundi",
                   "Cameroon", "Cape Verde", "Central African Republic", "Chad",
                   "Comoros", "Congo", "Cte d'Ivoire", "Democratic Republic of the Congo",
                   "Djibouti", "Egypt", "Equatorial Guinea", "Eritrea", "Ethiopia",
                   "Gabon", "Gambia", "Ghana", "Guinea", "Guinea-Bissau", "Kenya",
                   "Lesotho", "Liberia", "Libya", "Madagascar", "Malawi", "Mali",
                   "Mauritania", "Mauritius", "Mayotte", "Morocco", "Mozambique",
                   "Namibia", "Niger", "Nigeria", "Runion", "Rwanda", "Saint Helena",
                   "Sao Tome And Principe", "Senegal", "Seychelles", "Sierra Leone",
                   "Somalia", "South Africa", "South Sudan", "Sudan", "Swaziland",
                   "Tanzania", "Togo", "Tunisia", "Uganda", "Western Sahara", "Zambia",
                   "Zimbabwe")



#########################
## Maybe we don't need to match this code fully, but at least make sure that we calculate things in the same way?
## Do calculations
## User input
input <- list()
input$age <- 99 # corresponds to rows in matrix ageclasses; 99 for 'all' ageclasses
input$country <- 1 # corresponds to vector countries
input$pinf <- 0.4 # cumulative infection
input$log <- TRUE

countryname <- countries[as.numeric(input$country)]
if (countryname == 'All') {
  countrysubs <- dat
} else {
  countrysubs <- mask(dat, admin1[admin1$name_0 == countryname,])
  countrysubs <- crop(countrysubs,admin1[admin1$name_0 == countryname,])
}

if (input$age == '99') {  # if all age classes
  y <- countrysubs * cfr * input$pinf # multiply each age class with cfr
  y <- calc(y,sum)

} else { # for one age class
  y <- countrysubs[[as.numeric(input$age)]] * input$pinf * cfr[as.numeric(input$age)]
}

if (input$log == TRUE) {y <- log10(y)}

# create plot
cols <- c('#ffffcc','#ffeda0','#fed976','#feb24c','#fd8d3c','#fc4e2a','#e31a1c','#bd0026','#800026')
plot(y,
    main=paste0('Country overview: ',countryname),
    bty='n',xaxs="i", yaxs="i",box=FALSE,col=cols,xlab='X',ylab='Y')
 plot(admin1[admin1$name_0 == countryname,],add=TRUE)
 plot(admin0,add=TRUE)

