# ------------------------------------------------------------------------------------------------
#' Getting mada estimates 
# ------------------------------------------------------------------------------------------------ 

# set up cluster on single node with do Parallel
library(doParallel) 
cl <- makeCluster(3)
registerDoParallel(cl)
getDoParWorkers()
Sys.time()

library(raster)
library(data.table)
library(rgdal)
library(foreach)
library(iterators)
library(glue)

# Aggregate up files --------------------------------------------------------------------------
directory <- "wp_data/mada_100m_2020/"
out_dir <- "wp_data/mada_1x1km_2020/"

files <- list.files(directory, recursive = TRUE)
files <- files[grepl(".tif$", files)] # only tifs
ages <- unique(unlist(lapply(strsplit(files, "_"), function(x) x[[3]])))

foreach(i = 1:length(ages), .combine = cbind, .packages = c("raster", "glue"),
        .export = c("directory", "out_dir", "ages")) %dopar% {
  
  popM <- raster(glue("{directory}mdg_m_{ages[i]}_2020.tif"))
  popM <- aggregate(popM, fact = 10, fun = sum, na.rm = TRUE)
  writeRaster(popM, glue("{out_dir}mdg_m_{ages[i]}_2020_1x1.tif"))
  
  popF <- raster(glue("{directory}mdg_f_{ages[i]}_2020.tif"))
  popF <- aggregate(popF, fact = 10, fun = sum, na.rm = TRUE)
  writeRaster(popF, glue("{out_dir}mdg_f_{ages[i]}_2020_1x1.tif"))
  
  pop <- popM + popF
  values(pop)
  
} -> out_mat

colnames(out_mat) <- ages
fwrite(out_mat, "output/temp_out.gz")

# Read in shapefiles --------------------------------------------------------------------------
raster_base <- raster("wp_data/mada_1x1km_2020/mdg_f_0_2020_1x1.tif")
values(raster_base) <- 1:ncell(raster_base)

# Admin codes (pick finest scale and match accordingly)
admin3 <- readOGR("shapefiles/admin3.shp")
admin3 <- admin3[admin3$iso == "MDG", ]
admin3$id_match <- 1:length(admin3)
id_match <- values(rasterize(admin3, raster_base, field = "id_match"))

mada_dt <- data.table(cell_id = values(raster_base), iso_code = "MDG", 
                      admin1_code = admin3$id_1[id_match], admin2_code = admin3$id_2[id_match],
                      admin3_code = admin3$id_3[id_match], out_mat)

fwrite(mada_dt, "output/mada_dt.gz")

mada_admin1 <- mada_dt[, lapply(.SD, sum, na.rm = TRUE), .SDcols = 6:ncol(mada_dt), 
                        by = c("admin1_code")]
fwrite(mada_admin1, "output/mada_admin1.csv")

mada_admin2 <- mada_dt[, lapply(.SD, sum, na.rm = TRUE), .SDcols = 6:ncol(mada_dt), 
                       by = c("admin2_code")]
fwrite(mada_admin2, "output/mada_admin2.csv")

mada_admin3 <- mada_dt[, lapply(.SD, sum, na.rm = TRUE), .SDcols = 6:ncol(mada_dt), 
                       by = c("admin3_code")]
fwrite(mada_admin3, "output/mada_admin3.csv")

# Close out
stopCluster(cl)
Sys.time()