#!/bin/bash

####################################################################
#   - Proxy can be used for the function performUpdateCheck
#       use K82512024 to configure db variable to enable the proxy
#   - A proxy can also be used to download zip & md5 file with 
#       some adjustments to function getGeodbZip, 
####################################################################


BACKUP_DIR=/shared/GeoIP_backup
GEODB_DIR=/shared/GeoIP


function dirCheck {
    echo "CHECKING: if $BACKUP_DIR exists"
    if [ ! -e $BACKUP_DIR ]
    then
        #create directory if it doesn't exist
        mkdir $BACKUP_DIR
        echo "----- $BACKUP_DIR did NOT exist, it has been created"
    else
        echo "----- $BACKUP_DIR already exists"
    fi
}

function performUpdateCheck {
    echo "RUNNING: '/bin/updatecheck -f' to perform 'update check' on demand"
    /bin/updatecheck -f
    if [ $? -eq 0 ]
    then
        echo "----- SUCCESS: updatecheck succeeded"
    else
        echo "----- EXITING: updatecheck failed, run '/bin/updatecheck -f -d' to check for potential failure reason"
        exit 1
    fi
}

function setIfUpdateAvail {
    EXITSCRIPT=0
    echo "CHECKING: GeoDB-Region2 if update available"
    GEOLOCREG_AVAIL=$(tmsh list /sys software update-status GEOLOC-Region2 | awk 'NR==2' | awk '/available/ {print $2}')
    echo "CHECKING: GeoDB-v6 if update available"
    GEOLOCV6_AVAIL=$(tmsh list /sys software update-status GEOLOC-v6 | awk 'NR==2' | awk '/available/ {print $2}')
    echo "CHECKING: GeoDB-ISP if update available"
    GEOLOCISP_AVAIL=$(tmsh list /sys software update-status GEOLOC-ISP | awk 'NR==2' | awk '/available/ {print $2}')
    if [ $GEOLOCREG_AVAIL = "none" ]
    then
        echo "----- EXITING: No update found for GeoDB-Region2/Worldwide, currently set to $GEOLOCREG_AVAIL"
        EXITSCRIPT=1
    fi
    if [ $GEOLOCV6_AVAIL = "none" ]
    then
        echo "----- EXITING: No update found for GeoDB-v6, currently set to $GEOLOCV6_AVAIL"
        EXITSCRIPT=1
    fi
    if [ $GEOLOCISP_AVAIL = "none" ]
    then
        echo "----- EXITING: No update found for GeoDB-ISP, currently set to $GEOLOCISP_AVAIL"
        EXITSCRIPT=1
    fi
    if [ $EXITSCRIPT -eq 1 ]
    then
        echo "*****************************************************************************"
        echo "***** NO ACTION NEEDED: GeoDB's is showing that NO update is needed"
        echo "*****************************************************************************"
        exit
    else
        echo "----- SUCCESS: Updates available for GeoDB database"
        echo "----- GeoDB-Region2/Worldwide: $GEOLOCREG_AVAIL"
        echo "----- GeoDB-v6:                $GEOLOCV6_AVAIL"
        echo "----- GeoDB-ISP:               $GEOLOCISP_AVAIL"
    fi
}

function backupGeodb {
    echo "CHECKING: if $GEODB_DIR has entries, if so backing up $BACKUP_DIR"
    if [ $(ls -Al $GEODB_DIR | wc -l) -gt 1 ]
    then
        cp -R $GEODB_DIR/* $BACKUP_DIR
        echo "----- Backed up $GEODB_DIR to $BACKUP_DIR"
    else
        echo "----- No backup needed as $GEODB_DIR/* is empty"
    fi
}

function getGeodbZip {
    #URL was built and downloaded from alternative West Coast link pulled June 8th
    #This section will need to be modified depending on where the file will be stored. This also assumes it will be available via HTTP.
    DWNLDHOST=downloads08.f5.com
    DWNLDURLZIP=/esd/download.sv?loc=downloads08.f5.com/downloads/5b6329d5-00a0-4df6-b64a-3b4e26d2fe58/
    DWNLDURLMD5=/esd/download.sv?loc=downloads08.f5.com/downloads/d9668661-11d1-4bce-bb95-6d7f20517741/
    echo "DOWNLOADING: GeoDB ZIP file, this will take a few minutes, please be patient"
    DWNLDZIP=$(curl -w "%{http_code}" --output $GEOLOCREG_AVAIL.zip --silent http://$DWNLDHOST$DWNLDURLZIP$GEOLOCREG_AVAIL.zip)
    if [ $DWNLDZIP -eq 200 ]
    then
        echo "----- SUCCESS: zip file downloaded"
    else
        echo "----- EXITING: zip file download failed, with HTTP response code $DWNLDZIP"
        exit 1
    fi
    echo "DOWNLOADING: MD5 file, this should be quick"
    DWNLDMD5=$(curl -w "%{http_code}" --output $GEOLOCREG_AVAIL.zip.md5 --silent http://$DWNLDHOST$DWNLDURLMD5$GEOLOCREG_AVAIL.zip.md5)
    if [ $DWNLDMD5 -eq 200 ]
    then
        echo "----- SUCCESS: MD5 file downloaded"
    else
        echo "----- EXITING: MD5 file download failed"
        exit 1
    fi
    echo "RUNNING:q MD5 check against GeoDB zip file"
    MD5CHECK=$(md5sum -c ip-geolocation-v2-2.0.0-20210607.506.0.zip.md5)
    if [ $? -eq 0 ]
    then
        echo "----- SUCCESS: MD5 verified - $MD5CHECK"
    else
        echo "----- EXITING: MD5 verification failed"
        exit 1
    fi
}

function unzipRpms {
    echo "Unzipping the contents in $GEOLOCREG_AVAIL.zip"
    UNZIP=$(unzip $GEOLOCREG_AVAIL.zip)
    echo "Result of unzip: $UNZIP"
    #SetVars for each file name
}

function installUpdates {
    echo "RUNNING: install for each new rpm"
    for rpm in  $(unzip -l ip-geolocation-v2-2.0.0-20210607.506.0.zip -x README.txt | awk '/geoip*/ {print $4}')
    do
        #Will log to /var/log/gtm
        geoip_update_data -l -f $rpm
        if [ $? -eq 0 ]
        then
            echo "----- SUCCESS: $rpm was successfully installed"
        else
            echo "*****************************************************"
            echo "***** CHECK: $rpm installation failed, exiting script"
            echo "*****************************************************"
            exit 1
        fi
    done
}


echo "1) =================================="
dirCheck
echo "2) =================================="
performUpdateCheck
echo "3) =================================="
setIfUpdateAvail
echo "4) =================================="
backupGeodb
echo "5) =================================="
getGeodbZip
echo "6) =================================="
unzipRpms
echo "7) =================================="
installUpdates
echo "====================================="
