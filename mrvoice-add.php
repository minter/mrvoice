<? # CONFIGURATION
   # Set the following variables for your particular configuration.  
   # NOTE: This script is hardcoded to use MySQL.  If you use another 
   # database supported by PHP, change the mysql_* calls to match your
   # database.

   # $path is the path to the directory on your filesystem that contains
   # the Mr. Voice mp3s.  It must be writable by the user that your 
   # web server is running as.  This will be prepended to the filename
   # from the database result, so plan accordingly.
   $path = "/PATH/TO/MP3s";
 
   # These four options set the name, hostname, username, and password for
   # your database.
   # $database_username must have INSERT access on the mrvoice 
   # database/tables.
   $database = "DBNAME";
   $database_host = "localhost";
   $database_username = "USERNAME";
   $database_password = "PASSWORD";

   # CVS ID: $Id: mrvoice-add.php,v 1.3 2001/02/21 03:06:16 minter Exp $
?>

<TITLE>Mr. Voice MP3 Database Insertion</TITLE>
<BODY BGCOLOR=#FFFFFF>
<H1>Add a song to the Mr. Voice Database</H1>
<P>Use this form to add songs to the Mr. Voice database.
<HR>
  
<FORM ENCTYPE="multipart/form-data" ACTION="<? print $PHP_SELF ?>" METHOD=POST>
<TABLE BORDER=0>
<TR><TD>Category</TD> <TD><SELECT NAME=category>

<?
  if (!($dblink = mysql_connect($database_host,$database_username,$database_password)))
  { 
    print "mysql_connect failed\n";
  }

  if (!(mysql_select_db("$database",$dblink)))
  {
    print "mysql_select_db failed\n";
  }

  $query = "SELECT * FROM categories ORDER BY description";

  $dbresult = mysql_query($query,$dblink);
 
  while ($row = mysql_fetch_array($dbresult))
  {
    print "<OPTION VALUE={$row[0]}>{$row[1]}\n";
  }
?>

</SELECT></TD></TR>
<TR><TD>Category Extra Info.</TD> <TD><INPUT TYPE=text SIZE=25 NAME=extrainfo></TD></TR>
<TR><TD>Artist</TD> <TD><INPUT TYPE=text SIZE=25 NAME=artist></TD></TR>
<TR><TD>Title</TD> <TD><INPUT TYPE=text SIZE=25 NAME=title></TD></TR>
<TR><TD>File To Upload</TD> <TD><INPUT NAME=UploadFile TYPE=file></TD></TR>
</TABLE>
<INPUT TYPE=submit NAME=action VALUE=Add>  
</FORM>
  
<?
  if ($action == "Add")
  {
    if ($UploadFile == "none")
    {
      print "<FONT COLOR=#FF0000>File not uploaded properly . . . aborting.</FONT>\n";
      mysql_close($dblink);
      exit();
    }

    if ($artist)
    {
      $filename = "$artist-$title";
    }
    else
    {
      $filename = $title;
    }
    $filename = ereg_replace ("[^A-Za-z0-9\-]","",$filename);

    if (! file_exists("$path/$filename.mp3"))
    {
      $filename = "$filename.mp3";
      if (! move_uploaded_file ($UploadFile,"$path/$filename"))
      {
        print "<FONT COLOR=#FF0000>Rename of uploaded file failed!  Aborting!</FONT>\n";
        exit;
      }
      chmod ("$path/$filename", 0664);
    }
    else
    {
      $i=1;
      while (++$i)
      {
        if (! file_exists("$path/$filename$i.mp3"))
        {
          $filename="$filename$i.mp3";
          break;
        }
      }
      if (! move_uploaded_file ($UploadFile,"$path/$filename"))
      {
        print "<FONT COLOR=#FF0000>Rename of uploaded file failed!  Aborting!</FONT>\n";
      }
      chmod ("$path/$filename", 0664);

    }
        
    $query = "INSERT INTO mrvoice VALUES (0,'$title','$artist','$category','$extrainfo','$filename',NULL)";

    if (!($dbresult = mysql_query($query,$dblink)))
    {
      print "<FONT COLOR=#FF0000>mysql_query failed using query $query</FONT>\n";
    }
    else
    {
      print "<FONT COLOR=#00FF00>Insert successful!</FONT>\n";
    }
 
  mysql_close($dblink);
  }

?>

<HR>
<I>Designed by <a href=http://www.lunenburg.org/>H. Wade Minter</A> &lt<a href="mailto:minter@lunenburg.org">minter@lunenburg.org</A>&gt.

