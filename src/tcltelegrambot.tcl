# tcltelegrambot - Tcl interface to Telegram Bot API
# Copyright (C) 2023 Konstantin Kushnir <chpock@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

package require rest
package require json

if { $::tcl_platform(platform) eq "windows" } {

    package require twapi
    package require twapi_crypto

    http::register https 443 [list ::twapi::tls_socket]

}

package provide tcltelegram::bot 1.0.0

set _telegram_bot(sendMessage) {
    url https://api.telegram.org/bot%token%/sendMessage
    req_args { chat_id: text: }
    opt_args {
        message_thread_id: parse_mode: entities:
        disable_web_page_preview: disable_notification:
        protect_content: reply_to_message_id: allow_sending_without_reply:
        reply_markup:
    }
}

set _telegram_bot(getUpdates) {
    url https://api.telegram.org/bot%token%/getUpdates
    opt_args {
        offset: limit: timeout: allowed_updates:
    }
}

set _telegram_bot(getMe) {
    url https://api.telegram.org/bot%token%/getMe
}

rest::create_interface _telegram_bot

oo::class create Telegram::Bot {

    variable AuthToken
    variable LatestUpdateID
    variable UpdateCallbackTimerID
    variable UpdateCallbackInterval
    variable BgerrorCallback

    constructor { args } {

        set UpdateCallbackInterval 1000

        if { [llength $args] } {

            if { [lindex $args 0] ne "-token" } {
                error "Unknown arg: [lindex $args 0]"
            }

            if { [llength $args] != 2 } {
                error "Wrong # args"
            }

            my setAuthToken [lindex $args 1]

        }

    }

    method setAuthToken { token } {

        set AuthToken $token

    }

    method getAuthToken { } {

        if { ![info exists AuthToken] } {
            error "Auth token is not defined."
        }

        return $AuthToken

    }

    method getUpdatesAuto { args } {

        if { ![info exists LatestUpdateID] } {
            tailcall my resetUpdates
        } {
            tailcall my getUpdates {*}[concat $args [list -offset [expr { $LatestUpdateID + 1 }]]]
        }

    }

    method setUpdatesCallback { args } {

        if { ![llength $args] } {

            if { [info exists UpdateCallbackTimerID] } {
                after cancel $UpdateCallbackTimerID
                unset UpdateCallbackTimerID
            }

            return
        }

        my _tickUpdatesCallback [lindex $args 0]

    }

    method resetUpdates { } {
        tailcall my getUpdates -offset -1
    }

    method setBgerrorCallback { callback } {
        set BgerrorCallback $callback
    }

    method unknown { method_name args } {

        if { ![info exists ::_telegram_bot($method_name)] } {
            return -code error "Method $method_name not found."
        }

        ::_telegram_bot::set_static_args -token [my getAuthToken]

        set data [::_telegram_bot::$method_name {*}$args]

        if { [catch { dict get $data ok } ok] } {
            return -code error "Something went wrong. Could not get status: $ok \($data\)"
        }

        if { $ok eq "true" } {

            if { [catch { dict get $data result } result] } {
                return -code error "Something went wrong. Could not get result: $result \($data\)"
            }

            if { $method_name eq "getUpdates" } {
                my _postGetUpdates $result
            }

            return $result

        }

        if { [catch { dict get $data description } description] } {
            return -code error "Something went wrong. Could not get description: $description \($data\)"
        }

        return -code error $description

    }

    method _postGetUpdates { result } {
        foreach update_data $result {
            if { [catch { dict get $update_data update_id } update_id] } {
                return -code error "Could not find the field 'update_id': $result"
            }
            if { ![info exists LatestUpdateID] || $LatestUpdateID < $update_id } {
                set LatestUpdateID $update_id
            }
        }
    }

    method _tickUpdatesCallback { callback } {

        if { [info exists UpdateCallbackTimerID] } {
            after cancel $UpdateCallbackTimerID
            unset UpdateCallbackTimerID
        }

        if { [catch { my getUpdatesAuto } result] } {
            my _tickCallback $callback [self] 0 $result
        } else {
            if { [catch { llength $result } result_count] } {
                my _errorHandler "_tickUpdatesCallback: wrong result: $result_count"
            } else {
                # if updates exist
                if { $result_count } {
                    my _tickCallback $callback [self] 1 $result
                }
            }
        }

        set UpdateCallbackTimerID [after $UpdateCallbackInterval [list [info object namespace [self]]::my _tickUpdatesCallback $callback]]

    }

    method _tickCallback { callback args } {
        if { [catch {
            uplevel #0 $callback $args
        } errmsg] } {
            my _errorHandler "callback failed: $errmsg"
        }
    }

    method _errorHandler { error_message } {
        if { [info exists BgerrorCallback] && $BgerrorCallback ne "" } {
            if { ![catch {
                uplevel #0 $BgerrorCallback [list $error_message]
            } errmsg] } {
                return
            }
            puts stderr "BgerrorCallback: $errmsg"
        }
        puts stderr "Something wrong: $error_message"
    }

}
