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
 
   # CVS ID: $Id: mrvoice.php,v 1.5 2001/02/25 18:14:08 minter Exp $
?>

<TITLE>Mr. Voice MP3 Database</TITLE>
<BODY BGCOLOR=#FFFFFF>
<CENTER><H1>Online Mr. Voice MP3 Database</H1></CENTER>
<P>You can search the Mr. Voice database from this form.  
<P>To add a song to the database, use <a href=mrvoice-add.php>this form</A>.
<?
  $thismonth = date("n");
  $thisday = date("d");
  $thisyear = date ("Y");
?>
<HR>
  
<FORM ACTION=<? print $PHP_SELF ?> METHOD=POST>
<TABLE BORDER=0>
<TR><TD>Category</TD> <TD><SELECT NAME=category>

<?
  include ("class.id3.php");
  if (!($dblink = mysql_connect($database_host,$database_username,$database_password)))
  { 
    print "mysql_connect failed\n";
  }

  if (!(mysql_select_db($database,$dblink)))
  {
    print "mysql_select_db failed\n";
  }

  $query = "SELECT * FROM categories";

  $dbresult = mysql_query($query,$dblink);
 
  print "<OPTION VALUE='Any'>All Categories\n";

  while ($row = mysql_fetch_array($dbresult))
  {
    print "<OPTION VALUE={$row[0]}>{$row[1]}\n";
  }
?>

</SELECT></TD></TR>
<TR><TD>Category Extra Info.</TD> <TD><INPUT TYPE=text SIZE=25 NAME=extrainfo></TD></TR>
<TR><TD>Artist</TD> <TD><INPUT TYPE=text SIZE=25 NAME=artist></TD></TR>
<TR><TD>Title</TD> <TD><INPUT TYPE=text SIZE=25 NAME=title></TD></TR>
<TR><TD>Modified After (Date)</TD> <TD><SELECT NAME=month>

<?
  for ($i=1; $i<=12; $i++)
  {
    if ($i < 10)
    {
      $x = "0$i";
    }
    else
    {
      $x = $i;
    }
    print "<OPTION>$x\n";
  }
?>
</SELECT> / <SELECT NAME=date>
<?
  for ($i=1; $i<=31; $i++)
  {
    if ($i < 10)
    {
      $x = "0$i";
    }
    else
    {
      $x = $i;
    }
    print "<OPTION>$x\n";
  }
?>
</SELECT> / <SELECT NAME=year>
<?
  for ($i=2000; $i<=$thisyear; $i++)
  {
    $twoyear = substr($i,2,2);
    print "<OPTION VALUE=$twoyear>$i\n";
  }
?>
</SELECT>

(<a href=<? print $PHP_SELF ?>?action=Search&timespan=today>Modified Today</A>) (<a href=<? print $PHP_SELF ?>?action=Search&timespan=week>Modified In Past 7 Days</A>)</TD></TR>
</TABLE>
<INPUT TYPE=submit NAME=action VALUE=Search>  
</FORM>
  
<?
  if ($action == "Search")
  {
 
    $query = "SELECT mrvoice.title, mrvoice.artist, categories.description, mrvoice.info, mrvoice.filename,mrvoice.modtime,mrvoice.id FROM mrvoice,categories WHERE mrvoice.category=categories.code";
    if ($timespan == "today")
    {
      $time = date("ymd");
      $query = $query . " AND modtime='$time'";
    }
    elseif ($timespan == "week")
    {
      $timestamp = (time() - (60 * 60 * 24 * 6));
      $weekago = date("ymd",$timestamp);
      $query = $query . " AND modtime>=$weekago";
    }
    else
    {
      if ($category != "Any")
      {
        $query = $query . " AND category='$category'";
      }
      if ($extrainfo)
      {
        $query = $query . " AND info LIKE '%$extrainfo%'";
      }
      if ($title)
      {
        $query = $query . " AND title LIKE '%$title%'";
      }
      if ($artist)
      {
        $query = $query . " AND artist LIKE '%$artist%'";
      }
      $query = $query . " AND modtime>$year$month$date";
    }
    $query = $query . " ORDER BY category,info,title";

    if (!($dbresult = mysql_query($query,$dblink)))
    {
      print "mysql_query failed using query $query\n";
      mysql_close($dblink);
      exit;
    }
 
    print "<P><I>The search returned " . mysql_num_rows($dbresult) . " match";
    mysql_num_rows($dbresult) != 1 ? print "es</I>\n" : print "</I>\n";
    print "<TABLE BORDER=1 CELLPADDING=3>\n";
    print "<TR><TH>Category</TH> <TH>Extra Info</TH> <TH>Artist</TH> <TH>Title<BR>(Click to download MP3)</TH> <TH>File Size</TH> <TH>MP3<BR>Length</TH> <TH>Modified</TH> <TH>Edit?</TH></TR>\n";
    while ($row = mysql_fetch_array($dbresult))
    {
      print "<TR><TD>$row[2]</TD> <TD>";
 
      $row[3] == "" ? print "<BR>" : print "$row[3]";

      print "</TD> <TD>";

      $row[1] == "" ? print "<BR>" : print "$row[1]";

      print "</TD> <TD><a href=/csz$row[4]>$row[0]</A></TD> <TD>";
    
      $file_size = filesize("$path/$row[4]");     
      if ($file_size >= 1073741824) {
        $file_size = round($file_size / 1073741824 * 100) / 100 . "G";
      } elseif ($file_size >= 1048576) {
        $file_size = round($file_size / 1048576 * 100) / 100 . "M";
      } elseif ($file_size >= 1024) {
        $file_size = round($file_size / 1024 * 100) / 100 . "k";
      } else {
        $file_size = $file_size . "b";
      }
      print "$file_size</TD><TD>";

      $id3 = new id3("$path/$row[4]");
      $time = $id3->length;
      print "$time</TD><TD>";
  
      $rawdate = $row[5];
      $year = substr($rawdate,0,2);
      $month = substr($rawdate,2,2);
      $day = substr($rawdate,4,2);
      print "$month/$day/$year</TD>";
      print "<TD><A HREF=mrvoice-add.php?action=Edit&id=$row[6]>Edit</A></TD>";
      print "</TR>\n";
    }
    print "</TABLE>\n";
     
  mysql_close($dblink);

  }

?>

<HR>
<I>Designed by <a href=http://www.lunenburg.org/>H. Wade Minter</A> &lt<a href="mailto:minter@lunenburg.org">minter@lunenburg.org</A>&gt.
