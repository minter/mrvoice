<?php

// Note:
// MP3 lib from http://www.jawws.com/ seems to do a whole lot more then my
// little class. If you want something more then this go check it out.

class id3 {
    /*
     * id3 - A Class for reading/writing MP3 ID3 tags
     * 
     * By Leknor <Leknor@Leknor.com> (aka: Sandy McArthur, Jr.)
     * 
     * Copyright 2000 (c) All Rights Reserved, All Responsibility Yours
     *
     * This code is released under the GNU LGPL Go read it over here:
     * http://www.gnu.org/copyleft/lesser.html
     * 
     * I do make one optional request, I would like an account on or a
     * copy of where this code is used. If that is not possible then
     * an email would be cool.
     * 
     * Warning: I really hope this doesn't mess up your MP3s but you
     * are on your own if bad things happen, like don't blame me if
     * your first born dies while using this code.
     *
     * Note: This code doesn't try to deal with corrupt mp3s. So if you get
     * incorrect length times or something else it may be your mp3. To fix just
     * re-enocde from the CD. :~)
     * 
     * eg:
     * 	include('class.id3.php');
     *	$id3 = new id3('/path/to/our lady peace - naveed.mp3');
     *	$id3->comment = 'Go buy some OLP CDs, they rock!';
     *	$id3->write();
     * 
     * This was written from scratch from info freely available on
     * the web.
     * 
     * These site(s) were useful to me:
     *	http://www.php.net/manual/
     *	http://www.mpx.cz/mp3manager/tags.htm
     * 
     * The ID3 Tag format is as follows:
     * 
     * Start at the -128 byte from the end of the file.
     * byte   # of   field
     * range  bytes  description
     * ------------------------------------
     *  0-2    (3)   the tag identifier "TAG"
     *  3-32  (30)   the track name
     * 33-62  (30)   the artists name
     * 63-92  (30)   the album name
     * 93-96   (4)   the album year
     * 97-126 (30)   the comment
     * 127     (1)   the genre - look below
     * 
     * Change Log:
     *	0.92:	Added a @ to silence a warning about divide by zero.
     *	0.91:	Added a @ to silence a warning about 2nd arg in
     *		str_repeat() being 0. And a type that probably messed up
     *		$id3->lengths;
     *	0.9:	Jorge, added code to get the bitrate, time, mpeg version
     *	0.82:	Superficial code clean up
     *	0.81:	first 'release' version
     *
     * Thanks To:
     *	Jorge Cisneros Flores <jorge@e-nexus.com.mx>
     *	H. Wade Minter <minter@lunenburg.org>
     *
     * The most recent version is available at:
     *	http://Leknor.com/code/
     *
     */

    var $_version = 0.92; // Version of the id3 class

    // Anyone got a good way to prevent each instance of the
    // class from needing to allocate a genres array to save
    // a little memory? (I'm thinking of trying a function
    // with a switch) - Leknor
    var $genres = array(
	    0   => 'Blues',
	    1   => 'Classic Rock',
	    2   => 'Country',
	    3   => 'Dance',
	    4   => 'Disco',
	    5   => 'Funk',
	    6   => 'Grunge',
	    7   => 'Hip-Hop',
	    8   => 'Jazz',
	    9   => 'Metal',
	    10  => 'New Age',
	    11  => 'Oldies',
	    12  => 'Other',
	    13  => 'Pop',
	    14  => 'R&B',
	    15  => 'Rap',
	    16  => 'Reggae',
	    17  => 'Rock',
	    18  => 'Techno',
	    19  => 'Industrial',
	    20  => 'Alternative',
	    21  => 'Ska',
	    22  => 'Death Metal',
	    23  => 'Pranks',
	    24  => 'Soundtrack',
	    25  => 'Euro-Techno',
	    26  => 'Ambient',
	    27  => 'Trip-Hop',
	    28  => 'Vocal',
	    29  => 'Jazz+Funk',
	    30  => 'Fusion',
	    31  => 'Trance',
	    32  => 'Classical',
	    33  => 'Instrumental',
	    34  => 'Acid',
	    35  => 'House',
	    36  => 'Game',
	    37  => 'Sound Clip',
	    38  => 'Gospel',
	    39  => 'Noise',
	    40  => 'Alternative Rock',
	    41  => 'Bass',
	    42  => 'Soul',
	    43  => 'Punk',
	    44  => 'Space',
	    45  => 'Meditative',
	    46  => 'Instrumental Pop',
	    47  => 'Instrumental Rock',
	    48  => 'Ethnic',
	    49  => 'Gothic',
	    50  => 'Darkwave',
	    51  => 'Techno-Industrial',
	    52  => 'Electronic',
	    53  => 'Pop-Folk',
	    54  => 'Eurodance',
	    55  => 'Dream',
	    56  => 'Southern Rock',
	    57  => 'Comedy',
	    58  => 'Cult',
	    59  => 'Gangsta',
	    60  => 'Top 40',
	    61  => 'Christian Rap',
	    62  => 'Pop/Funk',
	    63  => 'Jungle',
	    64  => 'Native US',
	    65  => 'Cabaret',
	    66  => 'New Wave',
	    67  => 'Psychadelic',
	    68  => 'Rave',
	    69  => 'Showtunes',
	    70  => 'Trailer',
	    71  => 'Lo-Fi',
	    72  => 'Tribal',
	    73  => 'Acid Punk',
	    74  => 'Acid Jazz',
	    75  => 'Polka',
	    76  => 'Retro',
	    77  => 'Musical',
	    78  => 'Rock & Roll',
	    79  => 'Hard Rock',
	    80  => 'Folk',
	    81  => 'Folk-Rock',
	    82  => 'National Folk',
	    83  => 'Swing',
	    84  => 'Fast Fusion',
	    85  => 'Bebob',
	    86  => 'Latin',
	    87  => 'Revival',
	    88  => 'Celtic',
	    89  => 'Bluegrass',
	    90  => 'Avantgarde',
	    91  => 'Gothic Rock',
	    92  => 'Progressive Rock',
	    93  => 'Psychedelic Rock',
	    94  => 'Symphonic Rock',
	    95  => 'Slow Rock',
	    96  => 'Big Band',
	    97  => 'Chorus',
	    98  => 'Easy Listening',
	    99  => 'Acoustic',
	    100 => 'Humour',
	    101 => 'Speech',
	    102 => 'Chanson',
	    103 => 'Opera',
	    104 => 'Chamber Music',
	    105 => 'Sonata',
	    106 => 'Symphony',
	    107 => 'Booty Bass',
	    108 => 'Primus',
	    109 => 'Porn Groove',
	    110 => 'Satire',
	    111 => 'Slow Jam',
	    112 => 'Club',
	    113 => 'Tango',
	    114 => 'Samba',
	    115 => 'Folklore',
	    116 => 'Ballad',
	    117 => 'Power Ballad',
	    118 => 'Rhytmic Soul',
	    119 => 'Freestyle',
	    120 => 'Duet',
	    121 => 'Punk Rock',
	    122 => 'Drum Solo',
	    123 => 'Acapella',
	    124 => 'Euro-House',
	    125 => 'Dance Hall',
	    126 => 'Goa',
	    127 => 'Drum & Bass',
	    128 => 'Club-House',
	    129 => 'Hardcore',
	    130 => 'Terror',
	    131 => 'Indie',
	    132 => 'BritPop',
	    133 => 'Negerpunk',
	    134 => 'Polsk Punk',
	    135 => 'Beat',
	    136 => 'Christian Gangsta Rap',
	    137 => 'Heavy Metal',
	    138 => 'Black Metal',
	    139 => 'Crossover',
	    140 => 'Contemporary Christian',
	    141 => 'Christian Rock',
	    142 => 'Merengue',
	    143 => 'Salsa',
	    144 => 'Trash Metal',
	    145 => 'Anime',
	    146 => 'Jpop',
	    147 => 'Synthpop'
		);

    var $tag = false;	// id3 tag, usually "TAG" use this to test
   			// if a tag was loaded and what type of tag
			// was loaded
    var $file = false;		// mp3 file name
    var $name = false;		// track name
    var $artists = false;	// artists
    var $album = false;		// album
    var $year = false;		// year
    var $comment = false;	// comment
    var $bitrate = false;	// bitrate
    var $length = false;	// length of mp3 format hh:ss
    var $lengths = false;	// length of mp3 in seconds
    var $mpeg_ver = false;	// version of mpeg
    var $layer = false;		// version of layer
    var $genre = false;		// genre name
    var $genreno = false;	// genre number
    var $error = false;		// if any errors they will be here

    var $rawtag = false;
    var $newtag = false;


    var $id3format = 'a3TAG/a30NAME/a30ARTISTS/a30ALBUM/a4YEAR/a30COMMENT/C1GENRENO';
    var $id3pack = 'a3a30a30a30a4a30C1';
    // Format of the ID3 as understood by unpack
    var $id3unpack = 'a3TAG/a30NAME/a30ARTISTS/a30ALBUM/a4YEAR/a30COMMENT/C1GENRENO';


    /*
    $table = [2][
            [0,  8, 16, 24, 32, 40, 48, 56, 64, 80, 96,112,128,144,160,0],
            [0,  8, 16, 24, 32, 40, 48, 56, 64, 80, 96,112,128,144,160,0],
            [0, 32, 48, 56, 64, 80, 96,112,128,144,160,176,192,224,256,0] 
            ],[1]
            [0, 32, 40, 48, 56, 64, 80, 96,112,128,160,192,224,256,320,0],
            [0, 32, 48, 56, 64, 80, 96,112,128,160,192,224,256,320,384,0],
            [0, 32, 64, 96,128,160,192,224,256,288,320,352,384,416,448,0]
	    ];
     */


    var $debug = false;	// print debugging info?
    var $debugbeg = '<DIV STYLE="margin: 0.5 em; padding: 0.5 em; border-width: thin; border-color: black; border-style: solid">';
    var $debugend = '</DIV>';

    /*
     * id3 constructor - creates a new id3 object and maybe loads a tag
     * from a file.
     *
     * If a file is specified it will try to read it's tag.
     */
    function id3($file = false) {
	if ($this->debug) print($this->debugbeg . "id3($file)<HR>\n");
	if ($file) {
	    $this->file = $file;
	    $this->readhead();
	    $this->read();
	}
	//if ($this->debug) print_r($this->genres);
	if ($this->debug) print($this->debugend);
    }

    /*
     * read - read the tag from a file
     *
     * if a file is specified then it is read else the file specified
     * in $this->file is read.
     *
     * if there is an error it will return false and a message will be
     * put in $this->error
     */
    function read($file = false) {
	if ($this->debug) print($this->debugbeg . "read($file)<HR>\n");

	if ($file === false) {
	    $file = $this->file;
	} else {
	    $this->file = $file;
	}
	if (!$file) {
	    $this->error = 'File not specified';
	    return false;
	}

	if (! ($f = fopen($file, 'rb')) ) {
	    $this->error = 'Unable to open ' . $file;
	    return false;
	}

	if (fseek($f, -128, SEEK_END) == -1) {
	    $this->error = 'Unable to see to end - 128 of ' . $file;
	    return false;
	}

	$r = fread($f, 128);
	fclose($f);

	$this->rawtag = &$r;
	if ($this->debug) {
	    $unp = unpack('h*raw', $this->rawtag);
	    print_r($unp);
	}

	$id3tag = $this->decode();

	$this->tag = $id3tag['TAG'];
	$this->name = $id3tag['NAME'];
	$this->artists = $id3tag['ARTISTS'];
	$this->album = $id3tag['ALBUM'];
	$this->year = $id3tag['YEAR'];
	$this->comment = $id3tag['COMMENT'];
	$this->genreno = $id3tag['GENRENO'];
	$this->genre = $id3tag['GENRE'];

	if ($this->debug) print($this->debugend);
    }

    function readhead($file = false) {
	if ($this->debug) print($this->debugbeg . "read($file)<HR>\n");

	if ($file === false) {
	    $file = $this->file;
	} else {
	    $this->file = $file;
	}
	if (!$file) {
	    $this->error = 'File not specified';
	    return false;
	}

	if (! ($f = fopen($file, 'rb')) ) {
	    $this->error = 'Unable to open ' . $file;
	    return false;
	}
	while(fread($f,1)!="ÿ")  // Loop to find the first frame
	    if ($this->debug) echo "Find...";
	fseek($f,ftell($f)-1);
	$r = fread($f, 4); //Info Header
	fclose($f);
	$header="";
	for($z=0;$z<4;$z++) {
	    // XXX: Added the @ to silence an warning abd 2nd argument being 0, should I care?
	    $header.= @str_repeat("0",8-strlen(decbin(ord(substr($r,$z,1))))).decbin(ord(substr($r,$z,1)));
	    //$header.=str_repeat("0",8-strlen(decbin(ord(substr($r,$z,1))))).decbin(ord(substr($r,$z,1)));
	}
	$this->header = $header;

	switch (substr($header,11,2)) {
	    case "00":
		$this->mpeg_ver = "2.5";
	    $tbl_bit = array(
		    "3"=> array(0,  8, 16, 24, 32, 40, 48, 56, 64, 80, 96,112,128,144,160,0),
		    "2"=> array(0,  8, 16, 24, 32, 40, 48, 56, 64, 80, 96,112,128,144,160,0),
		    "1"=> array(0, 32, 48, 56, 64, 80, 96,112,128,144,160,176,192,224,256,0));
	    break;
	    case "10":
		$this->mpeg_ver = "2";
	    $tbl_bit = array(
		    "3"=> array(0,  8, 16, 24, 32, 40, 48, 56, 64, 80, 96,112,128,144,160,0),
		    "2"=> array(0,  8, 16, 24, 32, 40, 48, 56, 64, 80, 96,112,128,144,160,0),
		    "1"=> array(0, 32, 48, 56, 64, 80, 96,112,128,144,160,176,192,224,256,0));
	    break;
	    case "11":
		$this->mpeg_ver = "1";
	    $tbl_bit = array(
		    "3"=> array(0, 32, 40, 48, 56, 64, 80, 96,112,128,160,192,224,256,320,0),
		    "2"=> array(0, 32, 48, 56, 64, 80, 96,112,128,160,192,224,256,320,384,0),
		    "1"=> array(0, 32, 64, 96,128,160,192,224,256,288,320,352,384,416,448,0));
	    break;
	}
	switch (substr($header,13,2)) {
	    case "01":
		$this->layer = "3";
	    break;
	    case "10":
		$this->layer = "2";
	    break;
	    case "11":
		$this->layer = "1";
	    break;
	}
	$this->bitrate = $tbl_bit[$this->layer][bindec(substr($header,16,4))];
	if ($this->bitrate == 0) {
	    $second = -1;
	} else {
	    $second = ((8*filesize($this->file))/1000)/$this->bitrate;        
	}
	$this->length = sprintf("%02d:%02d",floor($second/60),floor($second-(floor($second/60)*60)));
	$this->lengths = $second;
	$this->tag = $id3tag['TAG'];
	$this->name = $id3tag['NAME'];
	$this->artists = $id3tag['ARTISTS'];
	$this->album = $id3tag['ALBUM'];
	$this->year = $id3tag['YEAR'];
	$this->comment = $id3tag['COMMENT'];
	$this->genreno = $id3tag['GENRENO'];
	$this->genre = $id3tag['GENRE'];
	if ($this->debug) print($this->debugend);
    }



    /*
     * write - write the tag to a file
     *
     * if a file is specified then it is used else the file specified
     * in $this->file is used.
     *
     * if there is an error it will return false and a message will be
     * put in $this->error
     */
    function write($file = false) {
	if ($this->debug) print($this->debugbeg . "write($file)<HR>\n");

	if ($file === false) {
	    $file = $this->file;
	}

	if (!$file) {
	    $this->error = 'File not specified';
	    return false;
	}

	if (! ($f = fopen($file, 'r+b')) ) {
	    $this->error = 'Unable to open ' . $file;
	    return false;
	}

	if (fseek($f, -128, SEEK_END) == -1) {
	    $this->error = 'Unable to see to end - 128 of ' . $file;
	    return false;
	}

	if (!$this->genreno) $this->genreno = 0xff;
	$this->genreno = $this->getgenreno($this->genre);

	$this->newtag = $this->encode();

	$r = fread($f, 128);

	if ($this->decode($r)) {
	    if (fseek($f, -128, SEEK_END) == -1) {
		$this->error = 'Unable to see to end - 128 of ' . $file;
		return false;
	    }
	    fwrite($f, $this->newtag);
	} else {
	    if (fseek($f, 0, SEEK_END) == -1) {
		$this->error = 'Unable to see to end of ' . $file;
		return false;
	    }
	    fwrite($f, $this->newtag);
	}
	fclose($f);


	if ($this->debug) print($this->debugend);
    }

    /*
     * remove - removes the id3 tag from a file
     *
     * returns true if the tag was removed or none was found
     * else false if there was an error
     */
    function remove($file = false) {
	if ($this->debug) print($this->debugbeg . "remove()<HR>\n");

	if ($file === false) {
	    $file = $this->file;
	}

	if (!$file) {
	    $this->error = 'File not specified';
	    return false;
	}

	if (! ($f = fopen($file, 'r+b')) ) {
	    $this->error = 'Unable to open ' . $file;
	    return false;
	}

	if (fseek($f, -128, SEEK_END) == -1) {
	    $this->error = 'Unable to see to end - 128 of ' . $file;
	    return false;
	}

	$r = fread($f, 128);

	$success = false;
	if ($this->decode($r)) {
	    $size = filesize($this->file) - 128;
	    echo $size;
	    if ($size === false) echo 'NOPE!';
	    $success = ftruncate($f, $size);	
	}
	fclose($f);
	if ($this->debug) print($this->debugend);
	return $success;
    }

    /*
     * decode - decodes that ID3 tag
     *
     * false will be returned if there was an error decoding the tag
     * else an array will be returned
     */
    function decode($rawtag = false) {
	if ($this->debug) print($this->debugbeg . "decode($rawtag)<HR>\n");

	if ($rawtag === false) {
	    $rawtag = $this->rawtag;
	}

	$id3tag = unpack($this->id3unpack, $rawtag);
	if ($this->debug) print_r($id3tag);

	if ($id3tag['TAG'] == 'TAG') {
	    $id3tag['GENRE'] = $this->getgenre($id3tag['GENRENO']);
	} else {
	    $this->error = 'TAG not found';
	    $id3tag = false;
	}
	if ($this->debug) print($this->debugend);
	return $id3tag;
    }

    /*
     * encode - encode the ID3 tag
     *
     * the newly built tag will be returned
     */
    function encode() {
	if ($this->debug) print($this->debugbeg . "encode()<HR>\n");

	$this->tag = 'TAG'; // If other tags supported then change this
	$newtag = pack($this->id3pack,
		$this->tag,
		$this->name,
		$this->artists,
		$this->album,
		$this->year,
		$this->comment,
		$this->genreno);

	if ($this->debug) {
	    if ($this->rawtag) {
		$unp = unpack('h*raw', $this->rawtag);
		print_r($unp);
	    }

	    $unp = unpack('h*new', $newtag);
	    print_r($unp);
	}

	if ($this->debug) print($this->debugend);
	return $newtag;
    }

    /*
     * getgenre - return the name of a genre number
     *
     * if no genre number is specified the genre number from
     * $this->genreno will be used.
     *
     * the genre is returned or false if an error or not found
     * no error message is ever returned
     */
    function getgenre($genreno = false) {
	if ($this->debug) print($this->debugbeg . "getgenre($genreno)<HR>\n");
	if ($genreno === false) {
	    $genreno = $this->genreno;
	}

	if (isset($this->genres[$genreno])) {
	    $genre = $this->genres[$genreno];
	    if ($this->debug) print($genre . "\n");
	} else {
	    $genre = false;
	}

	if ($this->debug) print($this->debugend);
	return $genre;
    }

    /*
     * getgenreno - return the number of the genre name
     *
     * if no genre name is specified the genre name from
     * $this->genre will be used.
     *
     * the genre number is returned or 0xff (255) if a match is not found
     * you can specify the default genreno to use if one is not found
     * no error message is ever returned
     */
    function getgenreno($genre = false, $default = 0xff) {
	if ($this->debug) print($this->debugbeg . "getgenreno($genreno)<HR>\n");

	if ($genreno === false) {
	    $genre = $this->genre;
	}

	$genreno = false;
	if ($genre) {
	    foreach ($this->genres as $no => $name) {
		if (strtolower($genre) == strtolower($name)) {
		    $genreno = $no;
		}
	    }
	}
	if ($genreno === false) $genreno = $default;
	if ($this->debug) print($this->debugend);
	return $genreno;
    }
} // end of id3

?>
