#!/bin/bash

#####################################################################
#                                                                   #
#     Use at your own risk! This is for POC purposes only!          #
#                                                                   #
#####################################################################
#   - Proxy can be used for the function performUpdateCheck         #
#       use K82512024 to configure db variable to enable the proxy  #
#   - "updatecheck" functionality and documentation can be found    #
#       here using F5 knowledge article K15000                      #
#   - A proxy can also be used to find & download zip & md5 files   #
#       this is via the proxy functionality included with curl      #
#   - This was tested on BIG-IP version 15.1.2.1, functionality     #
#       may break with different versions.  Also changes to         #
#       downloads.f5.com will probably break functionality as well  #
#   - Documenation for downloading and installing geoDB updates can #
#       be found at F5 knowledge article K11176                     #
#####################################################################

BACKUP_DIR=/shared/GeoIP_backup
GEODB_DIR=/shared/GeoIP

# Set proxy information here, update curl commands to use proxy
#PROXYOUT=10.1.1.1:3128
# Below is an example of adding the proxy to the curl command, adding '-x $PROXYOUT' will force curl to use specified proxy
#DWNLDZIP=$(curl -x $PROXYOUT -w "%{http_code}" --output $GEOLOCREG_AVAIL.zip --silent $DWNLDZIPURL)


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
    #The results of the updatecheck can be found using 'tmsh list /sys software udpate-status' we are using this to determine if an update is needed and as a seed URL to eventually get the zip & MD5 file
    EXITSCRIPT=0
    echo "CHECKING: GeoDB-Region2 if update available and getting seed URL for use later in script"
    GEOLOCREG_AVAIL=$(tmsh list /sys software update-status GEOLOC-Region2 | awk 'NR==2' | awk '/available/ {print $2}')
    GEOLOCREG_URL=$(tmsh list /sys software update-status GEOLOC-Region2 | awk 'NR==8' | awk '/url/ {print $2}' | sed 's/ecc.sv\\?/eula.sv?/g')
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
    #If needed backing up /shared/GeoIP to /shared/GeoIP_backup
    echo "CHECKING: if $GEODB_DIR has entries, if so backing up $BACKUP_DIR"
    if [ $(ls -Al $GEODB_DIR | wc -l) -gt 1 ]
    then
        cp -R $GEODB_DIR/* $BACKUP_DIR
        echo "----- Backed up $GEODB_DIR to $BACKUP_DIR"
    else
        echo "----- No backup needed as $GEODB_DIR/* is empty"
    fi
}

function performAuthGetUrls {
    # User & Password management is a business decision, hardcoding a password is never recommended. 
    echo "************************************************************"
    echo "* PROVIDE USER & PASSWORD INFORMATION FOR downloads.f5.com *"
    echo "************************************************************"
    sleep 2
    echo "F5 Downloads User:"
    read F5USER
    echo "F5 Downloads Password:"
    read -s F5PASSWD

    echo "STARTING: SSO auth and gathering seed URLs for downloads"
    RAWDATAF5="userid=$F5USER&passwd=$F5PASSWD"
    LOGINRESP=$(curl -v 'https://api-u.f5.com/auth/pub/sso/login/user' -H 'Origin: https://login.f5.com' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Referer: https://login.f5.com/' -H 'Accept-Language: en-US,en;q=0.9' --data-raw $RAWDATAF5 2>&1 | grep 'Set-Cookie')
    if [ -z "$LOGINRESP" ];
    then
        echo "----- EXITING: Unable to sign in"
        exit 1
    else
        echo "----- SUCCESS: LOGGED IN, RECEIVED SSO COOKIES"
        #Removing newline characters
        LOGINRESP=$(echo $LOGINRESP | sed -e 's/\r//g')
        #Gathering and setting response cookies
        COOKIESSO=$(echo $LOGINRESP | grep -Po 'ssosession=.*?(?=;)')
        COOKIESSOCOMPL=$(echo $LOGINRESP | grep -Po 'sso_completed=.*?(?=;)')
        COOKIEUSR=$(echo $LOGINRESP | grep -Po 'userinfo=.*?(?=;)')
        COOKIEF5SID=$(echo $LOGINRESP | grep -Po 'f5sid01=.*?(?=;)')
    fi
    echo "STARTING: EULA acceptance, getting JSESSION ID, and various COOKIES"
    sleep 5
    EULARESP=$(curl -s -i $GEOLOCREG_URL -H "Cookie: $COOKIESSO; $COOKIESSOCOMP; $COOKIEUSR; $COOKIEF5SID"  2>&1 | grep 'Set-Cookie')
    if [ -z "$EULARESP" ];
    then
        echo "----- EXITING: Accepting EULA failed"
        exit 1
    else
        echo "----- SUCCESS: EULA & JSESSION ID retrieved"
        #Removing newline characters
        EULARESP=$(echo $EULARESP | sed -e 's/\r//g')
        #Gathering and setting response cookies
        COOKIESSO=$(echo $EULARESP | grep -Po 'ssosession=.*?(?=;)')
        COOKIEJSESSIONID=$(echo $EULARESP | grep -Po 'JSESSIONID=.*?(?=;)')
        COOKIEBIGIPDWNLS=$(echo $EULARESP | grep -Po 'BIGipServerDownloads=.*?(?=;)')
        COOKIETS1=$(echo $EULARESP | grep -Po 'TS........=.*?(?=;)' | awk 'NR==1')
        COOKIETS2=$(echo $EULARESP | grep -Po 'TS........=.*?(?=;)' | awk 'NR==2')
    fi
    echo "STARTING: Parsing HTML to eventually find download URL"
    #updating seed URL to EULA accepted URL format
    GEOLOCREG_URL=$(echo $GEOLOCREG_URL | { sed 's/ecc/eula/g'| tr -d '\n' ; echo "&path=&file=&B1=I+Accept";})
    sleep 5
    #Parsing HTML to get URLs to get seed URLs to find URLs to directly download zip and MD5 files
    GETHTML=$(curl -s -H "Cookie: $COOKIEJSESSIONID; $COOKIESSOCOMPL; $COOKIESSO; $COOKIEUSR; $COOKIEBIGIPDWNLS; $COOKIETS1; $COOKIETS2" "$GEOLOCREG_URL" 2>&1 | grep zip)
    if [ -z "$GETHTML" ];
    then
        echo "----- EXITING: Getting HTML to find download location failed"
        exit 1
    else
        echo "----- SUCCESS: Getting HTML to find seed download location"
        ZIPURL=$(echo $GETHTML | grep -Po "a href='.*?(?=')" | sed "s/a href='//g" | grep -v md5)
        ZIPMD5URL=$(echo $GETHTML | grep -Po "a href='.*?(?=')" | sed "s/a href='//g" | grep md5)
    fi
    echo "STARTING: Parsing HTML to find seed URLs"
    #Parsing HTML to get URLs to directly download zip and MD5
    DWNLDZIPURL=$(curl -s -H "Cookie: $COOKIEJSESSIONID; $COOKIESSOCOMPL; $COOKIESSO; $COOKIEUSR; $COOKIEBIGIPDWNLS" "https://downloads.f5.com/esd/$ZIPURL" | grep -B10 HTTPS: | grep -Po 'a href=".*?(?=")' | sed 's/a href="//g')
    if [ -z "$DWNLDZIPURL" ];
    then
        echo "----- EXITING: Getting HTML to find download URL location failed"
        exit 1
    else
        echo "----- SUCCESS: Getting download zip URL: $DWNLDZIPURL"
    fi
    echo "STARTING: Parsing HTML to find download URLs"
    DWNLDZIPMD5URL=$(curl -s -H "Cookie: $COOKIEJSESSIONID; $COOKIESSOCOMPL; $COOKIESSO; $COOKIEUSR; $COOKIEBIGIPDWNLS" "https://downloads.f5.com/esd/$ZIPMD5URL" | grep -B10 HTTPS: | grep -Po 'a href=".*?(?=")' | sed 's/a href="//g')
    if [ -z "$DWNLDZIPMD5URL" ];
    then
        echo "----- EXITING: Getting HTML to find download URL location failed"
        exit 1
    else
        echo "----- SUCCESS: Getting download MD5 URL: $DWNLDZIPMD5URL"
    fi
}

function getGeodbZip {
    echo "DOWNLOADING: GeoDB ZIP file, this will take a few minutes, please be patient"
    DWNLDZIP=$(curl -w "%{http_code}" --output $GEOLOCREG_AVAIL.zip --silent $DWNLDZIPURL)
    if [ $DWNLDZIP -eq 200 ]
    then
        echo "----- SUCCESS: zip file downloaded"
    else
        echo "----- EXITING: zip file download failed, with HTTP response code $DWNLDZIP"
        exit 1
    fi
    echo "DOWNLOADING: MD5 file, this should be quick"
    DWNLDMD5=$(curl -w "%{http_code}" --output $GEOLOCREG_AVAIL.zip.md5 --silent $DWNLDZIPMD5URL)
    if [ $DWNLDMD5 -eq 200 ]
    then
        echo "----- SUCCESS: MD5 file downloaded"
    else
        echo "----- EXITING: MD5 file download failed, with HTTP response code $DWNLDMD5"
        exit 1
    fi
    echo "RUNNING: MD5 check against GeoDB zip file"
    MD5CHECK=$(md5sum -c $GEOLOCREG_AVAIL.zip.md5)
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
}

function installUpdates {
    echo "RUNNING: install for each new rpm"
    #Below command will list all the files that have been zipped and iterate over them to perform an install 
    for rpm in  $(unzip -l $GEOLOCREG_AVAIL.zip -x README.txt | awk '/geoip*/ {print $4}')
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

function lookupverification {
    echo "RUNNING: geoip_lookup to spot check database; pre & post DB update"
    geoip_lookup 8.8.8.8
    geoip_lookup 159.53.85.184
}

echo "START OF SCRIPT ====================="
echo "1) =================================="
lookupverification
echo "2) =================================="
dirCheck
echo "3) =================================="
performUpdateCheck
echo "4) =================================="
setIfUpdateAvail
echo "5) =================================="
backupGeodb
echo "6) =================================="
performAuthGetUrls
echo "7) =================================="
getGeodbZip
echo "8) =================================="
unzipRpms
echo "9) =================================="
installUpdates
echo "10) ================================="
lookupverification
echo "END OF SCRIPT========================"