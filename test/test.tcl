
set test_chan_name "tcltelegram"
set config_file [file join [file dirname $argv0] test.credentials]

lappend auto_path ../src .

package require tcltelegram::bot

if { ![file exists [file join [file dirname $argv0] test.credentials]] } {
    error "config file test.credentials doesn't exist"
} else {
    set fp [open $config_file r]
    set conf [read $fp]
    close $fp
}

set bot1 [Telegram::Bot new -token [dict get $conf token-1]]
set bot2 [Telegram::Bot new -token [dict get $conf token-2]]

if { ![dict exists $conf chat_id] } {
    puts "Test channel id is unknown. Trying to get it using bot1..."
    set data [$bot1 getUpdates]
    foreach upd $data {
        if {
            [dict exists $upd channel_post chat id] &&
            [dict exists $upd channel_post chat title] &&
            [dict get $upd channel_post chat title] eq $test_chan_name
        } {
            set chat_id [dict get $upd channel_post chat id]
        }
    }
    if { ![info exists chat_id] } {
        puts "ERROR: could not detect test the channel id. Post any message to the channel."
        exit 1
    }
    dict set conf chat_id $chat_id
    set fp [open $config_file w]
    puts -nonewline $fp $conf
    close $fp
}

set test_string "first test string [clock seconds]"

puts "Reset updates for bot1 ..."
$bot1 resetUpdates
puts "Reset updates for bot2 ..."
$bot2 resetUpdates
puts "Send message from bot1 ..."
$bot1 sendMessage -chat_id [dict get $conf chat_id] -text $test_string
puts "Get messages from bot2 ..."
set data [$bot2 getUpdatesAuto]
# get the first update
set data [lindex $data 0]
# check
if { [dict exists $data channel_post text] } {
    if { [dict get $data channel_post text] ne $test_string } {
        puts "ERROR: messages don't match"
        exit 1
    }
} else {
    puts "ERROR: text not found"
    exit 1
}
puts "OK: messages match!"


set test_string "second test string [clock seconds]"

unset -nocomplain done
after 10000 [list set ::done 0]

puts "Set callback on bot1 ..."
$bot1 setUpdatesCallback [list apply { { bot ok result } {
    if { $ok } {
        # get the first update
        set result [lindex $result 0]
        if { [dict exists $result channel_post text] } {
            if { [dict get $result channel_post text] ne $::test_string } {
                puts "ERROR in callback: messages don't match"
                set ::done 0
            }
        } else {
            puts "ERROR in callback: text not found"
            set ::done 0
        }
        puts "OK in callback: messages match!"
        set ::done 1
    } {
        return -code error "Something wrong with callback: $result"
    }
} }]

puts "Send message from bot2 ..."
$bot2 sendMessage -chat_id [dict get $conf chat_id] -text $test_string

vwait ::done

if { $done } {
    puts "OK: callback test"
} else {
    puts "ERROR: callback test"
    exit 1
}

