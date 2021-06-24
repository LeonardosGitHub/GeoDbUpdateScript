# AUTOMATE UPDATES TO GeoDB DIRECTLY FROM BIG-IP

### Purpose of this repo is to provide a POC for a shell script to update the GeoDB database at regular intervals from BIG-IP. Use at your own risk

_This was tested on BIG-IP version 15.1.2.1_

### The logic and flow for the script is as follows:

* Runs 'geoip_lookup' command against a couple of IPs to compare pre & post DB update
* If needed, creates a directory to backup GeoDB database files, /shared/GeoIP_backup
* Forces an "Update Check" on demand to see if GeoDB needs an update, see https://support.f5.com/csp/article/K15000 for details
* Checks what was returned during the "Update Check" to see if there's an available update
* If needed, performs backups up of current GeoDB files; /shared/GeoIP/ to /shared/GeoIP_backup/
* Authenticates to downloads.f5.com and uses seed URLs to eventually find the exact download URL for the update
* Downloads GeoDB zip file and MD5 file
* Unzips GeoDB zip file
* Installs GeoDB rpm files
* Runs 'geoip_lookup' command against a couple of IPs to compare pre & post DB update


### Notes

* Much of the script was based geoDB installation guide found here: https://support.f5.com/csp/article/K11176
* A proxy can be used for the function performUpdateCheck, use K82512024 to configure db variable to enable the proxy
* "updatecheck" functionality and documentation can be found here using F5 knowledge article https://support.f5.com/csp/article/K15000
* A proxy can also be used to find & download zip & md5 files this is via the proxy functionality included with curl, see https://everything.curl.dev/usingcurl/proxies
* If you have BIG-IQ in your environment, this process can be centralized from BIG-IQ. See https://support.f5.com/csp/article/K22650515
* This was tested on BIG-IP version 15.1.2.1, functionality may break with different versions.
* Also changes to downloads.f5.com will probably break functionality as well


# Use at your own risk! This is for POC purposes only!

