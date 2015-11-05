#/* Part of the Maestro sequencer software package.
# * Copyright (C) 2011-2015  Operations division of the Canadian Meteorological Centre
# *                          Environment Canada
# *
# * Maestro is free software; you can redistribute it and/or
# * modify it under the terms of the GNU Lesser General Public
# * License as published by the Free Software Foundation,
# * version 2.1 of the License.
# *
# * Maestro is distributed in the hope that it will be useful,
# * but WITHOUT ANY WARRANTY; without even the implied warranty of
# * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# * Lesser General Public License for more details.
# *
# * You should have received a copy of the GNU Lesser General Public
# * License along with this library; if not, write to the
# * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# * Boston, MA 02111-1307, USA.
# */


package require BWidget 1.9
package require Img 

proc MaestroConsole_init {} {
   MaestroConsole_createWidgets
}

proc MaestroConsole_createWidgets {} {
   global gbConsoleX gbConsoleyY
   set topWidget .maestro_console
   if { ! [winfo exists ${topWidget}] } {
      toplevel ${topWidget}
      wm protocol ${topWidget} WM_DELETE_WINDOW \
         [list MestroConsole_closeWindow ${topWidget}]

      wm minsize ${topWidget} 255 200
      wm title ${topWidget} "Maestro Center Console"

      # create toolbar
      set toolbar [MaestroConsole_addToolbar ${topWidget}]

      # create text widget
      set scrolledW [ScrolledWindow ${topWidget}.sw]
      set textW [text ${scrolledW}.txt -wrap word -state disabled -height 20]
      ${textW} tag configure ERROR -foreground red -font bold
      ${textW} tag configure WARNING -foreground "#ff7400" -font bold
      ${textW} tag configure PREFIX -foreground gray55

      ${scrolledW} setwidget ${textW}

      # create status bar
      set statusBar [MaestroConsole_addStatusBar ${topWidget}]
      grid ${toolbar} -row 0 -sticky w
      grid ${scrolledW} -row 1 -sticky nsew
      grid ${statusBar} -row 2 -sticky ew

      grid rowconfigure ${topWidget} 1 -weight 1
      grid columnconfigure ${topWidget} 0 -weight 1

      # at creation, put the console at lower-left corner
      wm geometry ${topWidget} =1200x400+0-0
      if { [MaestroConsole_isActive] == false } {
         MestroConsole_closeWindow ${topWidget}
      }

   } elseif { [MaestroConsole_isActive] == true } {
      MaestroConsole_show
   }

   #MiscTkUtils_positionWindow . ${topWidget}
}

proc MaestroConsole_addToolbar { _topWidget } {
   set toolbarW ${_topWidget}.toolbar

   if { ! [winfo exists ${toolbarW}] } {
      labelframe ${toolbarW} -width 0 -relief flat

      set imageDir [SharedData_getMiscData IMAGE_DIR]
      set quitImage [image create photo ${toolbarW}.quit_image -file ${imageDir}/stop.png]
      set clearImage [image create photo ${toolbarW}.clear_image -file ${imageDir}/message_clear.png]
      set saveImage [image create photo ${toolbarW}.save_image -file ${imageDir}/save_as.png]
      set closeButton [button ${toolbarW}.close_button -image ${quitImage} -relief flat \
            -command [list MestroConsole_closeWindow ${_topWidget}]]
      set clearButton [button ${toolbarW}.clear_button -image ${clearImage} -relief flat \
            -command [list MaestroConsole_clearMsg]]
      set saveButton [button ${toolbarW}.save_button -image ${saveImage} -relief flat \
            -command [list MaestroConsole_saveSelected ${_topWidget}]]

      grid ${clearButton} ${saveButton} ${closeButton} -padx 2 -sticky w

      ::tooltip::tooltip ${closeButton} "Close console window."
      ::tooltip::tooltip ${clearButton} "Clear all console messages."
      ::tooltip::tooltip ${saveButton} "Save console content to file."
   }
   return ${toolbarW}
}

proc MaestroConsole_saveSelected { _topWidget } {
   global env ::errorInfo
   set filename [tk_getSaveFile -parent ${_topWidget} -title "Maestro Center - Save Console" -initialdir $env(HOME)]
   if { ${filename} == "" } {
      return
   }

   ::log::log debug "MaestroConsole_saveSelected filename:${filename}"

   # retrieve data from widget
   set txtWidget ${_topWidget}.sw.txt
   set data ""
   if { [winfo exists ${txtWidget}] } {
      set data [${txtWidget} get 0.0 end]
   }

   MaestroConsole_addMsg "open ${filename} for writing"
   if { [ catch {
      set fileId [open ${filename} w+ 0664]
      MaestroConsole_addMsg "saving ${filename}..."
      puts ${fileId} ${data}
      close ${fileId}
   } errMsg] } {
      if { ${::errorInfo} != "" } {
         MaestroConsole_addErrorMsg ${::errorInfo}
      } else {
         MaestroConsole_addErrorMsg ${errMsg}
      }
      MessageDlg .msg_window -icon error -message "${errMsg}" \
         -title "Maestro Center - Save Error" -type ok -justify center -parent ${_topWidget}
      return
   }
   MaestroConsole_setStatusMsg ${_topWidget} "${filename} saved."
}

proc MaestroConsole_addWarningMsg { _message } {
   MaestroConsole_addMsg ${_message} WARNING
}

proc MaestroConsole_addErrorMsg { _message } {
   MaestroConsole_addMsg ${_message} ERROR
}

proc MaestroConsole_addMsg { _message {_colorTag ""} } {

   if { [MaestroConsole_isActive] == true } {
      MaestroConsole_show
   }

   set textW .maestro_console.sw.txt

   ${textW} configure -state normal

   # keep max 1000 lines
   set numlines [lindex [split [${textW} index end] "."] 0]
   if { ${numlines} == 1000 } { ${textW} delete 1.0 2.0 }
   set prefix [clock format [clock seconds] -format "%Y/%m/%d-%T"]:
   set formattedMsg ${prefix}${_message}
   ${textW} insert end "${prefix}" PREFIX
   if { ${_colorTag} != "" } {
      ${textW} insert end "${_colorTag}: " ${_colorTag}
   }
   ${textW} insert end "${_message}\n"
   ${textW} configure -state disabled
   ${textW} see end
}

proc MaestroConsole_isActive {} {
   set isActive false
   catch {
      set isActive [SharedData_getMiscData MC_SHOW_CONSOLE]
      if { ${isActive} == "" } { set isActive false }
   }
   return ${isActive}
}

proc MaestroConsole_clearMsg {} {
   set textW .maestro_console.sw.txt
   ${textW} configure -state normal
   ${textW} delete 1.0 end
   ${textW} configure -state disabled
   ${textW} see 1.0
   MaestroConsole_setStatusMsg .maestro_console "Console cleared."
}

proc MaestroConsole_show {} {
   set topW .maestro_console
   if { [winfo exists ${topW}] } {
      set currentStatus [wm state ${topW}]
      switch ${currentStatus} {
         withdrawn -
         iconic {
            wm deiconify ${topW}
         }   
      } 
   } else {
      # MaestroConsole_createWidgets
   }
   raise ${topW}
}

proc MaestroConsole_addStatusBar { _topWidget } {
   set statusBarW ${_topWidget}.statusbar
   if { ! [winfo exists ${statusBarW}] } {
      StatusBar ${statusBarW} -showresize true
      set statusFrame [${statusBarW} getframe]
      set statusLabel [label ${statusFrame}.msg_label -font TkSmallCaptionFont]
      ${statusBarW} add ${statusLabel} -weight 1 -sticky w
   }
   return ${statusBarW}
}

# _topWidget must be module flow main toplevel
proc MaestroConsole_setStatusMsg { _topWidget _msg } {
   global ${_topWidget}_status_afterid
   catch { after cancel [set ${_topWidget}_status_afterid] }
   set statusBarW ${_topWidget}.statusbar
   set statusFrame [${statusBarW} getframe]
   set statusLabel ${statusFrame}.msg_label
   ${statusLabel} configure -text ${_msg}
   set ${_topWidget}_status_afterid [after 10000 [list MaestroConsole_clearStatusMsg ${_topWidget}]]
}

proc MaestroConsole_clearStatusMsg { _topWidget } {
   global ${_topWidget}_status_afterid
   set ${_topWidget}_status_afterid ""
   set statusBarW ${_topWidget}.statusbar
   set statusFrame [${statusBarW} getframe]
   set statusLabel ${statusFrame}.msg_label
   ${statusLabel} configure -text ""
}

proc MestroConsole_closeWindow { _topWidget } {
   # destroy ${_topWidget}
   wm withdraw ${_topWidget}
}
