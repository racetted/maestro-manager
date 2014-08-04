#######################################################################
#######################################################################
# The code in this file contains logic to build the GUI aspect of an
# a module flow. It reads the data from the ModuleFlow tree
# structure to build the GUI of the module flow.
#
#######################################################################
#######################################################################
package require BWidget 1.9
package require textutil::trim
package require cksum
package require Img 

proc ModuleFlowView_initModule { _expPath _moduleNode {_sourceWidget .} } {
   set flowXmlFile [ModuleLayout_getFlowXml ${_expPath} ${_moduleNode}]
   if { ! [file readable ${flowXmlFile}] } {
      MessageDlg .msg_window -icon warning -message "Cannot read ${flowXmlFile}" -aspect 400 \
         -title "Application Warning" -type ok -justify center -parent ${_sourceWidget}
      return
   }

   if { [ catch { 
      set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]

      if { [winfo exists ${topWidget}] } {
         ModuleFlowView_toFront ${_expPath} ${_moduleNode}
      } else {
         # we force the reading of the module flow.xml everytime the module
         # is opened
         ModuleFlow_refresh ${_expPath} ${_moduleNode}

         ModuleFlowView_createWidgets ${_expPath} ${_moduleNode}
         MiscTkUtils_positionWindow ${_sourceWidget} ${topWidget}
         ModuleFlowView_draw ${_expPath} ${_moduleNode}
      }

      ModuleFlow_setModuleChanged ${_expPath} ${_moduleNode} false
   } errMsg] } {
      global ::errorInfo
      MaestroConsole_addErrorMsg ${errMsg}
      if { ${::errorInfo} != "" } {
         MaestroConsole_addErrorMsg ${::errorInfo}
      }
      MessageDlg .msg_window -icon error -message "An error happend while displaying the module flow. Check the maestro console for more details." \
         -title "Error Window" -type ok -justify center -parent ${_sourceWidget}
   }
}

proc ModuleFlowView_createWidgets { _expPath _moduleNode } {
   ModuleFlowView_setWidgetNames ${_expPath} ${_moduleNode}
   set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
   if { [winfo exists ${topWidget}] } {
      destroy ${topWidget}
   }

   toplevel ${topWidget}
   wm title ${topWidget} "Exp=[file tail ${_expPath}] Module=[file tail ${_moduleNode}] (${_moduleNode})"

   # post process when window closes
   wm protocol ${topWidget} WM_DELETE_WINDOW \
      [list ModuleFlowView_closeWindow ${_expPath} ${_moduleNode}]

   # store exp value and module path in toplevel widget
   Label ${topWidget}.exp_path -text ${_expPath}
   Label ${topWidget}.mod_node_name -text ${_moduleNode}

   set topFrame [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} topframe]
   frame ${topFrame}

   ModuleFlowView_addFileMenu ${_expPath} ${_moduleNode} ${topFrame}
   ModuleFlowView_addHelpMenu ${_expPath} ${_moduleNode} ${topFrame}

   # create toolbar
   set toolbar [ModuleFlowView_addToolbar ${_expPath} ${_moduleNode} ${topWidget}]

   # create scrollbable window
   set scrolledW [ScrolledWindow ${topWidget}.canvas_frame -relief sunken -borderwidth 1]
   set flowCanvas [canvas ${scrolledW}.flow_canvas -width 600 -height 350 ]

   # bind mouse rollover
   bind ${flowCanvas} <4> [list ${flowCanvas} yview scroll -4 units]
   bind ${flowCanvas} <5> [list ${flowCanvas} yview scroll +4 units]
   ${scrolledW} setwidget ${flowCanvas}
   #set flowCanvas [canvas ${topWidget}.flow_canvas]

   # create statusbar
   set statusBar [ModuleFlowView_addStatusBar ${_expPath} ${_moduleNode} ${topWidget}]

   # grid ${flowCanvas} -row 0 -column 0 -sticky nsew
   grid ${topFrame} -row 0 -column 0 -sticky w
   grid ${toolbar} -row 1 -sticky w
   grid ${scrolledW} -row 2 -sticky nsew
   grid ${statusBar} -row 3 -sticky ew

   grid rowconfigure ${topWidget} 2 -weight 1
   grid columnconfigure ${topWidget} 0 -weight 1
   #grid columnconfigure ${topWidget} 1 -weight 1

   # make sure we have a clean working dir
   ModuleLayout_clearWorkingDir ${_expPath} ${_moduleNode}
}

proc ModuleFlowView_addFileMenu { _expPath _moduleNode _parentWidget } {
   set menuButtonW ${_parentWidget}.file_menub
   set menuW ${menuButtonW}.menu

   menubutton ${menuButtonW} -text File -underline 0 -menu ${menuW} \
      -relief [SharedData_getMiscData MENU_RELIEF]
   menu ${menuW} -tearoff 0

   ${menuW} add command -label "Quit" -underline 0 \
      -command [list ModuleFlowView_closeWindow ${_expPath} ${_moduleNode}]

   pack $menuButtonW -side left

   return ${menuButtonW}
}

proc ModuleFlowView_addHelpMenu { _expPath _moduleNode _parentWidget } {
   global env
   set menuButtonW ${_parentWidget}.help_menub
   set menuW ${menuButtonW}.menu

   menubutton ${menuButtonW} -text Help -underline 0 -menu ${menuW} \
      -relief [SharedData_getMiscData MENU_RELIEF]
   menu ${menuW} -tearoff 0

   set sampleTaskFile $env(SEQ_MANAGER_BIN)/../etc/samples/task_resources.xml
   set sampleContainerFile $env(SEQ_MANAGER_BIN)/../etc/samples/container_resources.xml

   ${menuW} add command -label "Sample Task Resource" -underline 7 \
      -command [list ModuleFlowView_goEditor ${sampleTaskFile}]
   ${menuW} add command -label "Sample Container Resource" -underline 7 \
      -command [list ModuleFlowView_goEditor ${sampleContainerFile}]
   pack $menuButtonW -side left
   return ${menuButtonW}
}

proc ModuleFlowView_addToolbar { _expPath _moduleNode _topWidget } {
   set toolbarW ${_topWidget}.toolbar

   if { ! [winfo exists ${toolbarW}] } {
      labelframe ${toolbarW} -width 0 -relief flat

      set imageDir [SharedData_getMiscData IMAGE_DIR]
      set cvsImage [image create photo ${toolbarW}.mod_cvs_image -file ${imageDir}/version_sys.png]
      set saveImage [image create photo ${toolbarW}.mod_save_image -file ${imageDir}/save.png]
      # set undoImage [image create photo ${toolbarW}.mod_undo_image -file ${imageDir}/undo.gif]
      set reloadImage [image create photo ${toolbarW}.mod_refresh_image -file ${imageDir}/reload.png]
      set quitImage [image create photo ${toolbarW}.quit_image -file ${imageDir}/stop.png]

      set saveButton [button ${toolbarW}.save_button -image ${saveImage} -relief flat -state disabled \
         -command [list ModuleFlowControl_saveSelected ${_expPath} ${_moduleNode} ${_topWidget}]]
      bind ${saveButton} <KeyPress-Return> [list ModuleFlowControl_saveSelected ${_expPath} ${_moduleNode} ${_topWidget}]

      # set undoButton [button ${toolbarW}.undo_button -image ${undoImage} -relief flat -state disabled]

      set refreshButton [button ${toolbarW}.refresh_button -image ${reloadImage} -relief flat \
         -command [list ModuleFlowControl_refreshSelected ${_expPath} ${_moduleNode} ${_topWidget}]]
      bind ${refreshButton} <KeyPress-Return> [list ModuleFlowControl_refreshSelected ${_expPath} ${_moduleNode} ${_topWidget}]

      set vcsButton [button ${toolbarW}.vcs_button -image ${cvsImage} -relief flat  -state disabled]
      # bind ${vcsButton} <KeyPress-Return>

      set closeButton [button ${toolbarW}.close_button -image ${quitImage} -relief flat \
            -command [list ModuleFlowView_closeWindow ${_expPath} ${_moduleNode}]]
      bind ${closeButton} <KeyPress-Return> [list ModuleFlowView_closeWindow ${_expPath} ${_moduleNode}]
      grid ${saveButton} ${refreshButton} ${vcsButton} ${closeButton} -padx 2 -sticky w

      # ${_canvas} create window 25 30 -window ${expCanvasBar} -anchor n
      ::tooltip::tooltip ${saveButton} "Save modified flow."
      # ::tooltip::tooltip ${toolbarW}.undo_button "Undo last flow change."
      ::tooltip::tooltip ${refreshButton} "Reload current flow, undo all changes."
      ::tooltip::tooltip ${vcsButton} "version control system - gui"
      ::tooltip::tooltip ${closeButton} "Close module flow window."
   }
   return ${toolbarW}
}

proc ModuleFlowView_addStatusBar { _expPath _moduleNode _topWidget } {
   global ${_topWidget}_status_afterid
 
   set ${_topWidget}_status_afterid ""
   set statusBarW ${_topWidget}.statusbar
   if { ! [winfo exists ${statusBarW}] } {
      StatusBar ${statusBarW} -showresize true
      set statusFrame [${statusBarW} getframe]
      set statusLabel [label ${statusFrame}.msg_label -font TkSmallCaptionFont]
      ${statusBarW} add ${statusLabel} -weight 1 -sticky w
   }
   return ${statusBarW}
}

# enable save button to allow user to save a modified flow
# save is enable whenever changes are done on the flow
# i.e. adding/deleting nodes
proc ModuleFlowView_saveStatus { _expPath _moduleNode _status } {
   if { [ExpLayout_isModuleWritable ${_expPath} ${_moduleNode}] == true } {
      set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
      set saveButton [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} save_button]
      ${saveButton} configure -state ${_status}
      if { ${_status} == "normal" } {
         ModuleFlow_setModuleChanged ${_expPath} ${_moduleNode} true
      }
   }
}

# notifies the user once about module read-only
# notification is done only once per module window instance
proc ModuleFlowView_checkReadOnlyNotify { _expPath _moduleNode } {
   if { [ExpLayout_isModuleWritable ${_expPath} ${_moduleNode}] == false } {
      set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
      global ${moduleId}_Module_Writable
      if { ! [info exists ${moduleId}_Module_Writable] } {
         set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
         MessageDlg .msg_window -icon warning -message "This module is read-only, you will not be allowed to save the flow." \
               -aspect 400 -title "Module Flow Notification" -type ok -justify center -parent ${topWidget}
         set ${moduleId}_Module_Writable 1
      }
   }
}

# warns user that there are unsaved changes to the flow before refreshing or quitting the current window
proc ModuleFlowView_flowChangeNotify { _expPath _moduleNode _topWidget } {
   set isContinue true
   set answer [MessageDlg .msg_window -icon warning -message "There are unsaved changes to the module flow, are you sure you want to continue?" \
         -aspect 400 -title "Module Flow Notification" -type okcancel -justify center -parent ${_topWidget}]
   if { ${answer} == 1 } {
      set isContinue false
   }
   return ${isContinue}
}

proc ModuleFlowView_multiEditNotify { _expPath _moduleNode _topWidget } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_Module_Multi_Instance
   set isContinue true

   if { [ExpModTree_getModInstances ${_expPath} ${_moduleNode}] > 1 } {
      if { ! [info exists ${moduleId}_Module_Multi_Instance] } {
         # we only ask the user once per module flow opening
         set answer [MessageDlg .msg_window -icon warning -message "This module is used in more than one instance in the experiment, are you sure you want to continue?" \
               -aspect 400 -title "Module Flow Notification" -type okcancel -justify center -parent ${_topWidget}]
         if { ${answer} == 1 } {
            set isContinue false
         }
         set ${moduleId}_Module_Multi_Instance 1
      }
   }

   return ${isContinue}
}

# ask a user whether he wants to copy a linked module locally
# if true, copy locally
# returns true if the copy was done
# returns false if not
proc ModuleFlowView_copyLocalNotify { _expPath _moduleNode _sourceWidget } {
   # I'm using the same variable to notify the user only once
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_Module_Writable

   set topWidget [winfo toplevel ${_sourceWidget}]
   set isCopied false
   if { ! [info exists ${moduleId}_Module_Writable] } {
      set modInstances [ExpModTree_getModInstances ${_expPath} ${_moduleNode}]
      set extraMsg ""
      if { ${modInstances} > 1 } {
         set extraMsg "\n\nNote: The [file tail ${_moduleNode}] module is used in ${modInstances} different locations within the experiment."
      }
      set answer [MessageDlg .msg_window -icon warning -message "This module ([file tail ${_moduleNode}]) is a referenced module and is read-only, \
          do you want to copy the referenced module locally?${extraMsg}" \
            -aspect 800 -title "[file tail ${_moduleNode}] Rename Notification" -type yesno -justify center -parent ${topWidget}]
      if { ${answer} == 0 } {
         # copy local
         set isCopied true
         if { [ catch { ModuleFlowControl_copyLocalSelected ${_expPath} ${_moduleNode} } errMsg ] } {
            MessageDlg .msg_window -icon error -message "${errMsg}" \
               -title "Module Copy Error" -type ok -justify center -parent ${topWidget}
            return false
         }
         MessageDlg .msg_window -icon info -message "The module has been copied locally." \
            -aspect 400 -title "Module Flow Notification" -type ok -justify center -parent ${topWidget}
      }
   }
   return ${isCopied}
}

# _topWidget must be module flow main toplevel
proc ModuleFlowView_setStatusMsg { _topWidget _msg } {
   global ${_topWidget}_status_afterid
   after cancel [set ${_topWidget}_status_afterid]
   set statusBarW ${_topWidget}.statusbar
   set statusFrame [${statusBarW} getframe]
   set statusLabel ${statusFrame}.msg_label
   ${statusLabel} configure -text ${_msg}
   set ${_topWidget}_status_afterid [after 10000 [list ModuleFlowView_clearStatusMsg ${_topWidget}]]
}

proc ModuleFlowView_clearStatusMsg { _topWidget } {
   global ${_topWidget}_status_afterid
   set ${_topWidget}_status_afterid ""
   set statusBarW ${_topWidget}.statusbar
   if { [winfo exists ${statusBarW}] } {
      set statusFrame [${statusBarW} getframe]
      set statusLabel ${statusFrame}.msg_label
      ${statusLabel} configure -text ""
   }
}

proc ModuleFlowView_getModNode { _sourceWidget } {
   set topWidget [winfo toplevel ${_sourceWidget}]
   return [${topWidget}.mod_node_name cget -text]
}

proc ModuleFlowView_getExpPath { _sourceWidget } {
   set topWidget [winfo toplevel ${_sourceWidget}]
   return [${topWidget}.exp_path cget -text]
}

proc ModuleFlowView_getTopLevel { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   set topWidget .module_flow_${moduleId}
}

proc ModuleFlowView_getCanvas { _expPath _moduleNode } {
   set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
   # set flowCanvas ${topWidget}.flow_canvas
   set flowCanvas ${topWidget}.canvas_frame.flow_canvas
   return ${flowCanvas}
}

# make sure everything is cleaned before destroying widgets
proc ModuleFlowView_closeWindow { _expPath _moduleNode {_force false} } {
   ::log::log debug "ModuleFlowView_closeWindow ${_expPath} ${_moduleNode} ... "
   set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
   global ${topWidget}_status_afterid

   if { ${_force} == true || [ModuleFlow_isModuleChanged ${_expPath} ${_moduleNode}] == false || 
        [ModuleFlowView_flowChangeNotify ${_expPath} ${_moduleNode} ${topWidget}] == true } {

      if { [ModuleFlow_isModuleChanged ${_expPath} ${_moduleNode}] == true } {
         # clears current node records and reread module flow.xml
         ModuleFlow_refresh ${_expPath} ${_moduleNode}
      }

      set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

      # close global variables set my the module
      foreach globalVar [info globals ${moduleId}*] {
         global [set globalVar]
         unset [set globalVar]
      }

      ModuleFlowView_clearVisualNodes ${_moduleNode}

      # clear module working directory
      ModuleLayout_clearWorkingDir ${_expPath} ${_moduleNode}

      ModuleFlow_cleanup ${_expPath} ${_moduleNode}

      # destroy all module records, this part is only executed when the
      # the user closes the whole experiment, all flow node records needs to be cleaned up.
      # When the user closes the module only and not the whole exp, the records are kept in memory
      if { ${_force} == true } {
         ModuleFlow_cleanRecords ${_expPath} ${_moduleNode}
      } 

      # close any dormant callbacks
      if { [info exists ${topWidget}_status_afterid] } {
         after cancel [set ${topWidget}_status_afterid]
         unset ${topWidget}_status_afterid
      }

      ModuleFlowView_clearWidgetNames ${_expPath} ${_moduleNode}

      # any cleanup to do at module tree level?
      ExpModTreeControl_moduleClosing ${_expPath} ${_moduleNode}

      # delete widgets
      destroy ${topWidget}

      
      ::log::log debug "ModuleFlowView_closeWindow ${_expPath} ${_moduleNode} done"
      
   }
}

proc ModuleFlowView_draw { _expPath _moduleNode } {
   ::log::log debug "ModuleFlowView_draw _moduleNode:${_moduleNode}"

   set flowCanvas [ModuleFlowView_getCanvas ${_expPath} ${_moduleNode}]

   # first clear canvas
   DrawUtil_clearCanvas ${flowCanvas}

   ModuleFlowView_clearVisualNodes ${_moduleNode}

   set recordName [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   ModuleFlowView_drawNode ${flowCanvas} ${recordName} 0 true
   DrawUtil_AddCanvasBg ${flowCanvas}  [SharedData_getMiscData BG_TEMPLATES_DIR]/artist_canvas_blue.png
   set allElementsBox [${flowCanvas} bbox all]
   set scrolledRegion [list 0 0 [lindex ${allElementsBox} 2] [lindex ${allElementsBox} 3]]
   ${flowCanvas} configure -scrollregion ${scrolledRegion}
   ::log::log debug "ModuleFlowView_draw _moduleNode:${_moduleNode} done"
}

proc ModuleFlowView_drawNode { _canvas _flowNodeRecord _position { _isRootNode false } } {
   ::log::log debug "ModuleFlowView_drawNode _flowNodeRecord:${_flowNodeRecord} canvas:${_canvas} _position:${_position}"

   # mapping of draw procedures for each node type
   # first is proc to draw the node icon
   # second is proc to draw leading line to node
   # if type is not in Map, defaults to DrawUtil_drawBox DrawUtil_drawline
   set nodeTypeDrawMap {   
                           TaskNode "DrawUtil_drawBox DrawUtil_drawline"
                           NpassTaskNode "DrawUtil_drawRoundBox DrawUtil_drawline"
                           FamilyNode "DrawUtil_drawBox DrawUtil_drawline"
                           LoopNode "DrawUtil_drawOval DrawUtil_drawline"
                           ModuleNode "DrawUtil_drawBox DrawUtil_drawdashline"
                           SwitchNode "DrawUtil_drawLosange DrawUtil_drawline"
                       }
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set expPath [ModuleFlowView_getExpPath ${_canvas}]
   set boxW [SharedData_getMiscData CANVAS_BOX_WIDTH]
   set boxH [SharedData_getMiscData CANVAS_BOX_HEIGHT]
   set pady [SharedData_getMiscData CANVAS_PAD_Y]
   set padTx [SharedData_getMiscData CANVAS_PAD_TXT_X]
   set padTy [SharedData_getMiscData CANVAS_PAD_TXT_Y]
   set shadowColor [SharedData_getColor SHADOW_COLOR]
   set deltaY [ModuleFlowView_getLineDeltaSpace ${_flowNodeRecord}]
   set drawshadow on
   set drawLineShadow off
   set nodeType [${_flowNodeRecord} cget -type]
   set drawNodeProc [lindex [string map ${nodeTypeDrawMap} ${nodeType}] 0]
   set drawLineProc [lindex [string map ${nodeTypeDrawMap} ${nodeType}] 1]

   set parentNode [ModuleFlow_getSubmitter ${_flowNodeRecord}]
   set context [ModuleFlowView_getModNode ${_canvas}]
   set lineSubmitIcon [ModuleFlowView_getNodeSubmitIcon ${expPath} ${_flowNodeRecord}]
   if { ${_isRootNode} == true } {
      set linex2 [SharedData_getMiscData CANVAS_X_START]
      set liney2 [expr [SharedData_getMiscData CANVAS_Y_START] + ${deltaY}]
      set shadowColor [ExpModTreeView_getModuleColor ${expPath} ${flowNode}]
   } else {
      set lineColor [SharedData_getColor FLOW_SUBMIT_ARROW]

      # get parent node display coords
      set displayCoords [ModuleFlowView_getNodeCoord ${parentNode} ${context}]
      set px1 [lindex ${displayCoords} 0]
      set px2 [lindex ${displayCoords} 2]
      set py1 [lindex ${displayCoords} 1]
      set py2 [lindex ${displayCoords} 3]

      set lineTagName ${_flowNodeRecord}.submit_tag

      if { ${_position} == 0 } {
         set linex1 [expr $px2 + [SharedData_getMiscData CANVAS_SHADOW_OFFSET] - 1]
         #set linex1 $px2
         set liney1 [expr $py1 + ($py2 - $py1) / 2 + $deltaY]
         set liney2 $liney1
         set linex2 [expr $linex1 + $boxW/2]
         ${drawLineProc} ${_canvas} $linex1 $liney1 $linex2 $liney2 ${lineSubmitIcon} $lineColor ${drawLineShadow} $shadowColor ${lineTagName}
      } else {
         # draw L-shape arrow
         # first draw vertical line
         set nextY [ModuleFlowView_getNodeY ${_flowNodeRecord} ${context} ${_position}]

         set linex1 [expr $px2 + $boxW/4]
         set linex2 $linex1
         set liney1 [expr $py1 + ($py2 - $py1) / 2 ]
         set liney2 [expr $nextY + ($boxH/4) + $pady + $deltaY]
         ${drawLineProc} ${_canvas} $linex1 $liney1 $linex2 $liney2 none $lineColor ${drawLineShadow} $shadowColor ${lineTagName}
         # then draw hor line with arrow at end
         set linex2 [expr $px2 + $boxW/2]
         set liney1 $liney2
         ${drawLineProc} ${_canvas} $linex1 $liney1 $linex2 $liney2 ${lineSubmitIcon} $lineColor  ${drawLineShadow} $shadowColor ${lineTagName}
      }
   }
   set normalTxtFill [SharedData_getColor NORMAL_RUN_TEXT]
   set normalFill [SharedData_getColor INIT]
   set outline [SharedData_getColor NORMAL_RUN_OUTLINE]
   # now draw the node
   set tx1 [expr $linex2 + $padTx]
   set ty1 $liney2

   foreach { tx1 ty1 } [ModuleFlowView_addWorkUnitIndicator ${_canvas} ${_flowNodeRecord} ${tx1} ${ty1}] {break}

   set text [ModuleFlowView_getNodeText ${expPath} ${_flowNodeRecord} ${context}]

   ${drawNodeProc} ${_canvas} $tx1 $ty1 $text $text $normalTxtFill $outline $normalFill ${_flowNodeRecord} $drawshadow $shadowColor
   
   eval ModuleFlowView_setNodeCoord ${_flowNodeRecord} ${context} [split [${_canvas} bbox ${_flowNodeRecord}.main]]
   ${_canvas} bind ${_flowNodeRecord} <Button-3> [ list ModuleFlowView_nodeMenu ${_canvas} ${_flowNodeRecord} %X %Y]

   if { ${nodeType} == "SwitchNode" } {
      set indexListW [DrawUtils_getIndexWidgetName ${_flowNodeRecord} ${_canvas}]
      ${indexListW} configure -modifycmd [list ModuleFlowView_indexedNodeSelection ${_flowNodeRecord} ${_canvas} ${indexListW}]
      eval ModuleFlowView_setNodeCoord ${_flowNodeRecord} ${context} [split [${_canvas} bbox ${_flowNodeRecord}]]
      # bypass the switch item 
      if { [${_flowNodeRecord} cget -type] == "SwitchNode" && [${_flowNodeRecord} cget -switch_items] != "" } {
         set switchItemNodeRecord [ModuleFlow_getCurrentSwitchItemRecord ${_flowNodeRecord}]
         if { ${switchItemNodeRecord} != "" } {
            set _flowNodeRecord ${switchItemNodeRecord}
            ::log::log debug "ModuleFlowView_drawNode SwitchNode _flowNodeRecord:${_flowNodeRecord}"
         }
      }
   }

   # if it is a reference module, stop
   # else draw the children nodes
   if { ${nodeType} == "ModuleNode" && ${_isRootNode} == false } {
      # show reference module on double click
      ${_canvas} bind ${_flowNodeRecord} <Double-1> \
         [list ExpModTreeControl_moduleSelection ${expPath} ${flowNode}]
   } else {
      set childs [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]
      set childPosition 0
      foreach child ${childs} {
         ModuleFlowView_drawNode ${_canvas} ${child} ${childPosition}
         incr childPosition
      }
   }
}

proc ModuleFlowView_indexedNodeSelection { _flowNodeRecord _canvas _indexWidget } {
   puts "ModuleFlowView_indexedNodeSelection _flowNodeRecord:${_flowNodeRecord}"
   set expPath [ModuleFlowView_getExpPath ${_canvas}] 
   set moduleNode [ModuleFlowView_getModNode ${_canvas}]
   if { [${_indexWidget} getvalue] != -1 } {
      set selected [${_indexWidget} get]
      ${_flowNodeRecord} configure -curselection ${selected}
      # refresh module flow
      ModuleFlowView_draw ${expPath} ${moduleNode}
   }
}

proc ModuleFlowView_getLineDeltaSpace { _flowNodeRecord {_deltaValue 0} } {
   set value ${_deltaValue}
   # I only need to calculate extra space if the current node is not in position 0
   # in it's parent node. If it is in position 0, the extra space has already been calculated.
   if { [ModuleFlow_getSubmitPosition ${_flowNodeRecord}] != 0 } {
      set done 0
      set nodeRecord ${_flowNodeRecord}
      while { ! ${done} } {
         # for now only loops needs be treated
         if { [${nodeRecord} cget -type] == "LoopNode" } {
            if { [expr ${value} < [SharedData_getMiscData LOOP_OVAL_SIZE]] } {
               set value [SharedData_getMiscData LOOP_OVAL_SIZE]
            }
         }
         set submitNodeRecords [ModuleFlow_getSubmitRecords ${nodeRecord}]
         # i'm only interested in the first position of the submit list, the others will be calculated
         # when we move down the tree
         set submitNodeRecord [lindex ${submitNodeRecords} 0]
         if { ${submitNodeRecord} != "" } {
            # move further down the tree
            set nodeRecord ${submitNodeRecord}
         } else {
            set done 1
         }
      }
   }
   return $value
}


# add a striped circle before the node box to indicate the
# the start of a single reservation branch
# returns coords of modified x and y after image creation if exists
#                    modified x is start_x + width of created img
#                    y is startY
# else returns startX and startY
# 
proc ModuleFlowView_addWorkUnitIndicator { _canvas _flowNodeRecord _startX _startY } {
   global SingleReservImg
   if { [${_flowNodeRecord} cget -work_unit] == true } {
      if { [info exists SingleReservImg] == 0 } {
         set SingleReservImg [image create photo -file [SharedData_getMiscData IMAGE_DIR]/round_stripe.png]
      }

      ${_canvas} create image ${_startX} ${_startY} -image ${SingleReservImg} -tags "FlowItems ${_flowNodeRecord} ${_flowNodeRecord}.work_unit"
      return [list [expr ${_startX} + [image height $SingleReservImg] + 1] ${_startY}]
   }
   return [list ${_startX} ${_startY}]
}

proc ModuleFlowView_getNodeText { _expPath _flowNodeRecord _context } {
   set value [${_flowNodeRecord} cget -name]
   set flowNode  [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   ::log::log debug "ModuleFlowView_getNodeText flowNode:${flowNode} context:${_context}"
   if { [${_flowNodeRecord} cget -type] == "ModuleNode" && ${flowNode} == ${_context} } {
      # if the node is the first node of the module
      # it might be a reference module... if the module is a link, we display both
      # the link name the name of the module it is referencing
      set moduleRefName [ExpModTree_getReferenceName ${_expPath} ${flowNode}]
      if { ${moduleRefName} != "" &&  ${moduleRefName} != ${value}} {
         set value "${moduleRefName}\n(${value})"
      }
      set value /${value}
   } else {
      if { [ModuleFlow_isContainer ${_flowNodeRecord}] == true } {
         set value /${value}
      }
   }
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set value "${value}\n\[[${_flowNodeRecord} cget -switch_mode]\]"
   }

   return ${value}
}

proc ModuleFlowView_getNodeSubmitIcon { _expPath _flowNodeRecord } {
   set submitArrow last
   if { [${_flowNodeRecord} cget -type] == "NpassTaskNode" } {
      set submitArrow none
   }
   return ${submitArrow}
}

proc ModuleFlowView_nodeMenu { _canvas _flowNodeRecord x y } {
   global HighLightRestoreCmd
   set popMenu .popupMenu

   if { ! [record exists instance ${_flowNodeRecord}] } {
      MessageDlg .msg_window -icon error -message "The node does not exists! The module window should be closed." -aspect 400 \
         -title "Flow Manager Error" -type ok -justify center -parent ${_canvas}
      return
   }

   # highlight selected node
   set HighLightRestoreCmd ""
   DrawUtil_highLightNode ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd

   if { [winfo exists ${popMenu}] } {
      destroy ${popMenu}
   }

   menu ${popMenu} -title [${_flowNodeRecord} cget -name]

   # when the menu is destroyed, clears the highlighted node
   bind ${popMenu} <Unmap> [list DrawUtil_resetHighLightNode ${HighLightRestoreCmd}]

   set menuCount 0
   ModuleFlowView_addMenuConfig ${popMenu} ${_canvas} ${_flowNodeRecord}
   ModuleFlowView_addMenuSource ${popMenu} ${_canvas} ${_flowNodeRecord}
   ModuleFlowView_addMenuResource ${popMenu} ${_canvas} ${_flowNodeRecord}

   ${popMenu} add separator
   ModuleFlowView_addMenuAdd ${popMenu} ${_canvas} ${_flowNodeRecord}
   ModuleFlowView_addMenuDelete ${popMenu} ${_canvas} ${_flowNodeRecord}
   ModuleFlowView_addMenuEdit ${popMenu} ${_canvas} ${_flowNodeRecord}
   ModuleFlowView_addMenuRename ${popMenu} ${_canvas} ${_flowNodeRecord}
   # ${popMenu} add command -label "Edit" -underline 0 -state disabled
   ${popMenu} add separator
   ModuleFlowView_addMenuOpen ${popMenu} ${_canvas} ${_flowNodeRecord}

   tk_popup ${popMenu} $x $y
}

proc ModuleFlowView_highLightBranch { _flowNodeRecord _canvas _restoreCmd } {
   upvar #0 ${_restoreCmd} evalCmdList

   DrawUtil_highLightNode ${_flowNodeRecord} ${_canvas} ${_restoreCmd}
   set submitNodes [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]
   foreach submitNode ${submitNodes} {
      ModuleFlowView_highLightBranch ${submitNode} ${_canvas} ${_restoreCmd}
   }
}

# decides if Config menu item will be added
proc ModuleFlowView_addMenuConfig { _menu _canvas _flowNodeRecord } {

   set state normal
   # allow config except if it is a called module node
   if { [${_flowNodeRecord} cget -type] == "ModuleNode" } {
      set currentModule [file tail [ModuleFlowView_getModNode ${_canvas}]]
      if { [file tail ${_flowNodeRecord}] != ${currentModule} } {
         # it's a module but not current one, config not allowed within
         # current module
         set state disabled
      }
   }

   if { ${state} == "normal" } {
      ${_menu} add command -label "Config" -underline 0 -state ${state} -command \
      [list ModuleFlowControl_configSelected [ModuleFlowView_getExpPath ${_canvas}] ${_flowNodeRecord}]
   }
   #${_menu} add command -label "Config" -underline 0 -state ${state} -command \
   #   [list ModuleFlowControl_configSelected [ModuleFlowView_getExpPath ${_canvas}] ${_flowNodeRecord}]
}

proc ModuleFlowView_addMenuSource { _menu _canvas _flowNodeRecord } {
   set state normal
   if { [ModuleFlow_isContainer ${_flowNodeRecord}] == true } {
      set state disabled
   }

   ${_menu} add command -label "Source" -underline 0 -state ${state} -command \
      [list ModuleFlowControl_sourceSelected [ModuleFlowView_getExpPath ${_canvas}] ${_flowNodeRecord}]
}

proc ModuleFlowView_addMenuOpen { _menu _canvas _flowNodeRecord } {
   set moduleNode [ModuleFlowView_getModNode ${_canvas}]
   set state normal
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   if { [${_flowNodeRecord} cget -status] == "new" } {
      set state disabled
   } else {

      # allow launch of referenced module on double click
      if { [${_flowNodeRecord} cget -type] != "ModuleNode" || 
           ([${_flowNodeRecord} cget -type] == "ModuleNode" && ${flowNode} == ${moduleNode}) } {
         set state disabled
      }
   }

   set expPath [ModuleFlowView_getExpPath ${_canvas}] 
   ${_menu} add command -label "Open" -underline 0 -state ${state} -command \
      [list ExpModTreeControl_moduleSelection [ModuleFlowView_getExpPath ${_canvas}] ${flowNode}]
}

proc ModuleFlowView_addMenuResource { _menu _canvas _flowNodeRecord } {
   set state normal
   if { [${_flowNodeRecord} cget -type] == "ModuleNode" && [${_flowNodeRecord} cget -status] == "new" } {
      set state disabled
   }
   ${_menu} add command -label "Resource" -underline 0 -state ${state} -command \
      [list ModuleFlowControl_resourceSelected [ModuleFlowView_getExpPath ${_canvas}] ${_flowNodeRecord}]
}

proc ModuleFlowView_addMenuEdit { _menu _canvas _flowNodeRecord } {
   set state disabled
   set nodeType [${_flowNodeRecord} cget -type]
   set addLabel Edit
   if { ${nodeType} == "SwitchNode" } {
         set state normal
   }
   ${_menu} add command -label ${addLabel} -underline 0 -state ${state}  -command \
      [list ModuleFlowView_createNodeEditWidgets [ModuleFlowView_getModNode ${_canvas}] ${_canvas} ${_flowNodeRecord}]
}

proc ModuleFlowView_addMenuAdd { _menu _canvas _flowNodeRecord } {
   set state normal
   set nodeType [${_flowNodeRecord} cget -type]
   set addLabel Add
   if { ${nodeType} == "ModuleNode" } {
      set currentModule [file tail [ModuleFlowView_getModNode ${_canvas}]]
      if { [file tail ${_flowNodeRecord}] != ${currentModule} } {
         # it's a module but not current one, add not allowed within
         # current module
         set state disabled
      }
   } elseif { ${nodeType} == "SwitchNode" } {
      set currentSwitchItem [ModuleFlowView_getCurrentSwitchItem [ModuleFlowView_getExpPath ${_canvas}] ${_flowNodeRecord} ${_canvas}]
      if { ${currentSwitchItem} != "" } {
         set addLabel "Add to branch ${currentSwitchItem}"
      } else {
         # no valid switch item selected... no add possible
         set state disabled
      }
   }
   ${_menu} add command -label ${addLabel} -underline 0 -state ${state} -command \
      [list ModuleFlowView_createNodeAddWidgets [ModuleFlowView_getModNode ${_canvas}] ${_canvas} ${_flowNodeRecord}]
}

proc ModuleFlowView_addMenuDelete { _menu _canvas _flowNodeRecord } {
   set moduleNode [ModuleFlowView_getModNode ${_canvas}]
   set moduleTailName [file tail ${moduleNode}]
   set expPath [ModuleFlowView_getExpPath ${_canvas}]
   set nodeType [${_flowNodeRecord} cget -type]
   if { [ModuleFlow_record2NodeName ${_flowNodeRecord}] ==  ${moduleNode} } {
      # delete is not allowed on the root module node of a module flow
      ${_menu} add command -label "Delete" -underline 0 -state disabled
   } else {
      if { ${nodeType} == "SwitchNode" } {
         set currentSwitchItem [ModuleFlowView_getCurrentSwitchItem [ModuleFlowView_getExpPath ${_canvas}] ${_flowNodeRecord} ${_canvas}]
         if { ${currentSwitchItem} != "" } {
            set deleteLabel "Delete branch ${currentSwitchItem}"
            ${_menu} add command -label ${deleteLabel} -underline 0 \
               -command [list ModuleFlowControl_deleteNodeSelected ${expPath} ${moduleNode} ${_canvas} ${_flowNodeRecord} ${currentSwitchItem}]
         }
      }
      if { ( ${nodeType} == "ModuleNode" && [file tail ${_flowNodeRecord}] != ${moduleTailName} ) ||
         [${_flowNodeRecord} cget -submits] == "" } {

         # leaf node
         ${_menu} add command -label "Delete" -underline 0 \
            -command [list ModuleFlowControl_deleteNodeSelected ${expPath} ${moduleNode} ${_canvas} ${_flowNodeRecord}]
      } else {
         # add delete submenu
         set deleteMenu ${_menu}.delete_menu
         ${_menu} add cascade -label "Delete" -underline 0 -menu [menu ${deleteMenu}]
         ${deleteMenu} add command -label "Single Node" -underline 0 \
            -command [list ModuleFlowControl_deleteNodeSelected ${expPath} ${moduleNode} ${_canvas} ${_flowNodeRecord}]
         ${deleteMenu} add command -label "Branch" -underline 0 \
            -command [list ModuleFlowControl_deleteNodeSelected  ${expPath} ${moduleNode} \
               ${_canvas} ${_flowNodeRecord} true]
      }
   }
}

proc ModuleFlowView_addMenuRename { _menu _canvas _flowNodeRecord } {
   set moduleNode [ModuleFlowView_getModNode ${_canvas}]
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set flowNodeName [file tail ${flowNode}]
   set expPath [ModuleFlowView_getExpPath ${_canvas}]
   if { [${_flowNodeRecord} cget -status] != "new" && ${flowNode} !=  ${moduleNode} } {
      ${_menu} add command -label "Rename" -underline 2 -command \
         [list ModuleFlowView_renameNodeWidgets ${moduleNode} ${_canvas} ${_flowNodeRecord}]
   } else {
      proc out {} {
         if { [${_flowNodeRecord} cget -type] == "ModuleNode" && [ExpModTree_getModInstances ${expPath} ${flowNode}] > 1 } {
            ${_menu} add command -label "Rename" -underline 2 -command \
            [list ModuleFlowView_renameNodeWidgets ${moduleNode} ${_canvas} ${_flowNodeRecord} ]
            # same module used more than once
            # add rename submenu
            # set renameMenu ${_menu}.rename_menu
            # ${_menu} add cascade -label "Rename" -underline 2 -menu [menu ${renameMenu}]
            # ${renameMenu} add command -label "Current ${flowNodeName}" -underline 0 \
            #   -command [list ModuleFlowView_renameNodeWidgets ${moduleNode} ${_canvas} ${_flowNodeRecord}]
            # ${renameMenu} add command -label "All ${flowNodeName}" -underline 0 \
            #   -command [list ModuleFlowView_renameNodeWidgets ${moduleNode} ${_canvas} ${_flowNodeRecord} true]
         } else {
            ${_menu} add command -label "Rename" -underline 2 -command \
               [list ModuleFlowView_renameNodeWidgets ${moduleNode} ${_canvas} ${_flowNodeRecord}]
         }
      }
      ${_menu} add command -label "Rename" -underline 2 -state disabled
   }
}

# user has selected to add a new node to be submitted
# by the _flowNodeRecord
proc ModuleFlowView_createNodeAddWidgets { _moduleNode _canvas _flowNodeRecord } {
   ::log::log debug "ModuleFlowView_createNodeAddWidgets _moduleNode:${_moduleNode} _flowNodeRecord:${_flowNodeRecord}"
   global  HighLightRestoreCmd
   set expPath [ModuleFlowView_getExpPath ${_canvas}]
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]

   if { [ModuleFlowView_multiEditNotify ${expPath} ${_moduleNode} [winfo toplevel ${_canvas}]] == false } {
      return
   }

   if { [ExpLayout_isModuleWritable ${expPath} ${_moduleNode}] == false } {
      set isCopied [ModuleFlowView_copyLocalNotify ${expPath} ${_moduleNode} ${_canvas}]
      if { ${isCopied} == false } {
         ModuleFlowView_checkReadOnlyNotify ${expPath} ${_moduleNode}
      }
   }
   set moduleId [ExpLayout_getModuleChecksum ${expPath} ${_moduleNode}]

   # the type option is used to hold the values of node type selection
   global ${moduleId}_TypeOption ${moduleId}_Link_Module ${moduleId}_work_unit ${moduleId}_SwitchModeOption

   # hightlight parent flow node
   set HighLightRestoreCmd ""
   DrawUtil_highLightNode ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd

   set modeNodeName ${_moduleNode}

   # create add new node toplevel
   set topWidget [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} addnode_top_widget]
   if { [winfo exists ${topWidget}] } {
      destroy ${topWidget}
   }

   toplevel ${topWidget}

   MiscTkUtils_positionWindow ${_canvas} ${topWidget}
   # when window is destroyed, clears the highlighted node
   bind ${topWidget} <Destroy> [list DrawUtil_resetHighLightNode ${HighLightRestoreCmd}]

   # create frame to hold all needed fields
   set entryFrame [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} addnode_entry_frame]
   frame ${entryFrame} -relief sunken -bd 1

   # create a position label & field... this allows the user to set at which position
   # he wants the new node to be created (if node already submits other nodes)
   set positionLabel [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} addnode_pos_label]
   Label ${positionLabel} -text "Position:"

   set nofSubmits [llength [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]]
   set positionSpinW [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} addnode_pos_spinbox]
   set typeOption [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_type_option] 

   set hasSiblings [ModuleFlow_hasSubmitSiblings ${_flowNodeRecord}]
   if { ${nofSubmits} == 0 && ${hasSiblings} == false } {
      spinbox ${positionSpinW} -values 0 -state disabled -wrap yes
   } else {
      set values {}
      set initialValue 0
      set count 0
      while { ${count} <= ${nofSubmits} } {
         set values [lappend values ${count}]
	 if { ${count} == ${nofSubmits} } { set initialValue  ${count} }
         incr count
      }

      if { ${nofSubmits} > 0 } { lappend values serial }

      # parent node replaces current node and submits current node... but you cannot do it for a module node
      if { ${hasSiblings} == true && [${_flowNodeRecord} cget -type] != "ModuleNode" } {
         lappend values "parent"
      }
      spinbox ${positionSpinW} -values ${values} -wrap yes -bg white
      ${positionSpinW} set ${initialValue}

   }
   ${positionSpinW} configure -command [list ModuleFlowView_addPositionChanged ${positionSpinW} ${typeOption}]

   # creates node type label & selection field
   set typeLabel [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} addnode_type_label]
   Label ${typeLabel} -text "Type:"

   catch { unset ${moduleId}_TypeOption }
   tk_optionMenu ${typeOption} ${moduleId}_TypeOption TaskNode NpassTaskNode FamilyNode ModuleNode LoopNode SwitchNode

   # check if we shoud disable some node type items
   ModuleFlowView_addPositionChanged ${positionSpinW} ${typeOption}

   # creates node name label & entry field
   set nameLabel [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_name_label]
   set nameEntry [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_name_entry]
   Label ${nameLabel} -text "Name:"
   Entry ${nameEntry} -bg white -validate all \
      -vcmd {
         # allow wordchar and dot characters only
         # replace dot by _ so we can test
         regsub -all . %P _ tmpentry
         if { [string is wordchar ${tmpentry}] } {
            return 1
         }
         return 0
      }

   # creates module reference label & field
   set refLabel [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_ref_label]
   set refEntry [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_ref_entry]
   # ref button starts a file selection dialog allowing users to select the wanted module
   set refButton [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_ref_button]
   Label ${refLabel} -text "Module Path:"
   ComboBox ${refEntry} -values [ModuleFlowControl_getDepotModules]

   ${refEntry} configure -modifycmd [list ModuleFlowView_newNodeRefEntryCallback ${expPath} ${_moduleNode} ${refEntry}]
   Button ${refButton} -text "..." -command [list ModuleFlowView_newNodeRefButtonCallback ${expPath} ${_moduleNode} ${refButton} ]
   ::tooltip::tooltip  ${nameEntry} "Name of the new node."
   ::tooltip::tooltip  ${refEntry} "Reference to an existing module; to create a new module, leave empty."
   ::tooltip::tooltip  ${refButton} "Module selection dialog."

   # creates checkbox to ask whether use module link
   # only visible if user selects module node
   set useModLinkLabel [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_link_label]
   set useModLinkCb [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_link_cb]
   Label ${useModLinkLabel} -text "Link Module:"
   checkbutton ${useModLinkCb} -indicatoron true -variable ${moduleId}_Link_Module \
      -onvalue true -offvalue false
   set ${moduleId}_Link_Module true

   # creates checkbox to ask whether the container is a work_unit i.e. supertask
   set workUnitLabel [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_wunit_label]
   set workUnitCb [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_wunit_cb]
   Label ${workUnitLabel} -text "Work Unit:"
   checkbutton ${workUnitCb} -indicatoron true -variable ${moduleId}_work_unit \
      -onvalue true -offvalue false
   set ${moduleId}_work_unit false

   ::tooltip::tooltip  ${workUnitCb} "When enabled, child nodes will be executed in the same work unit."

   grid columnconfigure ${entryFrame} {0 1 2} -weight 1
   grid columnconfigure ${entryFrame} 1 -weight 2
   grid rowconfigure ${entryFrame} {0 1 2} -weight 1

   grid ${typeLabel} -row 0 -column 0 -sticky w -padx 2 -pady 2
   grid ${typeOption} -row 0 -column 1 -sticky w -padx 2 -pady 2
   grid ${positionLabel} -row 1 -column 0 -sticky w -padx 2 -pady 2
   grid ${positionSpinW} -row 1 -column 1 -sticky w -padx 2 -pady 2
   grid ${nameLabel} -row 2 -column 0 -sticky w -padx 2 -pady 2
   grid ${nameEntry} -row 2 -column 1 -sticky w -padx 2 -pady 2

   # create frame for ok/cancel buttons
   # add ok/cancel button
   set buttonFrame [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_button_frame]
   set okButton [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_ok_button]
   set cancelButton [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_cancel_button]

   frame ${buttonFrame} -relief raised
   button ${okButton} -text Ok
   button ${cancelButton} -text Cancel
   grid ${okButton} ${cancelButton} -padx 2

   grid ${entryFrame} -row 0 -padx 5 -pady {5 2} -sticky nsew
   grid ${buttonFrame} -row 1 -padx 5 -pady {5} -sticky e

   grid columnconfigure ${topWidget} 0 -weight 1
   grid rowconfigure ${topWidget} 0 -weight 1
   grid rowconfigure ${topWidget} 1 -weight 1

   wm title ${topWidget} "New Node ([ModuleFlow_record2NodeName ${_flowNodeRecord}])"

   # bind events to the widgets
   ${refEntry} bind <KeyPress-Return> [list ModuleFlowView_newNodeRefEntryCallback ${expPath} ${_moduleNode} ${refEntry}]
   bind ${cancelButton} <ButtonRelease> [list ModuleFlowView_newNodeCancel %W ${expPath} ${_moduleNode}]
   bind ${okButton} <ButtonRelease> [list ModuleFlowControl_addNodeOk ${topWidget} ${expPath} ${_moduleNode} ${_flowNodeRecord}]

   # callback when node type is changed
   trace add variable ${moduleId}_TypeOption write "ModuleFlowView_newNodeTypeCallback ${expPath} ${_moduleNode}"
}

proc ModuleFlowView_createNodeEditWidgets { _moduleNode _canvas _flowNodeRecord } {
   ::log::log debug "ModuleFlowView_createNodeEditWidgets _moduleNode:${_moduleNode} _flowNodeRecord:${_flowNodeRecord}"
   global  HighLightRestoreCmd
   set expPath [ModuleFlowView_getExpPath ${_canvas}]
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]

   if { [ModuleFlowView_multiEditNotify ${expPath} ${_moduleNode} [winfo toplevel ${_canvas}]] == false } {
      return
   }

   if { [ExpLayout_isModuleWritable ${expPath} ${_moduleNode}] == false } {
      set isCopied [ModuleFlowView_copyLocalNotify ${expPath} ${_moduleNode}]
      if { ${isCopied} == false } {
         ModuleFlowView_checkReadOnlyNotify ${expPath} ${_moduleNode}
      }
   }
   set moduleId [ExpLayout_getModuleChecksum ${expPath} ${_moduleNode}]

   # hightlight parent flow node
   set HighLightRestoreCmd ""
   DrawUtil_highLightNode ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd

   set modeNodeName ${_moduleNode}

   # create add new node toplevel
   set topWidget [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} addnode_top_widget]
   if { [winfo exists ${topWidget}] } {
      destroy ${topWidget}
   }

   toplevel ${topWidget}

   MiscTkUtils_positionWindow ${_canvas} ${topWidget}
   # when window is destroyed, clears the highlighted node
   bind ${topWidget} <Destroy> [list DrawUtil_resetHighLightNode ${HighLightRestoreCmd}]

   # create frame to hold all needed fields
   set entryFrame [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} addnode_entry_frame]
   frame ${entryFrame} -relief sunken -bd 1

   set switchValuesFrame [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_switchvalues_frame]
   set switchModeValue [${_flowNodeRecord} cget -switch_mode]
   ModuleFlowViwe_addSwitchItemWidgets  ${switchValuesFrame} ${switchModeValue} ${expPath} ${_moduleNode} ${_flowNodeRecord}

   # create frame for ok/cancel buttons
   # add ok/cancel button
   set buttonFrame [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_button_frame]
   set okButton [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_ok_button]
   set cancelButton [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} addnode_cancel_button]

   frame ${buttonFrame} -relief raised
   button ${okButton} -text Ok
   button ${cancelButton} -text Cancel
   grid ${okButton} ${cancelButton} -padx 2

   grid ${switchValuesFrame} -row 0 -column 0 -sticky we -padx 2 -pady 2 -columnspan 2
   grid ${entryFrame} -row 0 -padx 5 -pady {5 2} -sticky nsew
   grid ${buttonFrame} -row 1 -padx 5 -pady {5} -sticky e

   grid columnconfigure ${topWidget} 0 -weight 1
   grid rowconfigure ${topWidget} 0 -weight 1
   grid rowconfigure ${topWidget} 1 -weight 1

   wm title ${topWidget} "Edit Node [file tail ${_flowNodeRecord}] ([ModuleFlow_record2NodeName ${_flowNodeRecord}])"

   # bind events to the widgets
   bind ${cancelButton} <ButtonRelease> [list ModuleFlowView_editNodeCancel %W ${expPath} ${_moduleNode}]
   bind ${okButton} <ButtonRelease> [list ModuleFlowControl_editNodeOk ${topWidget} ${expPath} ${_moduleNode} ${_flowNodeRecord}]

}

proc ModuleFlowView_addPositionChanged { _posSpinbox _nodeTypeOption } {
   set insertPosition [${_posSpinbox} get]

   if { ${insertPosition} == "serial" } {
      # remove module node option
      # modules cannot be added in between existing nodes
     ${_nodeTypeOption}.menu entryconfigure [${_nodeTypeOption}.menu index "ModuleNode"] -state disabled
     ::tooltip::tooltip ${_posSpinbox} "serial - The newly created node will submit all nodes currently submitted by highlighted node."
   } elseif { ${insertPosition} == "parent" } {
     ::tooltip::tooltip ${_posSpinbox} "parent - The newly created node will submit highlighted node."
   } else {
     ${_nodeTypeOption}.menu entryconfigure [${_nodeTypeOption}.menu index "ModuleNode"] -state normal
     ::tooltip::tooltip ${_posSpinbox} "New created node will be submitted at position ${insertPosition}."
   }
}

proc ModuleFlowView_newNodeCancel { _sourceWidget _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_TypeOption

   ::log::log debug "ModuleFlowView_newNodeCancel"
   set topWidget [winfo toplevel ${_sourceWidget}]
   unset ${moduleId}_TypeOption

   # destroy window
   after idle destroy ${topWidget}
}

proc ModuleFlowView_editNodeCancel { _sourceWidget _expPath _moduleNode } {
   set topWidget [winfo toplevel ${_sourceWidget}]
   # destroy window
   after idle destroy ${topWidget}
}

proc ModuleFlowView_newNodeTypeCallback { _expPath _moduleNode args } {
   ::log::log debug "ModuleFlowView_newNodeTypeCallback _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_TypeOption ${moduleId}_PreviousTypeOption ${moduleId}_SwitchModeOption

   set nodeType [set ${moduleId}_TypeOption]
   ::log::log debug "ModuleFlowView_newNodeTypeCallback _expPath:${_expPath} _moduleNode:${_moduleNode} nodeType:${nodeType}"

   set nodeType [set ${moduleId}_TypeOption]

   # hide or show reference module row depending on selected node type
   set refLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_label]
   set refEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_entry]
   set refButton [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_button]

   set nameLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_name_label]
   set nameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_name_entry]

   set useModLinkLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_link_label]
   set useModLinkCb [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_link_cb]

   ModuleFlowView_cleanPreviousWidgets ${_expPath} ${_moduleNode}
   switch ${nodeType} {
      ModuleNode {
         grid ${refLabel} -row 2 -column 0 -sticky w -padx 2 -pady 2
         grid ${refEntry} -row 2 -column 1 -sticky we -padx 2 -pady 2
         grid ${refButton} -row 2 -column 2 -sticky w -padx 2 -pady 2
         grid ${nameLabel} -row 3 -column 0 -sticky w -padx 2 -pady 2
         grid ${nameEntry} -row 3 -column 1 -sticky we -padx 2 -pady 2
         grid ${useModLinkLabel} -row 4 -column 0 -sticky w -padx 2 -pady 2
         grid ${useModLinkCb} -row 4 -column 1 -sticky w -pady 2
         set workUnitRow 5
      }
      SwitchNode {
         grid ${nameLabel} -row 2 -column 0 -sticky w -padx 2 -pady 2
         grid ${nameEntry} -row 2 -column 1 -sticky we -padx 2 -pady 2
         ${refEntry} configure -text ""
         set workUnitRow 3
         ModuleFlowView_addSwitchNodeExtraWidget ${_expPath} ${_moduleNode}
      }
      default {
         grid ${nameLabel} -row 2 -column 0 -sticky w -padx 2 -pady 2
         grid ${nameEntry} -row 2 -column 1 -sticky we -padx 2 -pady 2
         ${refEntry} configure -text ""
         set workUnitRow 3
      }
   }

   # creates checkbox to ask whether the container is a work_unit i.e. supertask
   set workUnitLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_wunit_label]
   set workUnitCb [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_wunit_cb]
   if { ${nodeType} == "TaskNode" ||  ${nodeType} == "NpassTaskNode" } {
      # no work unit for tasks
      grid remove ${workUnitLabel} ${workUnitCb}
   } else {
      # work unit only for containers
      grid ${workUnitLabel} -row ${workUnitRow} -column 0 -sticky w -padx 2 -pady 2
      grid ${workUnitCb} -row ${workUnitRow} -column 1 -sticky w -padx 2 -pady 2
   }
   set ${moduleId}_PreviousTypeOption ${nodeType}
}

proc ModuleFlowView_cleanPreviousWidgets { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_PreviousTypeOption
   if { ! [info exists ${moduleId}_PreviousTypeOption] } {
      return
   }

   set nodeType [set ${moduleId}_PreviousTypeOption]

   set refLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_label]
   set refEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_entry]
   set refButton [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_button]

   set useModLinkLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_link_label]
   set useModLinkCb [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_link_cb]

   grid remove ${refLabel} ${refEntry} ${refButton}
   grid remove ${useModLinkLabel} ${useModLinkCb}
   puts "nodeType: ${nodeType}"
   if { ${nodeType} == "SwitchNode" } {
      ModuleFlowView_removeSwitchNodeExtraWidget ${_expPath} ${_moduleNode}
   }
}

proc ModuleFlowView_removeSwitchNodeExtraWidget { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_SwitchModeOption
   set entryFrame [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} addnode_entry_frame]
   set switchModeLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchmode_label]
   set switchModeOption [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchmode_option] 
   set switchValuesFrame [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchvalues_frame]
   destroy ${switchModeLabel} ${switchModeOption} ${switchValuesFrame}
   # grid remove ${switchModeLabel} ${switchModeOption} ${switchValuesFrame}
}

proc ModuleFlowView_addSwitchNodeExtraWidget { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_SwitchModeOption

   set entryFrame [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} addnode_entry_frame]
   set switchModeLabel [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchmode_label]
   set switchModeOption [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchmode_option] 

   Label ${switchModeLabel} -text "Switch Mode:"
   catch { unset ${moduleId}_SwichModeOption }
   tk_optionMenu ${switchModeOption} ${moduleId}_SwitchModeOption DatestampHour DayOfWeek DayOfMonth

   set switchModeValue [set ${moduleId}_SwitchModeOption]
   puts "ModuleFlowView_addSwitchNodeExtraWidget switchModeValue:${switchModeValue}"
   
   set switchValuesFrame [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchvalues_frame]
   ModuleFlowViwe_addSwitchItemWidgets ${switchValuesFrame} ${switchModeValue} ${_expPath} ${_moduleNode}

   grid ${switchModeLabel} -row 4 -column 0 -sticky w -padx 2 -pady 2
   grid ${switchModeOption} -row 4 -column 1 -sticky we -padx 2 -pady 2
   grid ${switchValuesFrame} -row 5 -column 0 -sticky we -padx 2 -pady 2 -columnspan 2
   grid rowconfigure ${entryFrame} 5 -weight 1
}

proc ModuleFlowViwe_addSwitchItemWidgets { _switchValuesFrame _switchMode _expPath _moduleN {_flowNodeRecord ""} } {
   switch ${_switchMode} {
      DatestampHour {
         set labelText "Default Hours"
      }
      default {
         set labelText ""
      }
   }
   LabelFrame ${_switchValuesFrame} -side top -text ${labelText} -bd 1 -relief raised
   set frameWidget [${_switchValuesFrame} getframe]
   set valueListWidget [listbox ${frameWidget}.values_list]
   set buttonFrame [frame ${frameWidget}.button_Frame]
   set itemEntry [entry ${buttonFrame}.item_entry -width 8 -bg white]
   set addButton [button ${buttonFrame}.add_button -text Add]

   if { ${_flowNodeRecord} != "" } {
      set switchItems [${_flowNodeRecord} cget -switch_items]
      foreach switchItem ${switchItems} {
         ${valueListWidget} insert end ${switchItem}
      }
   }

   ${addButton} configure -command [list ModuleFlowView_addSwitchNodeAddItem ${valueListWidget} ${itemEntry} ${_switchMode} ${_expPath} ${_moduleN} ${_flowNodeRecord}]
   set remButton [button ${buttonFrame}.rem_button -text Remove]
   ${remButton} configure -command [list ModuleFlowView_removeSwitchNodeAddItem ${valueListWidget} ${itemEntry} ${_flowNodeRecord}]
   bind ${valueListWidget} <<ListboxSelect>> [list ModuleFlowView_selectSwitchNodeAddItem ${valueListWidget} ${itemEntry}]

   grid ${valueListWidget} -row 0 -column 0 -sticky w
   grid ${buttonFrame} -row 0 -column 1
   grid ${itemEntry} -padx 2 -pady 2 -sticky w
   grid ${addButton} -padx 2 -pady 2 -sticky w
   grid ${remButton}  -padx 2 -pady 2 -sticky w
   grid rowconfigure ${frameWidget} 0 -weight 1
}

proc ModuleFlowView_addSwitchNodeAddItem { _valueListW _itemEntryW _switchMode _expPath _moduleN {_flowNodeRecord ""} } {
   if { ${_flowNodeRecord} == "" } {
     set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleN}]
     global ${moduleId}_SwitchModeOption
     set switchModeValue [set ${moduleId}_SwitchModeOption]
   } else {
     set switchModeValue ${_switchMode}
   }
   # get item to add
   set newItemValue [${_itemEntryW} get]
   set ItemValueList [split ${newItemValue} ","]
   if { ${newItemValue} != "" } {
      if { ${newItemValue} != "default" } {
	# validate hour field is 2 digits between 00 and 23
	foreach itemValue ${ItemValueList} {
          if { $switchModeValue == "DatestampHour" } {
	    if { ! ([string length ${itemValue}] == 2 && ${itemValue} >= "00" && ${itemValue} <= "23") } {
	      MessageDlg .msg_window -icon error -message "Invalid value: ${newItemValue}. Must be two digits character between 00 and 23 for DatestampHour switch." -aspect 400 \
	      -title "Add Node Error" -type ok -justify center -parent [winfo toplevel ${_valueListW}]
	      return
            }
          } elseif { $switchModeValue == "DayOfWeek" } {
            if { ! ([string length ${itemValue}] == 1 && ${itemValue} >= "0" && ${itemValue} <= "6") } {
	      MessageDlg .msg_window -icon error -message "Invalid value: ${newItemValue}. Must be one digit character between 0 and 6 for DayOfWeek switch." -aspect 400 \
	      -title "Add Node Error" -type ok -justify center -parent [winfo toplevel ${_valueListW}]
	      return
            }
          }
	}
      }
      # get all existings items
      set currentItems [${_valueListW} get 0 end]
      if { [lsearch ${currentItems} ${newItemValue}] == -1 } {
         if { ${newItemValue} != "" } {
            lappend currentItems ${newItemValue}
            set currentItems [lsort ${currentItems}]
            set newIndex [lsearch ${currentItems} ${newItemValue}]
            ${_valueListW} insert ${newIndex} ${newItemValue}
         }
      }
   }
}

proc ModuleFlowView_selectSwitchNodeAddItem { _valueListW _itemEntryW } {
   set currentSelection [${_valueListW} curselection]
   if { ${currentSelection} != "" } {
      # puts "ModuleFlowView_selectSwitchNodeAddItem currentSelection:${currentSelection}"
      ${_itemEntryW} delete 0 end
      ${_itemEntryW} insert 0 [${_valueListW} get ${currentSelection}]
   }
}

proc ModuleFlowView_removeSwitchNodeAddItem { _valueListW _itemEntryW {_flowNodeRecord ""} } {
   # get item to remove
   set remItemValue [${_itemEntryW} get]

   if { ${_flowNodeRecord} != "" } {
      set currentSavedItems [${_flowNodeRecord} cget -switch_items]
      if { [lsearch ${currentSavedItems} ${remItemValue}] != -1 } {
         MessageDlg .msg_window -icon error -message "Cannot remove currently used items." -aspect 400 \
            -title "Edit Node Error" -type ok -justify center -parent [winfo toplevel ${_valueListW}]
         return
      }
   }

   # get all existings items from list widget
   set currentItems [${_valueListW} get 0 end]

   set remIndex [lsearch ${currentItems} ${remItemValue}]
   if {  ${remIndex} != -1 } {
      ${_valueListW} delete ${remIndex}
   }
}

proc ModuleFlowView_getSwitchNodeItems {  _expPath _moduleNode } {
   puts "ModuleFlowView_getSwitchNodeItems _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   set values {}
   set switchValuesFrame [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchvalues_frame]
   set frameWidget [${switchValuesFrame} getframe]
   set valueListWidget ${frameWidget}.values_list
   set values [${valueListWidget} get 0 end]
   return ${values}
}

proc ModuleFlowView_getCurrentSwitchItem {  _expPath _flowNodeRecord _canvas} {
   puts "ModuleFlowView_getCurrentSwitchItem _expPath:${_expPath} _flowNodeRecord:${_flowNodeRecord}"
   set value ""
   set switchModeValue [${_flowNodeRecord} cget -switch_mode]
   # set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   if { ${switchModeValue} == "DatestampHour" } {
      set comboBoxWidget [DrawUtils_getIndexWidgetName ${_flowNodeRecord} ${_canvas}]
      # check if the current value of the combobox matches a valid entry in the list
      if { [${comboBoxWidget} getvalue] != -1 } {
         set value [${comboBoxWidget} get]
      }
   }
   return ${value}
}

proc ModuleFlowView_newNodeRefEntryCallback { _expPath _moduleNode _refEntry } {

   # get module path in the ref entry field
   set selectedModule [${_refEntry} cget -text]
   ModuleFlowView_newNodeModSelected ${_expPath} ${_moduleNode} ${selectedModule} ${_refEntry}
}

# called when the user has typed a module path in the "Module path" entry field or
# from the module selection dialog
# 
# _moduleNode is the node of the module we are editing
# _newModPath is the path to the new module node we are adding to the current module
proc ModuleFlowView_newNodeModSelected { _expPath _moduleNode _newModPath _sourceWidget } {
      # validate if it is a valid module... must contain a flow.xml file
      if { ! [file exists ${_newModPath}/flow.xml] } {
         MessageDlg .msg_window -icon error -message "Invalid module path: ${_newModPath}. Module flow.xml not found." \
            -aspect 400 -title "Module selection error" -type ok -justify center -parent ${_sourceWidget}
         return
      }

      # add the selected module name in the name entry
      set nameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_name_entry]
      ::log::log debug "ModuleFlowView_newNodeModSelected ${nameEntry} configure -text [file tail ${_newModPath}]"
      ${nameEntry} configure -text [file tail ${_newModPath}]
}

proc ModuleFlowView_newNodeRefButtonCallback { _expPath _moduleNode _refButton } {
   set selectedModule [tk_chooseDirectory -initialdir [ModuleFlowControl_getModDefaultDepot] \
      -parent ${_refButton} -title "Module selection dialog"]
   if { ${selectedModule} != "" } {
      ::log::log debug "ModuleFlowView_newNodeRefButtonCallback selectedModule:${selectedModule}"

      # add the selected module path in the ref entry field
      set refEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_entry]
      ${refEntry} configure -text ${selectedModule}

      ModuleFlowView_newNodeModSelected ${_expPath} ${_moduleNode} ${selectedModule} ${_refButton}
   }
}


proc ModuleFlowView_renameNodeWidgets { _moduleNode _canvas _flowNodeRecord {_allModules false} } {
   ::log::log debug "ModuleFlowView_renameNodeWidgets"
   global  HighLightRestoreCmd
   set expPath [ModuleFlowView_getExpPath ${_canvas}]
   set nodeType [${_flowNodeRecord} cget -type]
   if { [ExpLayout_isModuleWritable ${expPath} ${_moduleNode}] == false } {
      # current module must be writable
      set isCopied [ModuleFlowView_copyLocalNotify ${expPath} ${_moduleNode} ${_canvas}]
      if { ${isCopied} == false } {
         ModuleFlowView_checkReadOnlyNotify ${expPath} ${_moduleNode}
      }
   }

   if { ${nodeType} == "ModuleNode" } {
      set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
      # if { ${_allModules} == true } {
      #  set instanceNumber [ExpModTree_getModInstances ${expPath} ${flowNode}]
      #   MessageDlg .msg_window -icon warning -message "All instances (${instanceNumber}) of module [file tail ${flowNode}] will be renamed!" \
      #         -aspect 400 -title "Module Flow Notification" -type ok -justify center -parent [winfo toplevel ${_canvas}]
      #}

      # module node to be renamed must be local
      if { [ExpLayout_isModuleWritable ${expPath} ${flowNode}] == false } {
         set isCopied [ModuleFlowView_copyLocalNotify ${expPath} ${flowNode} ${_canvas}]
         if { ${isCopied} == false } {
            return
         }
      }
   }

   set moduleId [ExpLayout_getModuleChecksum ${expPath} ${_moduleNode}]
   # hightlight parent flow node
   set HighLightRestoreCmd ""
   DrawUtil_highLightNode ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd

   set modeNodeName ${_moduleNode}

   # create toplevel
   set topWidget [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} rename_top_widget]
   if { [winfo exists ${topWidget}] } {
      destroy ${topWidget}
   }

   toplevel ${topWidget}

   MiscTkUtils_positionWindow ${_canvas} ${topWidget}
   # when window is destroyed, clears the highlighted node
   bind ${topWidget} <Destroy> [list DrawUtil_resetHighLightNode ${HighLightRestoreCmd}]

   # create frame to hold all needed fields
   set entryFrame [ModuleFlowView_getWidgetName  ${expPath} ${_moduleNode} rename_entry_frame]
   frame ${entryFrame} -relief sunken -bd 1

   set nameLabel [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_name_label]
   set nameEntry [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_name_entry]
   Label ${nameLabel} -text "Name:"
   Entry ${nameEntry} -text [${_flowNodeRecord} cget -name] -state disabled

   ::tooltip::tooltip ${nameEntry} "Current ${nodeType} name: [${_flowNodeRecord} cget -name]"

   set newNameLabel [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_new_name_label]
   set newNameEntry [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_new_name_entry]
   Label ${newNameLabel} -text "New name:"
   Entry ${newNameEntry} -validate all \
      -vcmd {
         # allow wordchar and dot characters only
         # replace dot by _ so we can test
         regsub -all . %P _ tmpentry
         if { [string is wordchar ${tmpentry}] } {
            return 1
         }
         return 0
      }

   ::tooltip::tooltip ${newNameEntry} "Enter new name here."

   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   # creates module reference label & entry field
   if { ${nodeType} == "ModuleNode" && [ExpLayout_isModuleLink ${expPath} ${flowNode}] == true } {
      # creates module reference label & field
      set refLabel [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_ref_label]
      set refEntry [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_ref_entry]
      Label ${refLabel} -text "Module Path:"
      set linkTarget [ExpLayout_getModLinkTarget ${expPath} ${flowNode}]
      Entry ${refEntry} -text ${linkTarget} -state disabled

      ::tooltip::tooltip  ${refEntry} "Linked Reference Module:\n${linkTarget}"

      ${nameLabel} configure -text "Link Name:"
      ${newNameLabel} configure -text "New Link Name:"

      grid ${refLabel} -row 0 -column 0 -sticky w -padx 2 -pady 2 -sticky w
      grid ${refEntry} -row 0 -column 1 -sticky w -padx 2 -pady 2 -sticky ew
      grid ${nameLabel} -row 1 -column 0 -sticky w -padx 2 -pady 2 -sticky w
      grid ${nameEntry} -row 1 -column 1 -sticky w -padx 2 -pady 2 -sticky ew
      grid ${newNameLabel} -row 2 -column 0 -sticky w -padx 2 -pady 2 -sticky w
      grid ${newNameEntry} -row 2 -column 1 -sticky w -padx 2 -pady 2 -sticky ew

      grid columnconfigure ${entryFrame} 1 -weight 1
      grid rowconfigure ${entryFrame} {0 1 2} -weight 1
   } else {

      grid ${nameLabel} -row 0 -column 0 -sticky w -padx 2 -pady 2 -sticky w
      grid ${nameEntry} -row 0 -column 1 -sticky w -padx 2 -pady 2 -sticky ew
      grid ${newNameLabel} -row 1 -column 0 -sticky w -padx 2 -pady 2 -sticky w
      grid ${newNameEntry} -row 1 -column 1 -sticky w -padx 2 -pady 2 -sticky ew

      #grid columnconfigure ${entryFrame} {0 1} -weight 1
      grid columnconfigure ${entryFrame} 1 -weight 1
      grid rowconfigure ${entryFrame} {0 1} -weight 1
   }

   # create frame for ok/cancel buttons
   # add ok/cancel button
   set buttonFrame [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_button_frame]
   set okButton [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_ok_button]
   set cancelButton [ModuleFlowView_getWidgetName ${expPath} ${_moduleNode} rename_cancel_button]

   frame ${buttonFrame} -relief raised
   button ${okButton} -text Ok
   button ${cancelButton} -text Cancel
   grid ${okButton} ${cancelButton} -padx 2

   #grid ${entryFrame} -row 0 -padx 5 -pady {5 2} -sticky nsew
   grid ${entryFrame} -row 0 -padx 5 -pady {5 2} -sticky ew
   grid ${buttonFrame} -row 1 -padx 5 -pady {5} -sticky e

   grid columnconfigure ${topWidget} 0 -weight 1
   grid rowconfigure ${topWidget} 0 -weight 1
   #grid rowconfigure ${topWidget} 1 -weight 1

   wm title ${topWidget} "Rename ${nodeType} [${_flowNodeRecord} cget -name]"
   wm minsize ${topWidget} 300 100

   # bind events to the widgets
   bind ${cancelButton} <ButtonRelease> [list after idle destroy ${topWidget}]
   bind ${okButton} <ButtonRelease> [list ModuleFlowControl_renameNodeOk ${topWidget} ${expPath} ${_moduleNode} ${_flowNodeRecord}]

   focus ${newNameEntry}
}

# returns the y coordinates that the module shall be displayed based on
# it's parent coordinates, the module position within its parent and
# coordinates of it's previous siblings
proc ModuleFlowView_getNodeY { _flowNodeRecord _context _position } {
   ::log::log debug "ModuleFlowView_getNodeY _flowNodeRecord:${_flowNodeRecord} context:${_context} _position:${_position}"
   set parentNode [ModuleFlow_getSubmitter ${_flowNodeRecord}]

   set parentCoords [ModuleFlowView_getNodeCoord ${parentNode} ${_context}]
   if { ${_position} == 0 } {
      # if position 0, the next y is the same as the parent y1
      set nextY [lindex ${parentCoords} 1]
   } else {
      # the next y is the same as the previous sibling y2
      set parentSubmits [ModuleFlow_getSubmitRecords ${parentNode}]
      set previousSibling [lindex ${parentSubmits} [expr ${_position} - 1]]
      set nextY [ModuleFlowView_getBranchMaxY ${previousSibling} ${_context}]
   }

   ::log::log debug "ModuleFlowView_getNodeY _flowNodeRecord:${_flowNodeRecord} returning ${nextY}"
   return ${nextY}
}

# goes down a submit tree and find the max y
proc ModuleFlowView_getBranchMaxY { _flowNodeRecord _context } {
   ::log::log debug "ModuleFlowView_getBranchMaxY _flowNodeRecord:${_flowNodeRecord}"
   set nodeCoords [ModuleFlowView_getNodeCoord ${_flowNodeRecord} ${_context}]
   set maxY 0
   if { ${nodeCoords} != "" } {
      set maxY [lindex ${nodeCoords} 3]
      set childSubmits [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]
      foreach child ${childSubmits} {
         set childY [ModuleFlowView_getBranchMaxY ${child} ${_context}]
         if { [expr ${childY} > ${maxY}] } {
            set maxY ${childY}
         }
      }
   }
   ::log::log debug "ModuleFlowView_getBranchMaxY _flowNodeRecord:${_flowNodeRecord} maxY:${maxY}"
   return ${maxY}
}

# sets the display coordinates in the visual node.
# creates the module visual node if not exists.
proc ModuleFlowView_setNodeCoord { _flowNodeRecord _context _x1 _y1 _x2 _y2} {
   ::log::log debug "ModuleFlowView_setNodeCoord _flowNodeRecord:$_flowNodeRecord"
   set visualNodeName [ModuleFlowView_getVisualNodeName ${_flowNodeRecord} ${_context}]

   if { ! [record exists instance ${visualNodeName}] } {
      ::log::log debug "ModuleFlowView_setNodeCoord creating visualNodeName:$visualNodeName"
      FlowVisualNode ${visualNodeName}
   }

   ${visualNodeName} configure -context ${_context} -x1 ${_x1} -y1 ${_y1} -x2 ${_x2} -y2 ${_y2}
}

# returns the display coords of the module tree node as
# a list {x1 y1 x2 y2}
# retusn "" if not exists
proc ModuleFlowView_getNodeCoord { _flowNodeRecord _context } {
   ::log::log debug "ModuleFlowView_getNodeCoord _flowNodeRecord:$_flowNodeRecord _context:${_context}"
   set visualNodeName [ModuleFlowView_getVisualNodeName ${_flowNodeRecord} ${_context}]

   ::log::log debug "ModuleFlowView_getNodeCoord visualNodeName:$visualNodeName"
   if { ! [record exists instance ${visualNodeName}] } {
      return ""
   }
   ::log::log debug "ModuleFlowView_getNodeCoord visualNodeName exist!"

   set x1 [${visualNodeName} cget -x1]
   set y1 [${visualNodeName} cget -y1]
   set x2 [${visualNodeName} cget -x2]
   set y2 [${visualNodeName} cget -y2]

   return [list ${x1} ${y1} ${x2} ${y2}]
}

#
# the context is used to build the visual record of the node
# it is mainly used to avoid clashing between module nodes because they
# appear visually in their own flow and in the flow of the calling module as well
#
# The context is the value of the module node name withing the experiment tree
# for instance when we display the module /enkf_mod/anal_mod, all the
# nodes within the anal_mod module will be prefixed with /enkf_mod/anal_mod 
proc ModuleFlowView_getVisualNodeName { _flowNodeRecord _context } {
   set nodeName [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set parentMod [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set parentNodeName ""
   if { ${parentMod} != "" } {
      set parentNodeName [ModuleFlow_record2NodeName ${parentMod}]
   }
   set visualNodeName ModFlowView_${_context}_${nodeName}
   return ${visualNodeName}
}

proc ModuleFlowView_clearVisualNodes { _context } {
   set visualRecords [info commands ModFlowView_${_context}_*]
   foreach visuaRecord ${visualRecords} {
      if { [record exists instance ${visuaRecord}]} {
         record delete instance ${visuaRecord}
      }
   }
}

proc ModuleFlowView_toFront { _expPath _moduleNode } {
   set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
   if { [winfo exists ${topWidget}] == 1 } {
      raise ${topWidget}
   }
}

proc ModuleFlowView_goEditor { _file } {
   set textViewer gvim
   if { [info exists Preferences::text_viewer] } {
      set textViewer "$Preferences::text_viewer $Preferences::text_viewer_args"
      ::log::log debug "ModuleFlowView_goEditor textViewer=${textViewer}..."
      if { ${textViewer} == "default" } {
         set textViewer gvim
         ::log::log debug "ModuleFlowView_goEditor set textViewer gvim"
      }
   }

   ::log::log debug "ModuleFlowView_goEditor eval exec ${textViewer} ${_file}"
   eval exec ${textViewer} ${_file} &
}

proc ModuleFlowView_getWidgetName { _expPath _moduleNode _key } {
   ::log::log debug "ModuleFlowView_getWidgetName _expPath:${_expPath} _moduleNode:${_moduleNode} _key:${_key}"
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global array ${moduleId}_ModuleFlowWidgetNames
   set value ""
   ::log::log debug "ModuleFlowView_getWidgetName looking for '${moduleId}_ModuleFlowWidgetNames($_key)'"
   if { [info exists ${moduleId}_ModuleFlowWidgetNames($_key)] } {
      set value [set ${moduleId}_ModuleFlowWidgetNames($_key)]
   } else {
      ::log::log error "ModuleFlowView_getWidgetName invalid widget key name:${_key}"
      error "ModuleFlowView_getWidgetName invalid widget key name:${_key}"
   }
   return ${value}
}

proc ModuleFlowView_setWidgetNames { _expPath _moduleNode } {
   ::log::log debug "ModuleFlowView_setWidgetNames _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   #global array ${moduleId}_ModuleFlowWidgetNames
   global ${moduleId}_ModuleFlowWidgetNames
   if { ! [info exists ${moduleId}_ModuleFlowWidgetNames] } {
      set topWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
      set addNodeTopWidget .add_node_top_${moduleId}
      set renameNodeTopWidget .rename_top_${moduleId}
      ::log::log debug "ModuleFlowView_setWidgetNames creating array ${moduleId}_ModuleFlowWidgetNames"
      array set ${moduleId}_ModuleFlowWidgetNames \
         [list \
         topwidget ${topWidget} \
         topframe ${topWidget}.topframe \
         toolbar ${topWidget}.toolbar \
         save_button ${topWidget}.toolbar.save_button \
         addnode_top_widget ${addNodeTopWidget} \
         addnode_entry_frame ${addNodeTopWidget}.entry_frame \
         addnode_pos_label ${addNodeTopWidget}.entry_frame.position_label \
         addnode_pos_spinbox ${addNodeTopWidget}.entry_frame.position_spin \
         addnode_type_label ${addNodeTopWidget}.entry_frame.type_label \
         addnode_type_option ${addNodeTopWidget}.entry_frame.type_option \
         addnode_name_label ${addNodeTopWidget}.entry_frame.name_label \
         addnode_name_entry ${addNodeTopWidget}.entry_frame.name_entry \
         addnode_ref_label ${addNodeTopWidget}.entry_frame.reference_label \
         addnode_ref_entry ${addNodeTopWidget}.entry_frame.reference_combo \
         addnode_ref_button ${addNodeTopWidget}.entry_frame.reference_button \
         addnode_link_label ${addNodeTopWidget}.entry_frame.link_label \
         addnode_link_cb ${addNodeTopWidget}.entry_frame.link_check \
         addnode_wunit_label ${addNodeTopWidget}.entry_frame.wunit_label \
         addnode_wunit_cb ${addNodeTopWidget}.entry_frame.wunit_check \
         addnode_switchmode_label ${addNodeTopWidget}.entry_frame.switchmode_label \
         addnode_switchmode_option ${addNodeTopWidget}.entry_frame.switchmode_option \
         addnode_switchvalues_frame ${addNodeTopWidget}.entry_frame.switchvalues_frame \
         addnode_button_frame ${addNodeTopWidget}.button_frame \
         addnode_ok_button ${addNodeTopWidget}.button_frame.ok_button \
         addnode_cancel_button ${addNodeTopWidget}.button_frame.cancel_button \
         rename_top_widget ${renameNodeTopWidget} \
         rename_entry_frame ${renameNodeTopWidget}.entry_frame \
         rename_ref_label ${renameNodeTopWidget}.entry_frame.reference_label \
         rename_ref_entry ${renameNodeTopWidget}.entry_frame.reference_entry \
         rename_name_label ${renameNodeTopWidget}.entry_frame.name_label \
         rename_name_entry ${renameNodeTopWidget}.entry_frame.name_entry \
         rename_new_name_label ${renameNodeTopWidget}.entry_frame.new_name_label \
         rename_new_name_entry ${renameNodeTopWidget}.entry_frame.new_name_entry \
         rename_button_frame ${renameNodeTopWidget}.button_frame \
         rename_ok_button ${renameNodeTopWidget}.button_frame.ok_button \
         rename_cancel_button ${renameNodeTopWidget}.button_frame.cancel_button \
         ]
   }
}


proc ModuleFlowView_clearWidgetNames { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global array ${moduleId}_ModuleFlowWidgetNames
   array unset ${moduleId}_ModuleFlowWidgetNames
}
