#' @title Read Pamguard Data
#' 
#' @description Reads in the object data that is common to all modules. This 
#'   reads up to (but not including) the object binary length, and then calls 
#'   a function to read the module-specific data.
#'   
#' @param fid binary file identifier
#' @param fileInfo structure holding the file header, module header, and the
#'   appropriate function to read module specific data
#' @param skipLarge Should we skip large parts of binaries? Currently only applicable
#'   to whistle, click, and DIFAR data
#' @param debug logical flag to show more info on errors
#' @param keepUIDs If not \code{NULL}, a vector of UIDs to read. All UIDs not in this
#'   vector will not be read.
#' @param \dots Arguments passed to other functions
#' 
#' @return a structure containing data from a single object
#' 
#' @author Taiki Sakai \email{taiki.sakai@@noaa.gov}
#' 
readPamData <- function(fid, fileInfo, skipLarge, debug=FALSE, keepUIDs, ...) {
    ### UNSURE OF WHAT THE RESULTS ARE IN CASE OF ERROR ###
    # set constants to match flag bitmap constants in class
    # DataUnitBaseData.java. The following constants match header version 6.
    TIMEMILLIS           <- strtoi('1', base=16)
    TIMENANOS            <- strtoi('2', base=16)
    CHANNELMAP           <- strtoi('4', base=16)
    UID                  <- strtoi('8', base=16)
    STARTSAMPLE          <- strtoi('10', base=16)
    SAMPLEDURATION       <- strtoi('20', base=16)
    FREQUENCYLIMITS      <- strtoi('40', base=16)
    MILLISDURATION       <- strtoi('80', base=16)
    TIMEDELAYSSECS       <- strtoi('100', base=16)
    HASBINARYANNOTATIONS <- strtoi('200', base=16)
    HASSEQUENCEMAP       <- strtoi('400', base=16)
    HASNOISE             <- strtoi('800', base=16)
    HASSIGNAL            <- strtoi('1000', base=16)
    HASSIGNALEXCESS      <- strtoi('2000', base=16)

    # initialize a new variable to hold the data
    data <- list()
    data$flagBitMap <- 0
    hasAnnotation <- 0
    
    # caclulate where the next object starts, in case there is an error trying
    # to read this one
    curObj <- seek(fid)
    objectLen <- pamBinRead(fid, 'int32', n=1)
    nextObj <- curObj + objectLen
    
    # first thing to check is that this is really the type of object we think
    # it should be, based on the file header. If not, warn the user, move the
    # pointer to the next object, and exit
    data$identifier <- pamBinRead(fid, 'int32', n=1)
    
    # this is a re-read of the type of object, so we can use this to check for
    # a -6 which indicates background noise data which will need totally
    # different treatment.
    isBackground <- ifelse(data$identifier == -6,T,F)

    if(!isBackground && !is.null(fileInfo$objectType)) {
        if(any(data$identifier == fileInfo$objectType)) {
            # Do nothing here- couldn't figure out a clean way of checking if
            # number wasn't in array
        } else {
            print(paste('Error - Object Identifier does not match ',
                        fileInfo$fileHeader$moduleType,
                        ' type. Aborting data read.'))
            seek(fid, nextObj, origin='start')
            return(NULL)
        }
    }
    
    # Read the data, starting with the standard data that every data unit has
    version <- fileInfo$fileHeader$fileFormat
    tryCatch({
        data$millis <- pamBinRead(fid, 'int64', n=1)
        
        if(version >= 3) {
            data$flagBitMap <- pamBinRead(fid, 'int16', n=1)
        }
        
        if((version == 2) | (bitwAnd(data$flagBitMap, TIMENANOS) != 0)) {
            data$timeNanos <- pamBinRead(fid, 'int64', n=1)
        }
        
        if((version==2) | (bitwAnd(data$flagBitMap, CHANNELMAP) != 0)) {
            data$channelMap <- pamBinRead(fid, 'int32', n=1)
        }
        
        if(bitwAnd(data$flagBitMap, UID)==UID) {
            data$UID <- pamBinRead(fid, 'int64', n=1)
            # Skip if we provided UID list
            if(!is.null(keepUIDs) &&
               !(data$UID %in% keepUIDs)) {
                seek(fid, nextObj, origin='start')
                return(NULL)
            }
                
        }
        
        if(bitwAnd(data$flagBitMap, STARTSAMPLE) != 0) {
            data$startSample <- pamBinRead(fid, 'int64', n=1)
        }
        
        if(bitwAnd(data$flagBitMap, SAMPLEDURATION) != 0) {
            data$sampleDuration <- pamBinRead(fid, 'int32', n=1)
        }
        
        if(bitwAnd(data$flagBitMap, FREQUENCYLIMITS) != 0) {
            data$minFreq <- pamBinRead(fid, 'float', n=1)
            data$maxFreq <- pamBinRead(fid, 'float', n=1)
            # data$freqLimits <- c(minFreq, maxFreq)
        }
        
        if(bitwAnd(data$flagBitMap, MILLISDURATION) != 0) {
            data$millisDuration <- pamBinRead(fid, 'float', n=1)
        }
        
        if(bitwAnd(data$flagBitMap, TIMEDELAYSSECS) != 0) {
            data$numTimeDelays <- pamBinRead(fid, 'int16', n=1)
            td <- rep(0, data$numTimeDelays)
            for(i in 1:data$numTimeDelays) {
                td[i] <- pamBinRead(fid, 'float', n=1)
            }
            data$timeDelays <- td
        }
        
        if (bitwAnd(data$flagBitMap, HASSEQUENCEMAP) != 0) {
            data$sequenceMap <- pamBinRead(fid, 'int32', n=1)
        }
        
        if (bitwAnd(data$flagBitMap, HASNOISE) != 0) {
            data$noise <- pamBinRead(fid, 'float', n=1)
        }
        
        if (bitwAnd(data$flagBitMap, HASSIGNAL) != 0) {
            data$signal <- pamBinRead(fid, 'float', n=1)
        }
        
        if (bitwAnd(data$flagBitMap, HASSIGNALEXCESS) != 0) {
            data$signalExcess <- pamBinRead(fid, 'float', n=1)
        }
        
        # set date, to maintain backwards compatibility
        data$date <- millisToDateNum(data$millis)
        
        # now read the module-specific data
        if (isBackground) {
            if(inherits(fileInfo$readModuleData, 'function')) {
                result <- fileInfo$readBackgroundData(fid=fid, fileInfo=fileInfo, data=data)
                data <- result$data
                if(result$error) {
                    print(paste('Error - cannot retrieve', 
                                fileInfo$fileHeader$moduleType,
                                'data properly from file', fileInfo$fileName))
                    seek(fid, nextObj, origin='start')
                    return(NULL)
                }
            }
        } else {
            if(inherits(fileInfo$readModuleData, 'function')) {
                result <- fileInfo$readModuleData(fid=fid, fileInfo=fileInfo, data=data, 
                                                  skipLarge=skipLarge, debug=debug, ...)
                data <- result$data
                if(result$error) {
                    print(paste('Error - cannot retrieve', 
                                fileInfo$fileHeader$moduleType,
                                'data properly from file', fileInfo$fileName))
                    seek(fid, nextObj, origin='start')
                    return(NULL)
                }
            }
        }
        
        # Check for annotations
        annotations <- list()
        if(bitwAnd(data$flagBitMap, HASBINARYANNOTATIONS) != 0) {
            hasAnnotation <- 1
            anStart <- seek(fid)
            anTotLength <- pamBinRead(fid, 'int16', n=1)
            nAn <- pamBinRead(fid, 'int16', n=1)
            for(i in 1:nAn) {
                filePos <- seek(fid)
                anLength <- pamBinRead(fid, 'int16', n=1) - 2 # length not include itself
                anId <- readJavaUTFString(fid)$str
                anVersion <- pamBinRead(fid, 'int16', n=1)
                switch(anId,
                       'Beer' = {
                           annotations$beamAngles <- readBeamFormerAnnotation(fid, fileInfo, anVersion)
                       },
                       'Bearing' = {
                           annotations$bearing <- readBearingAnnotation(fid, fileInfo, anVersion)
                       },
                       'TMAN' = {
                           annotations$targetMotion <- readTMAnnotation(fid, fileInfo, anVersion)
                       },
                       'TDBL' = {
                           annotations$toadAngles <- readTDBLAnnotation(fid, fileInfo, anVersion)
                       },
                       'ClickClasssifier_1' = {
                           annotations$classification <- readClickClsfrAnnotation(fid, fileInfo)
                       },
                       'Matched_Clk_Clsfr' = {
                           annotations$mclassification <- readMatchClsfrAnnotation(fid, fileInfo, anVersion)
                       },
                       'DLRE' = {
                           annotations$dlclassification <- readDLAnnotation(fid, fileInfo, anVersion)
                       },
                       'Delt' = {
                           annotations$dlclassification <- readDLAnnotation(fid, fileInfo, anVersion)
                       },
                       {
                           warning(paste0('Unknown annotation type ', anId, ' length ', anLength, 
                                   ' version ', anVersion, ' in file ', fileInfo$fileName))
                           seek(fid, filePos + anLength, origin = 'start')
                       })
                endPos <- seek(fid)
                if(endPos != filePos + anLength) {
                    warning(paste0('Possible annotation read size error in file ',
                                   fileInfo$fileName))
                    seek(fid, filePos + anLength, origin = 'start')
                    endPos <- seek(fid)
                }
            }
            if(endPos != anStart + anTotLength) {
                seek(fid, anStart + anTotLength, origin = 'start')
            }
        }
        # Empty anno list makes turning things into DF weird...
        # if(length(annotations) == 0) annotations <- NA
        
        data$annotations <- annotations
        return(data)
    # }, warning = function(w) {
    #     print(paste('Warning occurred: ', w))
    #     return(data)
    }, error = function(e) {
        print('Error loading object data')
        print(data)
        print(e)
        seek(fid, nextObj, origin='start')
        return(NULL)
    })
}

