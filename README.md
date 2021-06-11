## The purpose of this repo is to provide a POC for a shell script to update the GeoDB database at regular intervals

_This was tested on BIG-IP version 15.1.2.1

### The logic and work flow for the script is as follows:

* Create a directory to backup GeoDB database files, /shared/GeoIP_backup
* Force an "Update Check" on demand, see https://support.f5.com/csp/article/K15000 for more details
* Checks what was returned during the "Update Check" to see if there's an available update
* Performs backups up of current GeoDB files; /shared/GeoIP/ to /shared/GeoIP_backup/
* Downloads GeoDB zip file and MD5 file
* Unzips GeoDB zip file
* Installs GeoDB rpm files
