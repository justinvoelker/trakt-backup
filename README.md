Simple Trakt.tv Backup Scripts
==============================

This is a collection of simplistic shell scripts that allows to create backups of personal data from the trakt.tv service. The personal data is downloaded in JSON format and stored in an archive. The scripts use version 2 of the trakt.tv API, which requires OAuth authentication.

The following are brief instructions of how to get started with these scripts. The aim is to have a running setup with scheduled jobs that perform regular backups at the end.

Quick setup
-----------

* Create new Trakt app at `https://trakt.tv/oauth/applications`
* Execute `./trakt-setup.sh`
* Obtain an new PIN at `https://trakt.tv/pin/<your-app-id>`
* Execute `./trakt-auth.sh -u <your-username> -c <the-pin-code>`
* Setup cron jobs for automation backup and authentication

Create a new API app
--------------------

The trakt.tv API requires each app to be registered. The registration process provides two keys, the "Client ID" and the "Client Secret", to uniquely identify an app. Head over to the following page to register your own app.

`https://trakt.tv/oauth/applications`

When registering the application, use the redirect URI specified for device authentication.

Once the app is registered, the `trakt-setup.sh` script can be used to store the two aforementioned keys in the `api-client` file. This will allow subsequent communication with the trakt.tv API to succeed.

`$ ./trakt-setup.sh`

Note that the scripts do not provide any OAuth endpoint of their own, hence "PIN Authentication" has to be selected for the app.

Authenticate with PIN code
--------------------------

To associate the scripts with a specific trakt.tv user account, we now perform a manual OAuth handshake using a PIN code. The PIN code can be obtained by heading over to the following page (the app id can be found in the URL when viewing your application page).

`https://trakt.tv/pin/<your-app-id>`

This will allow you to grant your newly created API app access to your (or any other) trakt.tv account. Take note of the PIN code and use it with the `trakt-auth.sh` script to finish authentication as follows.

`$ ./trakt-auth.sh -u <your-username> -c <the-pin-code>`

Authentication information will be stored locally for each account that has been authorized. The file `auth-<your-username>` holds a log of all authentication handshakes.

Note that each grant is valid for 3 months and needs to be refreshed periodically. The `trakt-auth.sh` script can perform the refresh on its own within that period, no new PIN code is required. It is recommended to configure a cron job to do the refresh as described below.

Perform manual backup run
-------------------------

Now that authentication is done, the `trakt-backup.sh` script is ready to download personal data for authenticated accounts. Manually invoking the script as follows will trigger a download.

`$ ./trakt-backup.sh -u <your-username>`

This will create a `backup-<your-username>-<timestamp>.tar.gz` archive containing your personal data in JSON format. Again it is recommended to configure a cron job to perform backups as described below.

By default, the timestamp in the filename will be formatted as YYYYMMDD. Specifying an optional `-d` or `--date-format` parameter allows for custom formatting of the timestamp. For example, to name the created filename with only the year and month, add `-d %Y%m` to the backup command.

Configure cron jobs
-------------------

Setting up the scripts to run periodically is the best way to make sure that regular backups are performed and that authentication information is refreshed. The following are two exemplary entries in the cron table that achieve this.

```
44 4 * * 6 cd $HOME/trakt; ./trakt-backup.sh -u <your-username>
55 4 4 * * cd $HOME/trakt; ./trakt-auth.sh -u <your-username>
```

This will run the backup job once a week and the authentication refresh once a month. You now have a setup performing periodic backups of your personal trakt.tv data. Have fun!

Experimental - data restore
------------

The `trakt-restore.sh` script can restore collections and watch history. Manually invoking the script as follows will restore the specified backup file.

*NOTE* Restoring a watch history is an additive process. Executing the restore script more than once will duplicate the watch history of items being restored. To account for this, the `trakt-restore.sh` script includes a `-c` or `--clear-history` argument which, when set to `true` will completely erase _all_ watch history of the Trakt account before executing the restore. Only clear your watch history if you are sure you want to erase your entire watch history and restore it from the file.

`$ ./trakt-restore.sh -u <your-username> -f <backup-file-to-restore>`
