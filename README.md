## The purpose of this repo is to provide a POC for a shell script to update the GeoDB database at regular intervals from BIG-IP.

_This was tested on BIG-IP version 15.1.2.1_

### The logic and work flow for the script is as follows:

* Create a directory to backup GeoDB database files, /shared/GeoIP_backup
* Force an "Update Check" on demand, see https://support.f5.com/csp/article/K15000 for details
* Checks what was returned during the "Update Check" to see if there's an available update
* Performs backups up of current GeoDB files; /shared/GeoIP/ to /shared/GeoIP_backup/
* Downloads GeoDB zip file and MD5 file
* Unzips GeoDB zip file
* Installs GeoDB rpm files


- Much of the script was based off information found here: https://support.f5.com/csp/article/K11176
- If you have BIG-IQ in your environment, this process can be centralized from BIG-IQ. See https://support.f5.com/csp/article/K22650515
