#!/usr/bin/wish

# hightlighning configuration
set highlight(types) [list keyword number string include]

set highlight(keyword,config) "-foreground blue"
set highlight(keyword,patterns) for|if|else|assign|set

set highlight(number,config) "-foreground red"
set highlight(number,patterns) \\d

set highlight(string,config) "-background green"
set highlight(string,patterns) (\['\"\]).*?\\1

set highlight(include,config) "-background yellow"
set highlight(include,patterns) \{.*?\}

# gui setup
wm title . richiedit
grid [ttk::notebook .buffers] -
ttk::notebook::enableTraversal .buffers

# debug window
text .debug -height 10 -yscrollcommand [list .debugyscroll set] -xscrollcommand [list .debugxscroll set] -wrap none
scrollbar .debugyscroll -command [list .debug yview] -orient vertical
scrollbar .debugxscroll -command [list .debug xview] -orient horizontal
grid .debug .debugyscroll -stick ns
grid .debugxscroll x -stick ew
grid configure .debug -stick news

grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1

# menu bar
menu .menu -tearoff 0

menu .menu.file -tearoff 0
.menu add cascade -label "File" -menu .menu.file -underline 0
.menu.file add command -label "Save" -command saveFile -underline 0
.menu.file add command -label "Open" -command openFile -underline 0
.menu.file add cascade -label "Open recent" -menu .menu.file.recent -underline 5
.menu.file add command -label "Close" -command [list debug close] -underline 0

menu .menu.file.recent -tearoff 0
.menu.file.recent add command -label "test 1" -command [list debug "test 1"]
.menu.file.recent add command -label "test 2" -command [list debug "test 2"]

. configure -menu .menu


# highlights the last word
proc highlight {textWidget {gobackChars 0}} {
	global highlight

	# determine the right tag for the word
	foreach config $highlight(types) {
		debug $highlight($config,patterns)
		forText $textWidget -regexp $highlight($config,patterns) 1.0 end {
			$textWidget tag add $config matchStart matchEnd
		}
	}
}

# debug procedures
proc bindTest {textWidget keysym} {
	bind $textWidget <KeyRelease-$keysym> [list debug "got: $keysym"]
}

# prints the actual position to the debug widget
proc printPosition {textWidget {gobackChars 0}} {
	debug "[$textWidget index insert]: \
		[$textWidget index [list insert - $gobackChars c wordstart]] - \
		[$textWidget index [list insert - $gobackChars c wordend]]"
}

set i 0
# prints a debug message
proc debug {message} {
	global i
	incr i
	.debug insert end "$i: $message\n"
	.debug see end
}

proc forText {w args} {
	# initialize search command; we may add to it, depending on the
	# arguments passed in...
	set searchCommand [list $w search -count count]

	# Poor man's switch detection
	set i 0
	while {[string match {-*} [set arg [lindex $args $i]]]} {
		if {[string match $arg* -regexp]} {
			lappend searchCommand -regexp
			incr i
		} elseif {[string match $arg* -elide]} {
			lappend searchCommand  -elide
			incr i
		} elseif {[string match $arg* -nocase]} {
			lappend searchCommand  -nocase
			incr i
		} elseif {[string match $arg* -exact]} {
			lappend searchCommand  -exact
			incr i
		} elseif {[string compare $arg --] == 0} {
			incr i
			break
		} else {
			return -code error "bad switch \"$arg\": must be\
			--, -elide, -exact, -nocase or -regexp"
		}
	}

	# parse remaining arguments, and finish building search command
	foreach {pattern start end script} [lrange $args $i end] {break}
	lappend searchCommand $pattern matchEnd searchLimit

	# make sure these are of the canonical form
	set start [$w index $start]
	set end [$w index $end]

	# place marks in the text to keep track of where we've been
	# and where we're going
	$w mark set matchStart $start
	$w mark set matchEnd $start
	$w mark set searchLimit $end

	# default gravity is right, but we're setting it here just to
	# be pedantic. It's critical that matchStart and matchEnd have
	# left and right gravity, respectively, so that any text inserted
	# by the caller duing the search won't normally (*) cause an infinite
	# loop.
	# (*) If the script inserts text after the matchEnd mark, and the
	# text that was added matches the pattern, madness will ensue.
	$w mark gravity searchLimit right
	$w mark gravity matchStart left
	$w mark gravity matchEnd right

	# finally, the part that does useful work. Keep running the search
	# command until we don't find anything else. Each time we find
	# something, adjust the marks and execute the script
	while {1} {
		set cmd $searchCommand
		set index [eval $searchCommand]
		if {[string length $index] == 0} break

		$w mark set matchStart $index
		$w mark set matchEnd  [$w index "$index + $count c"]

		uplevel $script
	}
}

# opens a file in a new buffer
proc openFile {} {
	set filename [tk_getOpenFile]

	# if no file was selected -> return
	if {[string length $filename] == 0} {
		return
	}

	debug "open $filename"
	if {[catch {open $filename r} file]} {
		debug "couldn't open $filename\n$file"
	} else {
		set textWidget [createBuffer $filename]
		$textWidget delete 1.0 end
		$textWidget insert end [read $file]
		if {[catch {close $file} message]} {
			debug "couldn't close $filename\n$message"
		}
	}
}

# saves the current buffer to a file
proc saveFile {} {
	set filename [tk_getSaveFile]

	# if no file was selected -> return
	if {[string length $filename] == 0} {
		return
	}

	debug "save $filename"
	if {[catch {open $filename w} file]} {
		debug "couldn't open $filename\n$file"
	} else {
		puts -nonewline $file [[.buffers select].t get 1.0 end]
		if {[catch {close $file} message]} {
			debug "couldn't close $filename\n$message"
		}

		# set the new buffername
		.buffers tab current -text [file tail $filename]
	}
}

set bufferCounter 0
# creates a new buffer an returns the name of the inner textwidget
proc createBuffer {{name "new file"}} {
	global highlight
	global bufferCounter

	# if we got a real file set the buffername to the filename
	if {[file isfile $name]} {
		set name [file tail $name]
	}

	# create the frame
	set buffer [frame .buffers.buffer[incr bufferCounter]]
	text $buffer.t -yscrollcommand [list $buffer.yscroll set] -xscrollcommand [list $buffer.xscroll set] -wrap none
	scrollbar $buffer.yscroll -command [list $buffer.t yview] -orient vertical
	scrollbar $buffer.xscroll -command [list $buffer.t xview] -orient horizontal
	grid $buffer.t $buffer.yscroll -stick ns
	grid $buffer.xscroll x -stick ew
	grid configure $buffer.t -stick news

	# add the buffer to the bufferlist
	.buffers add $buffer -text $name

	# tag configuration
	foreach config $highlight(types) {
		eval [list $buffer.t tag configure $config] $highlight($config,config)
	}

	# highlight bindings
	bind $buffer.t <KeyRelease-space> [list highlight $buffer.t 2]
	bind $buffer.t <KeyRelease-Tab> [list highlight $buffer.t 2]
	bind $buffer.t <KeyRelease-Return> [list highlight $buffer.t 2]

	return $buffer.t
}
createBuffer
