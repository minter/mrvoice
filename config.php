<? #CONFIGURATION
   # Set the following variables for your particular configuration.
   # NOTE: This script is hardcoded to use MySQL.  If you use another
   # database supported by PHP, change the mysql_* calls to match your
   # database.

   # $path is the path to the directory on your filesystem that contains
   # the Mr. Voice mp3s.  It must be writable by the user that your
   # web server is running as.  This will be prepended to the value
   # of the filename from the database result, so plan accordingly.
   $path = "/PATH/TO/MP3s";

   # These four options set the name, hostname, username, and password for
   # your database.
   # $database_username must have SELECT access on the mrvoice
   # database/tables.
   $database = "DBNAME";
   $database_host = "localhost";
   $database_username = "USERNAME";
   $database_password = "PASSWORD";

   # CVS ID: $Id: config.php,v 1.1 2001/02/25 23:33:04 minter Exp $
?>

