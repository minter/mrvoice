<? 
   include ("config.php");
   # CVS ID: $Id: mrvoice-add.php,v 1.6 2001/02/25 23:07:29 minter Exp $
?>

<TITLE>Mr. Voice MP3 Database Insertion</TITLE>
<BODY BGCOLOR=#FFFFFF>
<H1>Add/Modify the Mr. Voice Database</H1>

<P>Use this form to add or modify songs in the Mr. Voice database.
<HR>
  
<?
  if (!($dblink = mysql_connect($database_host,$database_username,$database_password)))
  { 
    print "mysql_connect failed\n";
  }

  if (!(mysql_select_db("$database",$dblink)))
  {
    print "mysql_select_db failed\n";
  }

  if ($type == "Edit")
  {
    print "<P>Editing the following entry...\n";
    $query = "SELECT * from mrvoice where id=$id";
    $dbresult = mysql_query($query,$dblink);
    $row = mysql_fetch_array($dbresult);
    $edit_category = $row["category"];
    $edit_artist = $row["artist"];
    $edit_title = $row["title"];
    $edit_info = $row["info"];
    $edit_filename = $row["filename"];
  }

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
  elseif ($action == "Edit")
  {
    $query = "UPDATE mrvoice SET title='$title', artist='$artist', category='$category', info='$extrainfo', filename='$filename' WHERE id=$id";
    if (!($dbresult = mysql_query($query,$dblink)))
    {
      print "<FONT COLOR=#FF0000>mysql_query failed using query $query</FONT>\n";
      print "<P>The error message was " . mysql_error();
    }
    else
    {
      print "<FONT COLOR=#00FF00>Edit successful!</FONT>\n";
    }
    mysql_close($dblink);
    print "<META http-equiv=\"Refresh\" CONTENT=\"1; URL=$PHP_SELF?type=Edit&id=$id\">";
    exit();
  }

?>

<FORM ENCTYPE="multipart/form-data" ACTION="<? print $PHP_SELF ?>" METHOD=POST>
<TABLE BORDER=0>
<TR><TD>Category</TD> <TD><SELECT NAME=category>
<?
  $query = "SELECT * FROM categories ORDER BY description";

  $dbresult = mysql_query($query,$dblink);
 
  while ($row = mysql_fetch_array($dbresult))
  {
    print "<OPTION VALUE={$row[0]} ";
    if ($row[0] == $edit_category) print "SELECTED";
    print ">{$row[1]}\n";
  }
?>

</SELECT></TD></TR>
<TR><TD>Category Extra Info.</TD> <TD><INPUT TYPE=text SIZE=25 NAME=extrainfo VALUE='<? print $edit_info ?>'></TD></TR>
<TR><TD>Artist</TD> <TD><INPUT TYPE=text SIZE=25 NAME=artist VALUE='<? print $edit_artist ?>'></TD></TR>
<TR><TD>Title</TD> <TD><INPUT TYPE=text SIZE=25 NAME=title VALUE='<? print $edit_title ?>'></TD></TR>
<?
  if ($type == "Edit")
  {
    print "<TR><TD>Filename</TD> <TD><INPUT NAME=filename TYPE=text SIZE=50 VALUE='$edit_filename'></TD></TR>\n";
  }
  else
  {
    print "<TR><TD>File To Upload</TD> <TD><INPUT NAME=UploadFile TYPE=file></TD></TR>";
  }
  if ($type == "Edit") print "<INPUT TYPE=HIDDEN NAME=id VALUE=$id>\n";
  print "</TABLE>\n";
  if ($type == "Edit")
  {
    print "<INPUT TYPE=submit NAME=action VALUE=Edit>  \n";
  }
  else
  {
    print "<INPUT TYPE=submit NAME=action VALUE=Add>  \n";
  }
?>

</FORM>
  

<HR>
<P><A HREF=index.php>Return to Index page</A>
<P><I>Designed by <a href=http://www.lunenburg.org/>H. Wade Minter</A> &lt<a href="mailto:minter@lunenburg.org">minter@lunenburg.org</A>&gt.

