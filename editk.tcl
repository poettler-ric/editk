#!/usr/bin/wish

# hightlighning configuration
set highlight(types) [list keyword number string include]

set highlight(keyword,config) "-foreground blue"
set highlight(keyword,patterns) [list for|if|else|assign|set]

set highlight(number,config) "-foreground red"
set highlight(number,patterns) [list \\d]

set highlight(string,config) "-background green"
#set highlight(string,patterns) [list (\[_\]).*\\1]
set highlight(string,patterns) [list (\[\\\'\]).*\\1]

set highlight(include,config) "-background yellow"
set highlight(include,patterns) [list \\{.*\\}]

# gui setup
wm title . richiedit
text .t -yscrollcommand [list .yscroll set] -xscrollcommand [list .xscroll set] -wrap none
scrollbar .yscroll -command [list .t yview] -orient vertical
scrollbar .xscroll -command [list .t xview] -orient horizontal
grid .t .yscroll -stick ns
grid .xscroll x -stick ew
grid configure .t -stick news
# debug window
text .debug -height 10 -yscrollcommand [list .debugyscroll set] -xscrollcommand [list .debugxscroll set] -wrap none
scrollbar .debugyscroll -command [list .debug yview] -orient vertical
scrollbar .debugxscroll -command [list .debug xview] -orient horizontal
grid .debug .debugyscroll -stick ns
grid .debugxscroll x -stick ew
grid configure .debug -stick news

grid rowconfigure . 0 -weight 1
grid columnconfigure . 0 -weight 1


# tag configuration
foreach config $highlight(types) {
	eval [list .t tag configure $config] $highlight($config,config)
}

# event bindings
bind .t <KeyRelease-space> [list highlight 2]
bind .t <KeyRelease-Tab> [list highlight 2]
bind .t <KeyRelease-Return> [list highlight 2]

# highlights the last word
proc highlight {{gobackChars 0}} {
	global highlight

	# getting the word
	set beginIndex [.t index [list insert - $gobackChars c wordstart]]
	set endIndex [.t index [list insert - $gobackChars c wordend]]
	set word [string trim [.t get $beginIndex $endIndex]]

	# there is no real word, so nothing to highlight
	if {[string length $word] < 1} {
		return
	}

	# determine the right tag for the word
	foreach config $highlight(types) {
		foreach pattern $highlight($config,patterns) {
			debug $pattern
			if {[regexp $pattern $word]} {
				debug "tag: $config"
				.t tag add $config $beginIndex $endIndex
			}
		}
	}
}

# debug procedures
proc bindTest {keysym} {
	bind .t <KeyRelease-$keysym> [list debug "got: $keysym"]
}

proc printPosition {{gobackChars 0}} {
	debug "[.t index insert]: \
		[.t index [list insert - $gobackChars c wordstart]] - \
		[.t index [list insert - $gobackChars c wordend]]"
}

set i 0
proc debug {message} {
	global i
	incr i
	.debug insert end "$i: $message\n"
	.debug see end
}
