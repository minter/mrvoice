<TITLE>Mr. Voice MP3 Database Insertion</TITLE>
<BODY BGCOLOR=#FFFFFF>
<H1>Add a song to the Mr. Voice Database</H1>
<P>This is an online version of my <a href=http://www.greatamericancomedy.com/csz/>ComedySportz-Raleigh</A> Mr. Voice MP3 Database.  You can search for songs in various categories and use the MP3s for your own neferious purposes.
<P>The "Extra Info." modifier is a companion to whichever category you choose to search.  For the "Game" category, it's the name of the game.  For the "Theme/Style" category, it's the type of style.  Etc.
<P>Most of the smaller songs have been edited down to snippets, and automatically fade out at the end.
<HR>
  
<FORM ENCTYPE="multipart/form-data" ACTION="mrvoice-add.php" METHOD=POST>
<TABLE BORDER=0>
<TR><TD>Category</TD> <TD><SELECT NAME=category>

<?
  if (!($dblink = mysql_connect("localhost","mrvoice","howie404")))
  { 
    print "mysql_connect failed\n";
  }

  if (!(mysql_select_db("comedysportz",$dblink)))
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
  $path = "/home/minter/html/csz/";
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
    $filename = ereg_replace ("[^A-Za-z\-]","",$filename);

    if (! file_exists("$path/mp3/$filename.mp3"))
    {
      $filename = "$filename.mp3";
      if (! move_uploaded_file ($UploadFile,"$path/mp3/$filename"))
      {
        print "<FONT COLOR=#FF0000>Rename of uploaded file failed!  Aborting!</FONT>\n";
        exit;
      }
      chmod ("$path/mp3/$filename", 0664);
    }
    else
    {
      $i=1;
      while (++$i)
      {
        if (! file_exists("$path/mp3/$filename$i.mp3"))
        {
          $filename="$filename$i.mp3";
          break;
        }
      }
      if (! move_uploaded_file ($UploadFile,"$path/mp3/$filename"))
      {
        print "<FONT COLOR=#FF0000>Rename of uploaded file failed!  Aborting!</FONT>\n";
      }
      chmod ("$path/mp3/$filename", 0664);

    }
        
    $query = "INSERT INTO mrvoice VALUES (0,'$title','$artist','$category','$extrainfo','/mp3/$filename',NULL)";

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
<I>Designed and maintained by H. Wade Minter &lt<a href="mailto:minter@lunenburg.org?subject=Mr. Voice Database">minter@lunenburg.org</A>&gt.  Did you like this database?  Find it useful?  Drop me a line!</I>
<P><I>Disclaimer: This is an online verison of my voice kit.  There are no guarantees as to quality/usefulness/correctness/etc.  Void where prohibited.</I>
