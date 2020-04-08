# ------------------------------------------------------------------------------------------------ #
#' Summarize data to admin level                                                                         
# ------------------------------------------------------------------------------------------------ #

# set up cluster
library(doParallel) 
cl <- makeCluster(3)
registerDoParallel(cl)
getDoParWorkers()
Sys.time()

# packages
library(raster)
library(rgdal)
library(data.table)
library(tidyverse)

# data
admin2 <- readOGR("output/shapefiles/admin2.shp")

# Aggregate Alegana stats ---------------------------------------------------------------------
# The rasters are not the same so we have to do this individually for each one!
# Takes abt 2 - 5 minutes per raster

files <- list.files("output", recursive = TRUE, full.names = TRUE)
files <- files[grepl("alegana", files)] # only tifs
val_rasts <- lapply(files, raster)
id_rasts <- lapply(val_rasts, function(x) {values(x) <- 1:ncell(x); return(x);})

# Match to finest admin level available
admin2$id_match <- 1:length(admin2)
# for combining dts

multicomb <- function(x, ...) {
  mapply(rbind, x, ..., SIMPLIFY = FALSE)
}

foreach(i= 1:length(id_rasts), .combine = multicomb, .packages = c("raster", "data.table")) %dopar% {
  # rasterize
  id_match <- values(rasterize(admin2, id_rasts[[i]], field = "id_match"))
  dt <- data.table(cell_id = values(val_rasts[[i]]), 
                   id_match, iso = admin2$iso[id_match],
                   value = values(val_rasts[[i]]))
  
  admin_dt <- dt[, .(value = mean(value, na.rm = TRUE)), by = c("id_match")]
  country_dt <- dt[, .(value = mean(value, na.rm = TRUE)), by = c("iso")]
  
  admin_dt$type <- country_dt$type <- gsub("alegana", "", names(val_rasts[[i]]))
  list(admin_dt, country_dt)
  
} -> summ_dt

# Close out
stopCluster(cl)

# Pivot so that each metric is a column
summ_dt[[1]] %>%
  pivot_wider(id_cols = id_match, names_from = type, values_from = value) %>%
  filter(!is.na(id_match)) -> admin2_dt # shape id matches the row id from the master shapefiles
admin2_dt$iso <- admin2$iso[admin2_dt$id_match]
summ_dt[[2]] %>%
  pivot_wider(id_cols = iso, names_from = type, values_from = value) %>%
  filter(!is.na(iso)) -> country_dt # shape id matches the row id from the master shapefiles

# Aggregate age + pop totals! ----------------------------------------------------------------
raster_base <- raster("wp_data/africa_10km_2020/afr_f_A0004_2020_10km.tif")
values(raster_base) <- 1:ncell(raster_base)
id_match <- values(rasterize(admin2, raster_base, field = "id_match"))
out_mat <- fread("output/temp_out_afr.gz")

afr_age <- data.table(cell_id = values(raster_base), iso = admin2$iso[id_match], 
                     id_match = id_match, out_mat)

afr_admin2 <- afr_age[, lapply(.SD, sum, na.rm = TRUE), .SDcols = 4:ncol(afr_age), 
                     by = c("id_match")]
afr_admin2$pop <- rowSums(afr_admin2[, 4:ncol(afr_admin2), with = FALSE])
afr_country <- afr_age[, lapply(.SD, sum, na.rm = TRUE), .SDcols = 4:ncol(afr_age), 
                                                                by = c("iso")]
afr_country$pop <- rowSums(afr_country[, 4:ncol(afr_country), with = FALSE])

# Join with alegana stats
afr_admin2 <- afr_admin2[admin2_dt, on = "id_match"]
afr_country <- afr_country[country_dt, on = "iso"]

# Join with necessary spatial data (names & admin types!)
afr_admin2 %>%
  left_join(select(admin2@data, country = name_0, admin_name = name_2, 
                   admin_type = type_2, id_match)) -> afr_admin2
afr_country$country <- admin2$name_0[match(afr_country$iso, admin2$iso)]

fwrite(afr_admin2, "output/admin2_dt.csv")
fwrite(afr_country, "output/country_dt.csv")

# Remove all extraneous fields from shapefiles & write to geojson --------------------------
admin2@data <- data.frame(id_match = admin2$id_match, iso = admin2$iso)
country <- readOGR("output/shapefiles/country.shp")
country@data <- data.frame(iso = country$iso)

writeOGR(admin2, "temp", layer = "admin2", driver = "ESRI Shapefile", overwrite = TRUE)
writeOGR(country, "temp", layer = "country", driver = "ESRI Shapefile", overwrite = TRUE)

system("ogr2ogr -f GeoJSON -t_srs crs:84 output/geojson/admin2.geojson temp/admin2.shp")
system("ogr2ogr -f GeoJSON -t_srs crs:84 output/geojson/country.geojson temp/country.shp")
system("rm -R temp") # remove intermediate shapefiles created

