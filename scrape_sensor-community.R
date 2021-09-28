# This file is part of Air Quality Data Sonification.
#
# Air Quality Data Sonification is free software: you can redistribute 
# it and/or modify it under the terms of the GNU General Public License 
# as published by the Free Software Foundation, either version 3 of the 
# License, or (at your option) any later version.
#
# Air Quality Data Sonification is distributed in the hope that it will 
# be useful, but WITHOUT ANY WARRANTY; without even the implied warranty 
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Air Quality Data Sonification.
# If not, see <http://www.gnu.org/licenses/>.

################################################################################
# Libraries                                                                    #
################################################################################
library(readr)
library(dplyr)
library(RCurl)

get_data <- function(id, type, start, end) {
  ##############################################################################
  # This function does for each day [date_start:date_end]:                     #
  #   - check if data for sensor id, type is available,                        #
  #   - if not, download data and store it on hard drive.                      #
  # Input:  - id, type: as in file name of archive.sensor.community            #
  #         - start/end: Start and End Time stamp                              #
  # Returns:  - 0: Every as planned                                            #
  #           - 1: Error while downloading                                     #
  #           - 2: Warning while downloading                                   #
  ##############################################################################
  # initialize error handling
  error = 0
  
  # Converting start/end into Date format, set starting date
  start <- as.Date(start)
  end   <- as.Date(end)
  theDate <- start
  
  # Loop trough dates
  while (theDate <= end) {
    
    # Construct file name
    file <- paste0(theDate,'_', type, '_sensor_',id,'.csv')
    
    # Check if file exists in data directory
    if (file.exists(paste0('data/',file))) {
      message(paste('File already downloaded'))
    } else { # Download file from archive.sensor.community
      
      # Construct URL
      url <- paste0('https://archive.sensor.community/',theDate,'/',file)
      
      # Download file
      out <- tryCatch(
        { # Everything goes as planes
          download <- getURL(url)
          data <- read.csv(text = download, header = TRUE, sep = ";", dec = ".", fill = TRUE)
          write.csv(data, file = paste0('data/',file))
        },
        error=function(cond) { # Error message
          message(paste("URL does not seem to exist:", url))
          return(1)
        },
        warning=function(cond) { # Warning message
          message(paste("URL caused a warning:", url))
          error = 2
        },
        finally={ # When done
          message(paste("Processed URL:", url))
        }
      )
    }
    
    # Iterate
    theDate <- theDate + 1
  }
  
  # Function terminates as planned
  return(error)
}
## END OF FUNCTION get_data

calc_moving_mean <- function(now, data, dt) {
  ##############################################################################
  # Calculate the 24h Moving Average for time "now" in data set "data"         #
  # Input:  - Now: Time stamp to Calculate 24h Moving Average for              #
  #         - data: data set with first col - time stamp, second col - data    #
  #         - dt: time to average about (in s)                                 #
  # Returns: Single Value Moving Average for now [P1, P2]                      #
  ##############################################################################
  
  # Filter data by time stamp and dt
  data <- filter(data,
                 as.POSIXlt(data$timestamp) < now + dt/2 & 
                 as.POSIXlt(data$timestamp) > now - dt/2
                 )
  
  # Return moving mean values
  return(cbind(mean(data$P1), mean(data$P2)))
}
## END OF FUNCTION calc_moving_mean

create_set_inherit <- function(id, type, start, end) {
  ##############################################################################
  # Create a data set with full data                                           #
  # Input:  - id: Sensor ID from sensor.community                              #
  #         - type: Sensor type from sensor.community                          #
  #         - start/end: Start and end time stamp                              #
  # Returns: Path to data set .csv File or Error Message                       #
  ##############################################################################
  
  # Scrape Data if not already in data directory
  error <- get_data(id, type, start, end)
  if( error == 0 ) { # Everything OK
    message(paste("All files downloaded"))
  } else if (error == 1) { # There was an Error
    message(paste("An Error occured while downloading the data"))
    return("An Error occured while downloading the data")
  } else if ( error == 2) { # There was a Warning
    message(paste("A Warning occured while downloading the data"))
  }
  
  # Set starting date and create empty data frame
  date <- as.Date(start)
  data <- data.frame()
  
  # Loop trough files and combine them
  while ( date <= end ) {
    
    # Construct file name
    file <- paste0('data/', date, '_', type, '_sensor_', id,'.csv')
    
    # Read data
    data <- rbind(data, read.csv(file))
    
    # Itterate
    date = date + 1
  }
  
  # Filter data by start/end
  data$timestamp <- gsub("T", " ", data$timestamp)
  data <- filter(data, data$timestamp > start & data$timestamp < end)
  
  # Here could go some statistic magic
  
  # Construct file name and save data
  path <- paste0('data/set_inherit',start,'_',end,'_',type,'_sensor_',id,'.csv')
  write.csv(data, file = path)
  
  # Return data
  return(path)
}
## END OF FUNCTION create_set_inherit

create_set_moving_mean <- function(id, type, start, end, dt, tmean) {
  ##############################################################################
  # Create a data set with hourly data                                         #
  # Input:  - id: Sensor ID from sensor.community                              #
  #         - type: Sensor type from sensor.community                          #
  #         - start/end: Start and end Time stamp                              #
  #         - dt: time between data points                                     #
  #         - tmean: time to average about                                     #
  # Retruns: Path to dataset .csv File or Error Message                        #
  ##############################################################################

  # Scrape Data if not already in data directory
  error <- get_data(id, type, start, end)
  if( error == 0 ) { # Everything OK
    message(paste("All files downloaded"))
  } else if (error == 1) { # There was an Error
    message(paste("An Error occured while downloading the data"))
    return("An Error occured while downloading the data")
  } else if ( error == 2) { # There was a Warning
    message(paste("A Warning occured while downloading the data"))
  }
  
  # Set starting date and create empty data frame
  date <- as.Date(start)
  data <- data.frame()
  
  # Loop trough files and combine them
  while ( date <= end ) {
    
    # Construct file name
    file <- paste0('data/', date, '_', type, '_sensor_', id,'.csv')
    
    # Read data
    data <- rbind(data, read.csv(file))
    
    # Itterate
    date = date + 1
  }

  # Edit Time stemp
  data$timestamp <- gsub("T", " ", data$timestamp)
  
  # Calculate moving mean
  now <- as.POSIXlt( start )
  timestamp <- c()
  moving_mean_P1 <- c()
  moving_mean_P2 <- c()
  
  # Loop trough data points
  while( now <= as.POSIXlt(end) ) {
    
    # Print progress
    message(paste("Calculate moving mean at time stemp: ", now))
    
    # Calculate
    out = calc_moving_mean(now, data, tmean)
    
    # Write to vector
    timestamp <- c(timestamp, paste0(now))
    moving_mean_P1 <- c(moving_mean_P1, out[1])
    moving_mean_P2 <- c(moving_mean_P2, out[2])
    
    # Iterate
    now <- now + dt
  }
  
  # Create data frame
  data_mean <- data.frame(timestamp, moving_mean_P1, moving_mean_P2)
  colnames(data_mean) <- c('timestamp', 'moving_mean_P1', 'moving_mean_P2')
  
  # Here could go some statistic magic
  
  # Construct file name and save data
  path <- paste0('data/set_dt_',dt,'_tmean_',tmean,start,'_',end,'_',type,'_sensor_',id,'.csv')
  write.csv(data_mean, file = path)
  
  # Return Data
  return(data_mean)
}
## END OF FUNCTION create_set_moving_mean