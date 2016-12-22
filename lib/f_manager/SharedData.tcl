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

package require Thread

# first element in the suites/exp_path is the suite's root_node
# second element in the suites/exp_path is the suite's thread id
proc SharedData_setRootNode { exp_path root_node } {
   set values {}
   if { [tsv::exists suites ${exp_path}] } {
      set values [tsv::set suites ${exp_path}]
   }
   set values [lreplace ${values} 0 0 ${root_node}]
   tsv::set suites ${exp_path} ${values}
}

proc SharedData_getRootNode { exp_path } {
   set returnedValue ""
   if { [tsv::exists suites ${exp_path}] } {
      set values [tsv::set suites ${exp_path}]
      set returnedValue [lindex ${values} 0]
   }
   return ${returnedValue}
}

proc SharedData_setExpData { exp_path key value } {
   if { [tsv::names ${exp_path}] == "" } {
      # does not exists... create it
      set initValues [list ${key} ${value}]
      tsv::array set ${exp_path} ${initValues}
   } else {
      array set values [tsv::array get ${exp_path}]
      set values(${key}) ${value}
      tsv::array set ${exp_path} [array get values]
   }
}

proc SharedData_getExpData { exp_path key } {
   set returnedValue ""
   if { [tsv::exists ${exp_path} ${key}] } {
      array set values [tsv::array get ${exp_path} ${key}]      
      set returnedValue $values(${key})
   }
   return ${returnedValue}
}

proc SharedData_setMiscData { key_ value_ } {
   tsv::set misc ${key_} ${value_}
}

proc SharedData_getMiscData { key_ } {
   set value ""
   if { [tsv::exists misc ${key_}] } {
      set value [tsv::set misc ${key_}]
   }
   return ${value}
}

proc SharedData_getColor { key_ } {
   set value ""
   if { [tsv::exists colors ${key_}] } {
     set value [tsv::set colors ${key_}]
   }
   return ${value}
}

proc SharedData_setColor { key_ color_ } {
   tsv::set colors ${key_} ${color_}
}

proc SharedData_initColors {} {
   if { ! [tsv::exists colors CANVAS_COLOR] } {

      SharedData_setColor FLOW_SUBMIT_ARROW "#787878"
      SharedData_setColor FLOW_SUBMIT_ARROW "#787878"

      SharedData_setColor INIT "#ececec"
      SharedData_setColor CANVAS_COLOR "#ececec"
      SharedData_setColor SHADOW_COLOR "#676559"
      SharedData_setColor NORMAL_RUN_OUTLINE black
      SharedData_setColor NORMAL_RUN_FILL "#6D7886"
      SharedData_setColor NORMAL_RUN_TEXT black
      SharedData_setColor ACTIVE_BG "#509df4"
      SharedData_setColor SELECT_BG "#509df4"
      SharedData_setColor DEFAULT_BG "#ececec"
   }

   # allow 16 colors for module colors
   SharedData_setColor ColorNames { Orange DarkCyan SteelBlue2 tomato VioletRed4 \
                                    IndianRed3 BlueViolet SeaGreen plum3 salmon sienna wheat3 yellow3 MediumVioletRed RosyBrown3 }
}

proc SharedData_initfont {} {
   if { [SharedData_getMiscData FONT_NAME] != "" } {
      # use user defined font
      SharedData_setDefaultFonts [SharedData_getMiscData FONT_NAME] [SharedData_getMiscData FONT_NAME_SIZE] [SharedData_getMiscData FONT_NAME_SLANT] [SharedData_getMiscData FONT_NAME_UNDERL]
      SharedData_setEntryFonts   [SharedData_getMiscData FONT_LABEL] [SharedData_getMiscData FONT_LABEL_SIZE] [SharedData_getMiscData FONT_LABEL_SLANT] [SharedData_getMiscData FONT_LABEL_UNDERL]
  }
}
proc SharedData_setDefaultFonts { {_family fixed} {_size 12} {_slant roman} {_underline 0}} {
   font configure TkDefaultFont -size ${_size} -family ${_family} -slant $_slant  -underline ${_underline}
   font configure TkHeadingFont -size ${_size} -family ${_family} -slant $_slant -underline ${_underline} 
   font configure TkFixedFont -size ${_size} -family ${_family} -slant $_slant -underline ${_underline}
   font configure TkIconFont -size ${_size} -family ${_family} -slant $_slant -underline ${_underline}
   font configure TkCaptionFont -size ${_size} -family ${_family} -slant $_slant -underline ${_underline}
}
proc SharedData_setEntryFonts { {_family fixed} {_size 12} {_slant roman} {_underline 0}} {
  font configure TkTextFont -size ${_size} -family ${_family} -slant $_slant -underline ${_underline} 
  font configure TkMenuFont -size ${_size} -family ${_family} -slant $_slant -underline ${_underline}
  font configure TkTooltipFont -size [expr ${_size} - 2] -family ${_family} -slant $_slant -underline ${_underline}
}
proc SharedData_init {} {
   SharedData_initColors

   #SharedData_setMiscData CANVAS_BOX_WIDTH 90
   SharedData_setMiscData CANVAS_BOX_WIDTH 75
   SharedData_setMiscData CANVAS_LINE_WIDTH 15
   SharedData_setMiscData CANVAS_X_START 60
   SharedData_setMiscData CANVAS_Y_START 40
   SharedData_setMiscData CANVAS_BOX_HEIGHT 43
   SharedData_setMiscData CANVAS_PAD_X 30
   SharedData_setMiscData CANVAS_PAD_Y 15
   SharedData_setMiscData CANVAS_PAD_TXT_X 4
   SharedData_setMiscData CANVAS_PAD_TXT_Y 23
   SharedData_setMiscData CANVAS_SHADOW_OFFSET 5

   SharedData_setMiscData LOOP_OVAL_SIZE 15

   SharedData_setMiscData SHOW_ABORT_TYPE true
   SharedData_setMiscData SHOW_EVENT_TYPE true
   SharedData_setMiscData SHOW_INFO_TYPE true

   SharedData_setMiscData MSG_CENTER_BELL_TRIGGER 15
   SharedData_setMiscData MSG_CENTER_NUMBER_ROWS 25

   SharedData_setMiscData FONT_BOLD "-microsoft-verdana-bold-r-normal--11-*-*-*-p-*-iso8859-10"
   SharedData_setMiscData FONT_NAME "" 
   SharedData_setMiscData FONT_TASK "" 
   SharedData_setMiscData FONT_LABEL "" 
   SharedData_setMiscData FONT_NAME_SIZE 10 
   SharedData_setMiscData FONT_TASK_SIZE 10 
   SharedData_setMiscData FONT_LABEL_SIZE 10 
   SharedData_setMiscData FONT_NAME_STYLE "normal" 
   SharedData_setMiscData FONT_TASK_STYLE "normal" 
   SharedData_setMiscData FONT_LABEL_STYLE "normal" 
   SharedData_setMiscData FONT_NAME_SLANT "roman" 
   SharedData_setMiscData FONT_TASK_SLANT "roman" 
   SharedData_setMiscData FONT_LABEL_SLANT "roman" 
   SharedData_setMiscData FONT_NAME_UNDERL 0 
   SharedData_setMiscData FONT_TASK_UNDERL 0 
   SharedData_setMiscData FONT_LABEL_UNDERL 0 
   SharedData_setMiscData DEBUG_TRACE 1
   SharedData_setMiscData DEBUG_LEVEL 5
   SharedData_setMiscData AUTO_LAUNCH true
   SharedData_setMiscData AUTO_MSG_DISPLAY true
   SharedData_setMiscData NODE_DISPLAY_PREF normal
   SharedData_setMiscData STARTUP_DONE false 

   SharedData_setMiscData DEFAULT_CONSOLE konsole
   SharedData_setMiscData TEXT_VIEWER default
   SharedData_setMiscData USER_TMP_DIR default

   SharedData_setMiscData MENU_RELIEF flat

   SharedData_readProperties
   SharedData_initfont
}

proc SharedData_readProperties {} {
   global env DEBUG_TRACE DEBUG_LEVEL
   set DEBUG_TRACE [SharedData_getMiscData DEBUG_TRACE]
   set DEBUG_LEVEL [SharedData_getMiscData DEBUG_LEVEL]
   set errorMsg ""

   set fileName $env(HOME)/.maestrorc
   if { [file exists ${fileName}] } {
      set propertiesFile [open ${fileName} r]

      while {[gets ${propertiesFile} line] >= 0 && ${errorMsg} == "" } {
         #::log::log debug "SharedData_readProperties processing line: ${line}"
         if { [string index ${line} 0] != "#" && [string length ${line}] > 0 } {
            #puts "SharedData_readProperties found data line: ${line}"
            # the = sign is used to separate between the key and the value.
            # spaces around the values are trimmed
            set splittedList [split ${line} =]

            # if the list does not contain 2 elements, something's not right
            # output the error message
            if { [llength ${splittedList}] != 2 } {
               # error "ERROR: While reading ${fileName}\nInvalid property syntax: ${line}"
               set errorMsg "While reading ${fileName}\n\nInvalid property syntax: ${line}.\n"
            } else {
               set keyFound [string toupper [string trim [lindex $splittedList 0]]]
               set valueFound [string trim [lindex $splittedList 1]]
               ::log::log debug "SharedData_readProperties found key:${keyFound} value:${valueFound}"
               SharedData_setMiscData ${keyFound} ${valueFound}
            }
         }
      }
      catch { close ${propertiesFile} }
      if { ${errorMsg} != "" } {
         ::log::log error "Error reading file ${propertiesFile} : ${errorMsg}"
         error "Error reading file ${propertiesFile} : ${errorMsg}"
      }
   }
}
