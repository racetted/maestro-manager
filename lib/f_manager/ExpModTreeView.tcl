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


#######################################################################
#######################################################################
# The code in this file contains logic to build the GUI aspect of an
# an experiment modules tree. It reads the data from the ExpModTree
# structure to build the modules tree GUI.
#
#######################################################################
#######################################################################
package require BWidget 1.9
package require Img 

# returns true if the experiment flow manager window is already opened
# returns false otherwise
proc ExpModTreeView_isOpened { _expPath } {
   set topWidget [ExpModTreeView_getTopLevel ${_expPath}]
   if { [winfo exists ${topWidget}] == 1 } {
      return true
   }

   return false
}

# raises the experiment main window
proc ExpModTreeView_toFront { _expPath } {
   set topWidget [ExpModTreeView_getTopLevel ${_expPath}]
   if { [winfo exists ${topWidget}] == 1 } {
      raise ${topWidget}
   }
}

proc ExpModTreeView_createWidgets { _expPath _sourceWidget } {

   set topWidget [ExpModTreeView_getTopLevel ${_expPath}]
   if { [winfo exists ${topWidget}] } {
      destroy ${topWidget}
   }

   toplevel ${topWidget}

   # MiscTkUtils_InitPosition ${topWidget}
   MiscTkUtils_positionWindow  ${_sourceWidget} ${topWidget}

   wm title ${topWidget} "Flow Manager Exp=[file tail ${_expPath}]"

   # post process when window closes
   wm protocol $topWidget WM_DELETE_WINDOW \
      [list ExpModTreeControl_closeWindow ${_expPath} ${topWidget}]

   # store exp value in toplevel widget
   label ${topWidget}.exp_path -text ${_expPath}

   set topFrame [frame ${topWidget}.top_frame]

   # create scrollbable window
   set scrolledW [ScrolledWindow ${topWidget}.canvas_frame -relief sunken -borderwidth 1]
   set modCanvas [canvas ${scrolledW}.mod_tree_canvas -width 500 -height 250]

   # bind mouse rollover
   bind ${modCanvas} <4> [list ${modCanvas} yview scroll -4 units]
   bind ${modCanvas} <5> [list ${modCanvas} yview scroll +4 units]

   ${scrolledW} setwidget ${modCanvas}

   # add file menu
   set fileMenu [ExpModTreeView_addFileMenu ${_expPath} ${topFrame}]

   # add help menu
   set helpMenu [ExpModTreeView_addHelpMenu ${_expPath} ${topFrame}]

   # create toolbar
   set toolbar [ExpModTreeView_addExpToolbar ${_expPath} ${modCanvas}]

   # create statusbar
   set statusBar [ExpModTreeView_addStatusBar ${_expPath} ${topWidget}]
   #set modCanvas [canvas ${topWidget}.mod_tree_canvas]
   #grid ${modCanvas} -row 0 -column 0 -sticky nsew

   # grid ${fileMenu} -row 0 -column 0 -sticky w
   grid ${topFrame} -row 0 -column 0 -sticky w
   grid ${toolbar} -row 1 -column 0 -sticky w
   grid ${scrolledW} -row 2 -column 0 -sticky nsew
   grid ${statusBar} -row 3 -sticky ew

   grid rowconfigure ${topWidget} 2 -weight 1
   grid columnconfigure ${topWidget} 0 -weight 1
}

proc ExpModTreeView_addFileMenu { _expPath _parentWidget } {
   set menuButtonW ${_parentWidget}.menub
   set menuW ${menuButtonW}.menu

   menubutton ${menuButtonW} -text File -underline 0 -menu ${menuW} \
      -relief [SharedData_getMiscData MENU_RELIEF]
   menu ${menuW} -tearoff 0

   ${menuW} add command -label "Quit" -underline 0 -command [list ExpModTreeControl_closeWindow ${_expPath} [winfo toplevel ${_parentWidget}]]
   pack $menuButtonW -side left
   return ${menuButtonW}
}

proc ExpModTreeView_addHelpMenu { _expPath _parentWidget } {
   global env
   set menuButtonW ${_parentWidget}.help_menub
   set menuW ${menuButtonW}.menu

   menubutton ${menuButtonW} -text Help -underline 0 -menu ${menuW} \
      -relief [SharedData_getMiscData MENU_RELIEF]
   menu ${menuW} -tearoff 0

   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   global ${expChecksum}_DebugOn
   set ${expChecksum}_DebugOn false

   ${menuW} add checkbutton -label "Debug" -underline 0 -onvalue true -offvalue false -variable ${expChecksum}_DebugOn \
      -command [list ExpModTreeControl_debugChanged ${_expPath}]

   #::log::lvSuppress debug [set ${expChecksum}_DebugOn]
   #trace add variable ${expChecksum}_DebugOn write {::log::lvSuppress debug [set ${expChecksum}_DebugOn]}
   #trace add variable ${expChecksum}_DebugOn write [list ExpModTreeControl_debugChanged ${_expPath}]

   pack $menuButtonW -side left
   return ${menuButtonW}
}

proc ExpModTreeView_addExpToolbar { _expPath _canvas } {
   set topWidget [ExpModTreeView_getTopLevel ${_expPath}]
   set expToolbar ${topWidget}.toolbar

   if { ! [winfo exists ${expToolbar}] } {
      labelframe ${expToolbar} -width 0 -relief flat

      set imageDir [SharedData_getMiscData IMAGE_DIR]
      set vcsImage [image create photo ${expToolbar}.vcs_image -file ${imageDir}/version_sys.png]
      set flowImage [image create photo ${expToolbar}.flow_image -file ${imageDir}/flow.png]
      set consoleImage [image create photo ${expToolbar}.console_image -file ${imageDir}/console_log.png]
      set quitImage [image create photo ${expToolbar}.quit_image -file ${imageDir}/stop.png]
      #set refreshImage [image create photo ${expToolbar}.refresh_image -file ${imageDir}/refresh.gif]
      #set refreshButton [button ${expToolbar}.refresh_button -image ${refreshImage}  -relief flat]

      set vcsButton [button ${expToolbar}.cvs_button -image ${vcsImage}  -relief flat \
         -command [list ExpModTreeView_vcsSelected ${_expPath} ${expToolbar}]]
      bind ${vcsButton} <KeyPress-Return> [list ExpModTreeView_vcsSelected ${_expPath} ${expToolbar}]
      
      set consoleLogButton [button ${expToolbar}.cons_log_button -image ${consoleImage}  -relief flat -command [list MaestroConsole_show]]
      bind ${consoleLogButton} <KeyPress-Return> [list MaestroConsole_show]

      set quitButton [button ${expToolbar}.quit_button -image ${quitImage}  -relief flat \
         -command [list ExpModTreeControl_closeWindow ${_expPath} ${topWidget}]]
      bind ${quitButton} <KeyPress-Return> [list ExpModTreeControl_closeWindow ${_expPath} ${topWidget}]

      grid ${vcsButton} ${consoleLogButton} ${quitButton} -padx 2 -sticky w

      #::tooltip::tooltip ${refreshButton} "Refresh module tree."
      ::tooltip::tooltip ${vcsButton} "version control system - gui"
      ::tooltip::tooltip ${consoleLogButton} "Show console log window."
      ::tooltip::tooltip ${quitButton} "Close experiment module tree window."
   }
   return ${expToolbar}
}

proc ExpModTreeView_addExpSettingsImg { _expPath _canvas } {
   set imageDir [SharedData_getMiscData IMAGE_DIR]
   set expCfgImage ${_canvas}.exp_cfg_image
   image create photo ${expCfgImage} -file ${imageDir}/config.png

   set iconStartX [expr [SharedData_getMiscData CANVAS_X_START] - 35]
   set iconY [SharedData_getMiscData CANVAS_Y_START]

   ${_canvas} create image ${iconStartX} ${iconY} -image ${expCfgImage} -tag "FlowItems ExpSettings"
   ${_canvas} bind ExpSettings <Double-1> [list ModuleFlowView_goEditor ${_expPath}/experiment.cfg]
   ${_canvas} bind ExpSettings <Button-3> [list ExpModTreeView_addExpSettingsMenu ${_expPath} ${_canvas} %X %Y]

   tooltip::tooltip ${_canvas}  -items ExpSettings "View/edit experiment settings."

   #DrawUtil_drawdashline ${_canvas} 40 40 58 40 none [SharedData_getColor FLOW_SUBMIT_ARROW] off on
   set lineStartX [expr [SharedData_getMiscData CANVAS_X_START] - 20]
   set lineEndX [expr ${lineStartX} + 18]
   DrawUtil_drawline ${_canvas} ${lineStartX} ${iconY} ${lineEndX} ${iconY} none [SharedData_getColor FLOW_SUBMIT_ARROW] off on
}

proc ExpModTreeView_addExpSettingsMenu { _expPath _canvas _x _y } {
   set popMenu .pop_menu
   if { [winfo exists ${popMenu}] } {
      destroy ${popMenu}
   }
   menu .pop_menu -title "Exp Settings"
   ${popMenu} add command -label "Exp Config" -underline 0 -command \
      [list ModuleFlowView_goEditor ${_expPath}/experiment.cfg]
   ${popMenu} add command -label "Exp Resource" -underline 0 -command \
      [list ModuleFlowView_goEditor ${_expPath}/resources/resources.def]
   $popMenu add separator

   tk_popup $popMenu ${_x} ${_y}
}

# recursively deletes every instance of a module record from the
# tree of module nodes
proc ExpModTreeView_deleteNode { _expPath _modTreeNodeRecord } {
   ::log::log debug "ExpModTreeView_deleteNode ${_expPath} ${_modTreeNodeRecord}"
   set childNodes [${_modTreeNodeRecord} cget -children]
   if { ${childNodes} != "" } {
      # delete child nodes first
      foreach childNode ${childNodes} {
         ExpModTreeView_deleteNode ${_expPath} ${childNode}
      }
   }

   set moduleNode [ExpModTree_record2NodeName ${_modTreeNodeRecord}]
   ::log::log debug "ExpModTreeView_deleteNode ModuleFlowView_closeWindow ${_expPath} ${moduleNode}"

   # delete any associated module flow widgets and data structures
   ModuleFlowView_closeWindow ${_expPath} ${moduleNode} true

   # delete respective visual node
   record delete instance [ExpModTreeView_getVisualNodeName ${_modTreeNodeRecord}]

   # delete current node
   record delete instance ${_modTreeNodeRecord}
}

proc ExpModTreeView_addStatusBar { _expPath _topWidget } {
   global ${_topWidget}_status_afterid

   set statusBarW ${_topWidget}.statusbar
   set ${_topWidget}_status_afterid ""

   if { ! [winfo exists ${statusBarW}] } {
      StatusBar ${statusBarW} -showresize true
      set statusFrame [${statusBarW} getframe]
      set statusLabel [label ${statusFrame}.msg_label -font TkSmallCaptionFont]
      ${statusBarW} add ${statusLabel} -weight 1 -sticky w
   }
   return ${statusBarW}
}

proc ExpModTreeView_setStatusMsg { _topWidget _msg } {
   global ${_topWidget}_status_afterid
   after cancel [set ${_topWidget}_status_afterid]
   set statusBarW ${_topWidget}.statusbar
   set statusFrame [${statusBarW} getframe]
   set statusLabel ${statusFrame}.msg_label
   ${statusLabel} configure -text ${_msg}
   set ${_topWidget}_status_afterid [after 10000 [list ExpModTreeView_clearStatusMsg ${_topWidget}]]
}

proc ExpModTreeView_clearStatusMsg { _topWidget } {
   global ${_topWidget}_status_afterid
   set ${_topWidget}_status_afterid ""
   set statusBarW ${_topWidget}.statusbar
   set statusFrame [${statusBarW} getframe]
   set statusLabel ${statusFrame}.msg_label
   ${statusLabel} configure -text ""
}

proc ExpModTreeView_vcsSelected { _expPath _sourceW } {

   set currentDir [pwd]
   cd ${_expPath}
   eval exec git gui &
   cd ${currentDir}
   
}

proc ExpModTreeView_draw { _expPath _entryTreeNodeRecord } {
   ExpModTreeView_clearVisualNodes ${_expPath}

   set modCanvas [ExpModTreeView_getCanvas ${_expPath}]

   DrawUtil_clearCanvas ${modCanvas}
   ExpModTreeView_addExpSettingsImg ${_expPath} ${modCanvas}

   ExpModTreeView_drawModuleNode ${_expPath} ${_entryTreeNodeRecord} 0 true

   DrawUtil_AddCanvasBg ${modCanvas}  [SharedData_getMiscData BG_TEMPLATES_DIR]/artist_canvas_purple.png

   # set scroll region
   set allElementsBox [${modCanvas} bbox all]
   set scrolledRegion [list 0 0 [expr [lindex ${allElementsBox} 2] + 20] [expr [lindex ${allElementsBox} 3] + 20 ]]
   ${modCanvas} configure -scrollregion ${scrolledRegion}
}

proc ExpModTreeView_getTopLevel { _expPath } {
   # replace / by _
   regsub -all "/" ${_expPath} _ widgetName
   # replace . by _
   regsub -all "\\." ${widgetName} _ widgetName

   set topWidget .${widgetName}_modules_tree
}

proc ExpModTreeView_getCanvas { _expPath } {
   set topWidget [ExpModTreeView_getTopLevel ${_expPath}]
   set modCanvas ${topWidget}.canvas_frame.mod_tree_canvas
   return ${modCanvas}
}

proc ExpModTreeView_drawModuleNode { _expPath _modTreeNodeRecord _position { _isRootNode false } } {
   ::log::log debug "ExpModTreeView_drawModuleNode _modTreeNodeRecord:${_modTreeNodeRecord} _position:${_position}"

   set moduleNode [ExpModTree_record2NodeName ${_modTreeNodeRecord}]
   set canvasW [ExpModTreeView_getCanvas ${_expPath}]
   set boxW [SharedData_getMiscData CANVAS_BOX_WIDTH]
   set boxH [SharedData_getMiscData CANVAS_BOX_HEIGHT]
   set pady [SharedData_getMiscData CANVAS_PAD_Y]
   set padTx [SharedData_getMiscData CANVAS_PAD_TXT_X]
   set padTy [SharedData_getMiscData CANVAS_PAD_TXT_Y]
   set shadowColor [SharedData_getColor SHADOW_COLOR]
   set deltaY 0
   set drawshadow on
   set drawLineShadow off

   if { [ExpModTreeControl_isOpenedModule ${_expPath} ${moduleNode}] } {
      set shadowColor [ExpModTreeView_getModuleColor ${_expPath} ${moduleNode}]
   }

   set parentTreeNodeRecord [${_modTreeNodeRecord} cget -parent]
   if { ${_isRootNode} == true } {
      set linex2 [SharedData_getMiscData CANVAS_X_START]
      set liney2 [expr [SharedData_getMiscData CANVAS_Y_START] + ${deltaY}]
   } else {
      set lineColor [SharedData_getColor FLOW_SUBMIT_ARROW]
      # get parent node display coords
      set displayCoords [ExpModTreeView_getModuleCoord ${parentTreeNodeRecord}]
      set px1 [lindex ${displayCoords} 0]
      set px2 [lindex ${displayCoords} 2]
      set py1 [lindex ${displayCoords} 1]
      set py2 [lindex ${displayCoords} 3]

      set lineTagName ${_modTreeNodeRecord}.submit_tag

      ::log::log debug "parent coords: $displayCoords"
      if { ${_position} == 0 } {
         set linex1 $px2
         set liney1 [expr $py1 + ($py2 - $py1) / 2 + $deltaY]
         set liney2 $liney1
         set linex2 [expr $linex1 + $boxW/2]
         DrawUtil_drawdashline ${canvasW} $linex1 $liney1 $linex2 $liney2 last $lineColor ${drawLineShadow} $shadowColor ${lineTagName}
      } else {
         # draw L-shape arrow
         # first draw vertical line
         set nextY [ExpModTreeView_getModuleY ${_modTreeNodeRecord} ${_position}]

         set linex1 [expr $px2 + $boxW/4]
         set linex2 $linex1
         set liney1 [expr $py1 + ($py2 - $py1) / 2 ]
         set liney2 [expr $nextY + ($boxH/4) + $pady + $deltaY]
         DrawUtil_drawdashline ${canvasW} $linex1 $liney1 $linex2 $liney2 none $lineColor ${drawLineShadow} $shadowColor ${lineTagName}
         # then draw hor line with arrow at end
         set linex2 [expr $px2 + $boxW/2]
         set liney1 $liney2
         DrawUtil_drawdashline ${canvasW} $linex1 $liney1 $linex2 $liney2 last $lineColor  ${drawLineShadow} $shadowColor ${lineTagName}
      }
   }
   set normalTxtFill [SharedData_getColor NORMAL_RUN_TEXT]
   set normalFill [SharedData_getColor INIT]
   set outline [SharedData_getColor NORMAL_RUN_OUTLINE]
   # now draw the node
   set tx1 [expr $linex2 + $padTx]
   set ty1 $liney2
   set text [${_modTreeNodeRecord} cget -name]

   DrawUtil_drawBox ${canvasW} $tx1 $ty1 $text $text $normalTxtFill $outline $normalFill ${_modTreeNodeRecord} $drawshadow $shadowColor
   eval ExpModTreeView_setModuleCoord ${_modTreeNodeRecord} [split [${canvasW} bbox ${_modTreeNodeRecord}]]
   if { [ModuleFlow_isModuleNew ${_expPath} ${moduleNode}] == false } {
      # not providing the right click and double-click until the module is saved
      # node menu on right-click
      ${canvasW} bind ${_modTreeNodeRecord} <Button-3> [ list ExpModTreeView_nodeMenu ${canvasW} ${_modTreeNodeRecord} %X %Y]
      # launch module flow on left-double click
      ${canvasW} bind ${_modTreeNodeRecord} <Double-1> [ list ExpModTreeControl_moduleSelection ${_expPath} ${moduleNode} ${canvasW}]
   }

   set childs [${_modTreeNodeRecord} cget -children]
   set childPosition 0
   foreach child ${childs} {
      # set childNode ${_modTreeNodeRecord}/${child}
      ExpModTreeView_drawModuleNode ${_expPath} ${child} ${childPosition}
      incr childPosition
   }
}

# retrieves the color assigned to a module, currently used to draw module shadow color
proc ExpModTreeView_getModuleColor { _expPath _moduleNode } {
   set moduleName [file tail ${_moduleNode}]
   set moduleColor [SharedData_getExpData ${_expPath} ${moduleName}]
   if { ${moduleColor} == "" } {
      set colorNames [SharedData_getColor ColorNames]
      set expColorIndex [SharedData_getExpData ${_expPath} ColorIndex]
      if { ${expColorIndex} == "" } {
         SharedData_setExpData ${_expPath} ColorIndex 0
         set expColorIndex 0
      } elseif { [expr ${expColorIndex} + 1] == [llength ${colorNames}] } {
         set expColorIndex 0
      }
      set moduleColor [lindex ${colorNames} ${expColorIndex}]
      SharedData_setExpData ${_expPath} ColorIndex [expr ${expColorIndex} + 1]
      SharedData_setExpData ${_expPath} ${moduleName} ${moduleColor}
   }
   ::log::log debug "SharedData_getExpData ${_expPath} ${moduleName} color?: ${moduleColor}"

   return ${moduleColor}
}

proc ExpModTreeView_nodeMenu { _canvas _modTreeNodeRecord x y } {
   global HighLightRestoreCmd
   set popMenu .popupMenu
   set moduleNode [ExpModTree_record2NodeName ${_modTreeNodeRecord}]
   # highlight selected node
   set HighLightRestoreCmd ""
   DrawUtil_highLightNode ${_modTreeNodeRecord} ${_canvas} HighLightRestoreCmd
   if { [winfo exists ${popMenu}] } {
      destroy ${popMenu}
   }

   set expPath [[winfo toplevel ${_canvas}].exp_path cget -text]

   menu ${popMenu} -title [${_modTreeNodeRecord} cget -name]
   # when the menu is destroyed, clears the highlighted node
   bind ${popMenu} <Unmap> [list DrawUtil_resetHighLightNode ${HighLightRestoreCmd}]

   ::log::log debug "ExpModTreeView_nodeMenu expPath: ${expPath}"
   ${popMenu} add command -label "open" -underline 0 -command \
      [ list ExpModTreeControl_moduleSelection ${expPath} ${moduleNode} ${_canvas}]
   #$popMenu add separator
   if { [ExpLayout_isModuleOutsideLink ${expPath} ${moduleNode}] == true } {
      $popMenu add separator
      ${popMenu} add command -label "copy locally" -underline 0 -command \
       [list ExpModeTreeControl_copyModule ${expPath} ${moduleNode} ${_canvas}]
   }

   tk_popup $popMenu $x $y
}

# returns the y coordinates that the module shall be displayed based on
# it's parent coordinates, the module position within its parent and
# coordinates of it's previous siblings
proc ExpModTreeView_getModuleY { _modTreeNodeRecord _position } {
   ::log::log debug "ExpModTreeView_getModuleY _modTreeNodeRecord:${_modTreeNodeRecord} _position:${_position}"
   set parentTreeNodeRecord [${_modTreeNodeRecord} cget -parent]
   set parentCoords [ExpModTreeView_getModuleCoord ${parentTreeNodeRecord}]
   if { ${_position} == 0 } {
      # if position 0, the next y is the same as the parent y1
      set nextY [lindex ${parentCoords} 1]
   } else {
      # the next y is the same as the previous sibling y2
      set parentChilds [${parentTreeNodeRecord} cget -children]
      set previousSibling [lindex ${parentChilds} [expr ${_position} - 1]]
      #set previousSiblingCoords [ExpModTreeView_getModuleCoord ${previousSibling}]
      #set nextY [lindex ${previousSiblingCoords} 3]
      set nextY [ExpModTreeView_getBranchMaxY ${previousSibling}]
   }

   return ${nextY}
}

proc ExpModTreeView_getBranchMaxY { _modTreeNodeRecord } {
   ::log::log debug "ExpModTreeView_getBranchMaxY _modTreeNodeRecord:${_modTreeNodeRecord}"
   set nodeCoords [ExpModTreeView_getModuleCoord ${_modTreeNodeRecord}]
   set maxY [lindex ${nodeCoords} 3]
   set childSubmits [${_modTreeNodeRecord} cget -children]
   foreach child ${childSubmits} {
      set childY [ExpModTreeView_getBranchMaxY ${child}]
      if { [expr ${childY} > ${maxY}] } {
         set maxY ${childY}
      }
   }
   return ${maxY}
}

# sets the display coordinates in the visual node.
# creates the module visual node if not exists.
proc ExpModTreeView_setModuleCoord { _modTreeNodeRecord _x1 _y1 _x2 _y2} {
   ::log::log debug "ExpModTreeView_setModuleCoord _modTreeNodeRecord:$_modTreeNodeRecord"
   set visualNodeName [ExpModTreeView_getVisualNodeName ${_modTreeNodeRecord}]

   if { ! [record exists instance ${visualNodeName}] } {
   ::log::log debug "ExpModTreeView_setModuleCoord creating visualNodeName:$visualNodeName"
      FlowVisualNode ${visualNodeName}
   }

   ${visualNodeName} configure -x1 ${_x1} -y1 ${_y1} -x2 ${_x2} -y2 ${_y2}
}

# returns the display coords of the module tree node as
# a list {x1 y1 x2 y2}
# retusn "" if not exists
proc ExpModTreeView_getModuleCoord { _modTreeNodeRecord } {
   ::log::log debug "ExpModTreeView_getModuleCoord _modTreeNodeRecord:$_modTreeNodeRecord"
   set visualNodeName [ExpModTreeView_getVisualNodeName ${_modTreeNodeRecord}]

   ::log::log debug "ExpModTreeView_getModuleCoord visualNodeName:$visualNodeName"
   if { ! [record exists instance ${visualNodeName}] } {
      return ""
   }
   ::log::log debug "ExpModTreeView_getModuleCoord visualNodeName exist!"

   set x1 [${visualNodeName} cget -x1]
   set y1 [${visualNodeName} cget -y1]
   set x2 [${visualNodeName} cget -x2]
   set y2 [${visualNodeName} cget -y2]

   return [list ${x1} ${y1} ${x2} ${y2}]
}

proc ExpModTreeView_getVisualNodeName { _modTreeNodeRecord } {
   set nodeName [ExpModTree_record2NodeName ${_modTreeNodeRecord}]
   set visualNodeName ExpModTreeView.${nodeName}
   return ${visualNodeName}
}

proc ExpModTreeView_clearVisualNodes { expPath } {
   set visualRecords [info commands ExpModTreeView_*]
   foreach visuaRecord ${visualRecords} {
      if { [record exists instance ${visuaRecord}]} {
         record delete instance ${visuaRecord}
      }
   }
}
