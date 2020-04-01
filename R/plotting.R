# ------------------------------------------------------------------------------------------------ #
#' Plotting age cfrs using output data tables                                                                               
# ------------------------------------------------------------------------------------------------ #

library(raster)
library(ggplot2)
library(rgdal)
library(data.table)
library(dplyr)

# Calculating cfrs ----------------------------------------------------------------------------
# Per Jess
age.upper <- c(9, 19, 29, 39, 49, 59, 69, 79, 89)
N.cases <- c(416, 549, 3619, 7600, 8571, 10008, 8583, 3918, 1408)
N.deaths <- c(0, 1, 7, 18, 38, 130, 309, 312, 208)
CFR <- N.deaths/N.cases
fit.cfr <- smooth.spline(age.upper - 4.5, (N.deaths/ N.cases)) # mid-point of age bracket & cases/deaths
p_infected <- 0.4 # 40% cummulative infections

# Madagascar ----------------------------------------------------------------------------------
# read in data
mada_grid <- fread("output/mada_dt.gz")

# take midpoint of our age brackets for mada data @ 1x1
age_lower <- sort(as.numeric(names(mada_grid)[!is.na(as.numeric(names(mada_grid)))]))
age_upper <- age_lower + diff(age_lower)
age_upper[age_upper == 81] <- 89 # set the last age bracket to be 80 - 89
mid_pt <- (age_upper + age_lower)/2
cfr <- pmax(predict(fit.cfr, mid_pt)$y, 0)
names(cfr) <- age_lower

# set order by cell_id for matching to raster
setorder(mada_grid, cell_id)

# sanity checks
check_inf <- mada_grid[, Map("*", .SD, cfr*p_infected), .SDcols = as.character(age_lower)]
check_pop <- mada_grid[, as.character(age_lower), with = FALSE]
plot(colSums(check_inf, na.rm = TRUE)/colSums(check_pop, na.rm = TRUE))
points(cfr*p_infected, col = "blue") 
sum(colSums(check_pop, na.rm = TRUE)) # ~ 27 million people
order_check <- check_pop$`0` == mada_grid$`0` # spot check id order stayed the same
length(order_check[!is.na(order_check) & order_check == FALSE]) # should be zero

# Plotting deaths
mada_deaths <- copy(mada_grid)
mada_deaths <- mada_deaths[, (as.character(age_lower)) :=  Map("*", .SD, cfr*p_infected), 
                           .SDcols = as.character(age_lower)]
mada_deaths$deaths_total <- rowSums(mada_deaths[, as.character(age_lower), with = FALSE], na.rm = TRUE)


# Raster 
mada_base <- raster("wp_data/mada_1x1km_2020/mdg_f_0_2020_1x1.tif")
values(mada_base) <- 1:ncell(mada_base) # get cell id
names(mada_base) <- "cell_id"
mada_base <- as.data.table(as.data.frame(mada_base, xy = TRUE))
mada_base <- mada_base[mada_deaths, on = "cell_id"]
mada_base$deaths_total[mada_base$deaths_total == 0] <- NA

# right now just where people are!
raster <- ggplot() + 
  geom_raster(data = mada_base, aes(x = x, y = y, 
                                       fill = deaths_total)) + 
  scale_fill_distiller(na.value = NA, palette = "PuRd", direction = 1, 
                       trans = "sqrt", name = "Estimated burden") +
  coord_quickmap()
ggsave("figs/mada_deaths_grid.jpeg", raster, height = 7, width = 5)

# Admin 3
mada_admin3 <- mada_base[, lapply(.SD, sum, na.rm = TRUE), 
                         .SDcols = c(as.character(age_lower), "deaths_total"), 
                         by = c("admin3_code")]
mada_admin3$admin3_code <- as.character(mada_admin3$admin3_code)
admin3 <- readOGR("shapefiles/admin3_simple/admin3.shp")
admin3 <- admin3[admin3$iso == "MDG", ]
gg_admin3 <- fortify(admin3, region = "id_3")
gg_admin3 %>%
  left_join(mada_admin3, by = c("id" = "admin3_code")) -> gg_admin3

mada_deaths_admin3 <- ggplot() +
  geom_polygon(data = gg_admin3, aes(x = long, y = lat, group = group, 
                                     fill = deaths_total)) + 
  scale_fill_distiller(na.value = NA, palette = "PuRd", direction = 1, name = "Estimated burden") +
  coord_quickmap()
ggsave("figs/mada_deaths_admin3.jpeg", mada_deaths_admin3, height = 7, width = 5)

# Africa ----------------------------------------------------------------------------------
afr_grid <- fread("output/afr_dt.gz")
  
# take midpoint of our age brackets for afr data
age_lower <- seq(0, 65, by = 5)
age_upper <- age_lower + 4
age_upper[age_upper == max(age_upper)] <- 85 # set this age bracket higher to capture higher mortality
mid_pt <- (age_lower + age_upper)/2
cfr <- pmax(predict(fit.cfr, mid_pt)$y, 0)
names(cfr) <- c("A0004", "A0509", "A1014", "A1519", "A2024", "A2529", "A3034", "A3539", "A4044",
                "A4549", "A5054", "A5559", "A6064", "A65PL") # names should match colnames!
p_infected <- 0.4 # 40% cummulative infections

# set order by cell_id for matching to raster
setorder(afr_grid, cell_id)

# sanity checks
check_inf <- afr_grid[, Map("*", .SD, cfr*p_infected), .SDcols = names(cfr)]
check_pop <- afr_grid[, names(cfr), with = FALSE]
plot(colSums(check_inf, na.rm = TRUE)/colSums(check_pop, na.rm = TRUE))
points(cfr*p_infected, col = "blue") 
sum(colSums(check_pop, na.rm = TRUE)) # ~ 1.3 billion people?
order_check <- check_pop$A0004 == afr_grid$A0004 # spot check id order stayed the same
length(order_check[!is.na(order_check) & order_check == FALSE]) # should be zero

# Plotting deaths
afr_deaths <- copy(afr_grid)
afr_deaths <- afr_deaths[, (names(cfr)) :=  Map("*", .SD, cfr*p_infected), 
                           .SDcols = names(cfr)]
afr_deaths$deaths_total <- rowSums(afr_deaths[, names(cfr), with = FALSE], na.rm = TRUE)


# Raster 
afr_base <- raster("wp_data/africa_10km_2020/afr_f_A0004_2020_10km.tif")
values(afr_base) <- 1:ncell(afr_base) # get cell id
names(afr_base) <- "cell_id"
afr_base <- as.data.table(as.data.frame(afr_base, xy = TRUE))
afr_base <- afr_base[afr_deaths, on = "cell_id"]
afr_base$deaths_total[afr_base$deaths_total == 0] <- NA

# right now just where people are!
raster <- ggplot() + 
  geom_raster(data = afr_base, aes(x = x, y = y, 
                                    fill = deaths_total)) + 
  scale_fill_distiller(palette = "PuRd", direction = 1, name = "Estimated burden", 
                       na.value = NA,
                       trans = "log", breaks = c(1, 10, 100, 1000, 1e4, 1e5)) +
  coord_quickmap()
ggsave("figs/afr_deaths_grid.jpeg", raster, height = 7, width = 7)

# Admin 3 (This takes a while for AFR!)
afr_admin2 <- afr_base[, lapply(.SD, sum, na.rm = TRUE), 
                         .SDcols = c(names(cfr), "deaths_total"), 
                         by = c("admin2_code")]
afr_admin2$admin2_code <- as.character(afr_admin2$admin2_code)
admin2 <- readOGR("shapefiles/admin2.shp")
gg_admin2 <- fortify(admin2, region = "id_2")
gg_admin2 %>%
  left_join(afr_admin2, by = c("id" = "admin2_code")) -> gg_admin2

afr_deaths_admin2 <- ggplot() +
  geom_polygon(data = gg_admin2, aes(x = long, y = lat, group = group, 
                                     fill = deaths_total)) + 
  scale_fill_distiller(palette = "PuRd", direction = 1, name = "Estimated burden", 
                       trans = "log", breaks = c(1, 10, 100, 1000, 1e4, 1e5, 1e6)) +
  coord_quickmap()
ggsave("figs/afr_deaths_admin2.jpeg", afr_deaths_admin2, height = 7, width = 7)

