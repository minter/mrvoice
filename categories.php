<? # CONFIGURATION
   # Set the following variables for your particular configuration.
   # NOTE: This script is hardcoded to use MySQL.  If you use another
   # database supported by PHP, change the mysql_* calls to match your
   # database.

   # These four options set the name, hostname, username, and password for
   # your database.
   # $database_username must have INSERT access on the mrvoice
   # database/tables.
   $database = "DBNAME";
   $database_host = "localhost";
   $database_username = "USERNAME";
   $database_password = "PASSWORD";

   # CVS ID: $Id: categories.php,v 1.1 2001/02/25 22:11:36 minter Exp $
?>

<TITLE>Display/Modify the categories database</TITLE>
<BODY BGCOLOR=#FFFFFF>

<?
  if (!($dblink = mysql_connect($database_host,$database_username,$database_password)))
  {
    print "mysql_connect failed\n";
  }

  if (!(mysql_select_db("$database",$dblink)))
  {
    print "mysql_select_db failed\n";
  }

  if ($action == "Add New Category")
  {
    $query = "INSERT INTO categories (code,description) VALUES ('$code','$description')";
    if ($dbresult = mysql_query($query,$dblink))
    {
      print "<FONT COLOR=#00FF00>Category added successfully</FONT>\n";
    }
    else
    {
      print "<FONT COLOR=#FF0000>Database add failed!</FONT> - error message: " . mysql_error();
      print "<P>The query was: $query\n";
    }
  }
  elseif ($action == "Delete Checked Categories")
  {
    $numentries = count($del_categories);
    if ($numentries == 0)
    {
      print "No items checked for deletion.  Doing nothing...<P>\n";
    }
    else
    {
      for ($i=0; $i<$numentries; $i++)
      {
        print "<P>Deleting $del_categories[$i]...";
        $query = "DELETE FROM categories WHERE code='$del_categories[$i]'";
        if ($dbresult = mysql_query($query,$dblink))
        {
          print "<FONT COLOR=#00FF00>Deleted successfully!</FONT>";
        }
        else
        {
          print "<FONT COLOR=#FF0000>Deletion failed!</FONT>";
        }
      }
    }
  }

  $query = "SELECT * from categories ORDER BY code";
  $dbresult = mysql_query($query,$dblink);
  $row = mysql_fetch_array($dbresult);

  print "<H2>Current Categories</H2>\n";
  print "<FORM METHOD=POST ACTION=$PHP_SELF>\n";
  print "<TABLE BORDER=1>\n";
  print "<TR><TH>Delete?</TH> <TH>Category Code</TH> <TH>Description</TH></TR>\n";
  while ($row = mysql_fetch_array($dbresult))
  {
    print "<TR><TD><INPUT TYPE=checkbox NAME=del_categories[] VALUE={$row["code"]}></TD> <TD>{$row["code"]}</TD> <TD>{$row["description"]}</TD></TR>\n";
  }
  print "</TABLE>\n";
  print "<P><INPUT TYPE=submit NAME=action VALUE=\"Delete Checked Categories\">";
  print "</FORM>\n";

  print "<HR>";
  print "<H2>Add a new category</H2>\n";
  print "<FORM METHOD=POST ACTION=$PHP_SELF>\n";
  print "<TABLE BORDER=0>\n";
  print "<TR><TD>Category Code</tD> <TD><INPUT TYPE=text NAME=code SIZE=6></TD></TR>\n";
  print "<TR><TD>Category Description</tD> <TD><INPUT TYPE=text NAME=description SIZE=25></TD></TR>\n";
  print "</TABLE>\n";
  print "<INPUT TYPE=submit NAME=action VALUE=\"Add New Category\">\n";
  print "</FORM>\n";

?>
<HR>
<P><A HREF=index.php>Return to Index page</A>
<P><I>Designed by <a href=http://www.lunenburg.org/>H. Wade Minter</A> &lt<a href="mailto:minter@lunenburg.org">minter@lunenburg.org</A>&gt.
