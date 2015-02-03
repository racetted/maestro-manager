package require tablelist
package require autoscroll


proc ResourceView_createWidgets { _expPath _moduleNode _flowNodeRecord } {
   ::log::log debug "ResourceView_createWidgets _expPath:${_expPath} _moduleNode:${_moduleNode} _flowNodeRecord:${_flowNodeRecord}"
   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]
   if { [winfo exists ${topWidget}] } {
      destroy ${topWidget}
   }

   toplevel ${topWidget}
   ModuleFlowView_registerToplevel ${_expPath} ${_moduleNode} ${topWidget} [list ResourceControl_closeSelected ${_expPath} ${_moduleNode} ${_flowNodeRecord}]

   set flowNode [${_flowNodeRecord} cget -flow_path]
   wm title ${topWidget} "Resource Settings [file tail ${_flowNodeRecord}] ([ModuleFlow_record2NodeName ${_flowNodeRecord}])"
   set flowCanvas [ModuleFlowView_getCanvas ${_expPath} ${_moduleNode}]
   MiscTkUtils_positionWindow ${flowCanvas} ${topWidget}

   set noteBook [NoteBook ${topWidget}.note_book -height 300 -width 500 -tabbevelsize 2]

   ${noteBook} insert 0 batch -text Batch
   ${noteBook} insert 1 dep -text Dependencies
   ${noteBook} insert 2 action -text "Abort Action"

   ${noteBook} raise batch

   set batchFrame [${noteBook} getframe batch]
   ResourceView_createBatchWidget ${batchFrame} ${_expPath} ${_moduleNode} ${flowNode}

   set dependsFrame [ResourceView_getDependsFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   ResourceView_createDependsWidget ${dependsFrame} ${_expPath} ${_moduleNode} ${flowNode}
   
   set abortActionFrame [ResourceView_getAbortActionFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   ResourceView_createAbortActionWidget ${abortActionFrame} ${_expPath} ${_moduleNode} ${flowNode}

   if { [${_flowNodeRecord} cget -type] == "LoopNode" } {
      ${noteBook} insert 3 loop -text Loop
      set loopFrame [ResourceView_getLoopFrameWidget  ${_expPath} ${_moduleNode} ${flowNode}]
      ResourceView_createLoopWidget ${loopFrame} ${_expPath} ${_moduleNode} ${flowNode}
   }

   set buttonFrame [frame ${topWidget}.button_Frame]
   set cancelButton [button ${buttonFrame}.cancel_button -text Cancel \
      -command [list ResourceControl_closeSelected ${_expPath} ${_moduleNode} ${_flowNodeRecord}]]
   set refreshButton [button ${buttonFrame}.refresh_button -text Refresh \
      -command [list ResourceControl_refreshSelected ${_expPath} ${_moduleNode} ${_flowNodeRecord}]]
   set saveButton [button ${buttonFrame}.save_button -text Save \
      -command [ list ResourceControl_saveSelected ${_expPath} ${_moduleNode} ${_flowNodeRecord}]]

   grid ${saveButton} ${refreshButton} ${cancelButton} -padx { 2 2 } -pady 2 -sticky e

   grid ${noteBook} -row 0 -column 0 -pady 5 -padx 5 -ipadx 5 -ipady 5 -sticky nsew
   grid ${buttonFrame} -row 1 -column 0 -padx 5 -pady {10 2} -sticky e


   # allow widgets in first column to take all available horiz space
   grid columnconfigure ${topWidget} 0 -weight 1
   # allow widgets in first row to take all available vert space space
   grid rowconfigure ${topWidget} 0 -weight 1
}

proc ResourceView_updateSaveButtonState { _topWidget _newState } {
   set saveButton ${_topWidget}.button_Frame.save_button
   if { [winfo exists ${saveButton}] } {
      ${saveButton} configure -state ${_newState}
   }
}

proc ResourceView_createBatchWidget { _batchFrame _expPath _moduleNode _flowNode } {

   ResourceView_addEntryMACHINE ${_batchFrame} 1
   ResourceView_addEntryQUEUE ${_batchFrame} 2
   ResourceView_addEntryCPU ${_batchFrame} 3
   ResourceView_addEntryCPU_MULTIPLIER ${_batchFrame} 4
   ResourceView_addEntryMEMORY ${_batchFrame} 5
   ResourceView_addEntryWALLCLOCK ${_batchFrame} 6
   ResourceView_addEntryCATCHUP ${_batchFrame} 7
   ResourceView_addEntryMPI ${_batchFrame} 8
   ResourceView_addEntrySOUMET_ARGS ${_batchFrame} 9

   grid columnconfigure ${_batchFrame} 1 -weight 1
}

proc ResourceView_addNewDepEntry { _tableListWidget _position } {
   global ResourceTableColumnMap
   set tableVariable [ResourceView_getDepTableVar ${_tableListWidget}]
   global ${tableVariable}
   set ${tableVariable} [linsert [set ${tableVariable}] ${_position} [list "" "end" "" "" "" ""]]
   ${_tableListWidget} cellconfigure ${_position},$ResourceTableColumnMap(ExpColumnNumber) -window [list ResourceView_updateExpEntryWidget] \
      -windowdestroy  [list ResourceView_destroyExpEntryWidget]
   ResourceView_setDataChanged ${_tableListWidget} true
}

proc ResourceView_updateDepTableWidgets { _expPath _moduleNode _flowNode } {
   ::log::log debug "ResourceView_updateDepTableWidgets $_expPath $_moduleNode $_flowNode"
   global ResourceTableColumnMap
   set dependsFrame [ResourceView_getDependsFrameWidget ${_expPath} ${_moduleNode} ${_flowNode}]

   set tableListWidget ${dependsFrame}.table
   set tableVariable [ResourceView_getDepTableVar ${tableListWidget}]
   global ${tableVariable}
 
   if { [info exists ${tableVariable}] } {
      ::log::log debug "tableVariable: ${tableVariable}"
      set size [llength [set ${tableVariable}]]
      set rowCount 0
      while { ${rowCount} < ${size} } {
         ${tableListWidget} cellconfigure ${rowCount},$ResourceTableColumnMap(ExpColumnNumber) -window [list ResourceView_updateExpEntryWidget]
	 incr rowCount
      }
   }

   set nodeTableListWidget ${dependsFrame}.node_table
   set nodeTableVariable [ResourceView_getDepTableVar ${nodeTableListWidget}]
   global ${nodeTableVariable}
   if { [info exists ${nodeTableVariable}] } {
      ::log::log debug "nodeTableVariable: ${nodeTableVariable}"
      set size [llength [set ${nodeTableVariable}]]
      set rowCount 0
      while { ${rowCount} < ${size} } {
         ${nodeTableListWidget} cellconfigure ${rowCount},$ResourceTableColumnMap(ExpColumnNumber) -window [list ResourceView_updateExpEntryWidget]
	 incr rowCount
      }
   }
}

proc ResourceView_updateExpEntryWidget { _tableListWidget _cellRow  _cellColumn _cellWidget } {
   ::log::log debug "ResourceView_updateExpEntryWidget  $_tableListWidget $_cellRow  $_cellColumn $_cellWidget"
   set buttonImg [image create photo ${_tableListWidget}.open_img -file /users/dor/afsi/sul/Downloads/folder_16.png]
   Button ${_cellWidget} -image ${buttonImg} -command [list ResourceView_depExpChooseDir $_tableListWidget $_cellRow  $_cellColumn $_cellWidget]
}

proc ResourceView_depExpChooseDir { _tableListWidget _cellRow  _cellColumn _cellWidget } {
   set tableVariable [ResourceView_getDepTableVar ${_tableListWidget}]
   global ${tableVariable}

   ${_tableListWidget} cancelediting

   set expDir [tk_chooseDirectory -initialdir / -mustexist true -parent ${_tableListWidget} -title "Select Experiment"]
   ::log::log debug "ResourceView_depExpChooseDir expDir:${expDir} win:[${_tableListWidget} editwinpath]"

   if { ${expDir} != "" } {
      # get the row entry data
      set rowEntry [lindex [set ${tableVariable}] ${_cellRow}]

      # replace the exp in the row entry
      set rowEntry [lreplace ${rowEntry} ${_cellColumn} ${_cellColumn} ${expDir}]

      # put the row entry back in the global list
      set ${tableVariable} [lreplace [set ${tableVariable}] ${_cellRow} ${_cellRow} ${rowEntry}]
   }
}

proc ResourceView_destroyExpEntryWidget { _tableListWidget _cellRow  _cellColumn _cellWidget } {
   ::log::log debug "ResourceView_destroyExpEntryWidget  $_tableListWidget $_cellRow  $_cellColumn $_cellWidget"
}

proc ResourceView_removeDepEntry { _tableListWidget _positions } {
   set tableVariable [ResourceView_getDepTableVar ${_tableListWidget}]
   global ${tableVariable}
   set reversePositions [lsort -decreasing ${_positions}]
   foreach deletePosition ${reversePositions} {
      set ${tableVariable} [lreplace [set ${tableVariable}] ${deletePosition} ${deletePosition}]
   }
   ResourceView_setDataChanged ${_tableListWidget} true
}

proc ResourceView_editNodeDepRowStartCallback { _expPath _moduleNode _tableListWidget _cellRow  _cellColumn _cellContent } {
   set tableVariable [ResourceView_getDepTableVar ${_tableListWidget}]
   global ${tableVariable}
   set currentValueRow [lindex [set ${tableVariable}] ${_cellRow}]
   set currentValue [lindex ${currentValueRow} ${_cellColumn}]
   if { [ResourceView_editDepFlowNotify  ${_expPath} ${_moduleNode} ${_tableListWidget}] == true } {
      set returnValue [ResourceView_editDepRowStartCallback ${_expPath} ${_moduleNode} ${_tableListWidget} ${_cellRow} ${_cellColumn} ${_cellContent}]
   } else {
      set returnValue ${currentValue}
      ${_tableListWidget} cancelediting
   }
   return ${returnValue}
}

# callback when done starting editing cell
proc ResourceView_editDepRowStartCallback { _expPath _flowNode _tableListWidget _cellRow  _cellColumn _cellContent } {
   global ResourceTableColumnMap
   ::log::log debug "ResourceView_editDepRowStartCallback _tableListWidget:${_tableListWidget} _cellRow:${_cellRow}  _cellColumn:${_cellColumn} _cellContent:${_cellContent}"
   if { ${_cellColumn} == $ResourceTableColumnMap(StatusColumnNumber) } {
      set comboBoxWidget [${_tableListWidget} editwinpath]
      ${comboBoxWidget} configure -values {begin end}
   } elseif { ${_cellColumn} == $ResourceTableColumnMap(NodeColumnNumber) } {
      set comboBoxWidget [${_tableListWidget} editwinpath]
      ${comboBoxWidget} configure -values [lsort [ModuleFlow_getAllInstances ${_expPath}]]
   }

   return ${_cellContent}
}

proc ResourceView_editDepRowEndCallback {  _expPath _flowNode _tableListWidget _cellRow  _cellColumn _cellContent } {
   set tableVariable [ResourceView_getDepTableVar ${_tableListWidget}]
   global ${tableVariable}

   global ResourceTableColumnMap ResourceTableColumnValidateMap
   ::log::log debug "ResourceView_editDepRowEndCallback _tableListWidget:${_tableListWidget} _cellRow:${_cellRow}  _cellColumn:${_cellColumn} _cellContent:${_cellContent}"
   set currentValueRow [lindex [set ${tableVariable}] ${_cellRow}]
   set currentValue [lindex ${currentValueRow} ${_cellColumn}]
   ::log::log debug "ResourceView_editDepRowEndCallback currentValue:${currentValue}"

   set value ${_cellContent}
   set errorFlag 0

   if { ! [array exists ResourceTableColumnValidateMap] } {
      array set ResourceTableColumnValidateMap \
         [list $ResourceTableColumnMap(NodeColumnNumber) ResourceView_validateDepNode \
               $ResourceTableColumnMap(StatusColumnNumber) ResourceView_validateDepStatus \
               $ResourceTableColumnMap(IndexColumnNumber) ResourceView_validateDepIndex \
               $ResourceTableColumnMap(LocalIndexColumnNumber) ResourceView_validateDepIndex \
               $ResourceTableColumnMap(HourColumnNumber) ResourceView_validateDepHour \
               $ResourceTableColumnMap(ExpColumnNumber) ResourceView_validateDepExp]
   }

   # execute the column validation proc if it exists
   # the validation proc must take the same arguments as the current proc
   set errorMsg ""
   if { [info exists ResourceTableColumnValidateMap(${_cellColumn})] } {
      set validateProc $ResourceTableColumnValidateMap(${_cellColumn})
      if { [info procs ${validateProc}] != "" } {
          ::log::log debug "ResourceView_editDepRowEndCallback calling ${validateProc} exp:${_expPath} node:${_flowNode} widget:${_tableListWidget} row:${_cellRow} col: ${_cellColumn} value:${value}"
         set errorFlag [${validateProc} ${_expPath} ${_flowNode} ${_tableListWidget} ${_cellRow}  ${_cellColumn} ${value} errorMsg]
      }
   }

   ::log::log debug "ResourceView_editDepRowEndCallback errorMsg: ${errorMsg} errorFlag:${errorFlag}"
   switch ${errorFlag} {
      1 {
         # error
         MessageDlg .msg_window -icon error -message "Error saving dependency entry.\n${errorMsg}" -aspect 300 \
            -title "Notification" -type ok -justify center -parent ${_tableListWidget}
         set value ${currentValue}
      } 
      2 {
         set answer [MessageDlg .msg_window -icon warning -message "Warning: ${errorMsg}" -aspect 300 \
            -title "Notification" -type okcancel -justify center -parent ${_tableListWidget}]
         if { ${answer} == 1 } {
	    # cancel the operation
            set value ${currentValue}
	 }
      }
      default {
      }
   } 

   # if the new value is different than old value, set the change flag for the resource to true
   if { ${value} != ${currentValue} } {
      ResourceView_setDataChanged ${_tableListWidget} true
   }

   return ${value}
}

# _outErrMsg is output variable used to store error msg to be sent back to caller
proc ResourceView_validateDepNode { _expPath _flowNode _tableListWidget _cellRow  _cellColumn _cellContent _outErrMsg } {
   global ResourceTableColumnMap
   ::log::log debug "ResourceView_validateDepNode $_tableListWidget $_cellRow  $_cellColumn $_cellContent "
   upvar ${_outErrMsg} myOutputErrMsg
   set myOutputErrMsg "Invalid Node!"

   set errorFlag 0
   if { ${_cellContent} != "" } {
      # get the node with relative path expansion if any
      set flowNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_flowNode}]
      set resultingNodeRecord [ModuleFlow_getFromRelativePath ${_expPath} ${flowNodeRecord} ${_cellContent} myOutputErrMsg]
      ::log::log debug "ResourceView_validateDepNode resultingNodeRecord:${resultingNodeRecord}"
      if { ${resultingNodeRecord} == -1 } {
         # got an error
	 set errorFlag 1
      }

      if { ${errorFlag} == 0 } {
         # check if the exp field is set
         set expFieldValue [${_tableListWidget} cellcget ${_cellRow},$ResourceTableColumnMap(ExpColumnNumber) -text]
	 if { ${expFieldValue} != "" } {
	    # remote node
	    if { [ModuleFlow_hasRelativeSyntax ${_cellContent}] == true } {
               # relative dependencies with remote exp does not make sense,
	       # so we forbid it
	       set errorFlag 1
               set myOutputErrMsg "Relative syntax not supported for remote experiment dependency."
	    } elseif { [ModuleFlow_checkNodeExists ${expFieldValue} ${_cellContent}] == false } {
               # validate that the node exists within the remote exp
	       # issue warning
	       set errorFlag 2
               set myOutputErrMsg "The dependant node ${_cellContent} does not exist in the remote experiment ${expFieldValue}! Do you want to continue?"
            }
	 } else {
	    # local node
	    if { ! [record exists instance ${resultingNodeRecord}] } {
	       set errorFlag 2
               set myOutputErrMsg "The dependant node ${_cellContent} does not exist in the current experiment! Do you want to continue?"
	    }
	 }
      }
   }

   return ${errorFlag}
}

proc ResourceView_validateDepStatus { _expPath _flowNode _tableListWidget _cellRow  _cellColumn _cellContent _outErrMsg } {
   ::log::log debug "ResourceView_validateDepStatus _newValue:$_cellContent"
   set errorFlag 0
   if { ${_cellContent} != "" && [string index ${_cellContent} 0] != "$" } {
      if { ${_cellContent} != "begin" && ${_cellContent} != "end" } {
	 set errorFlag true
         upvar ${_outErrMsg} myOutputErrMsg
         set myOutputErrMsg "Invalid status value: ${_cellContent}"
      }
   }
   return ${errorFlag}
}

proc ResourceView_validateDepIndex { _expPath _flowNode _tableListWidget _cellRow  _cellColumn _cellContent _outErrMsg } {

   ::log::log debug "ResourceView_validateDepIndex _newValue:$_cellContent"
   set errorFlag 0
   if { ${_cellContent} != "" && [string index ${_cellContent} 0] != "$" } {
      # acceptable format is loop_name_x0=loop_index,loop_name_x1=loop_index,loop_name_xn=loop_index
      set loopArgsList [split ${_cellContent} ","]
      foreach loopArg ${loopArgsList} {
         set splitArgs [split ${loopArg} "="]
	 if { [llength ${splitArgs}] != 2 || [lindex ${splitArgs} 0] == "" ||
	      [lindex ${splitArgs} 1] == "" } {
	    # invalid syntax
	    set errorFlag 1
            upvar ${_outErrMsg} myOutputErrMsg
            set myOutputErrMsg "Invalid index syntax: ${loopArg}"
	    break
         }
      }
   }

   return ${errorFlag}
}

proc ResourceView_validateDepHour { _expPath _flowNode _tableListWidget _cellRow  _cellColumn _cellContent _outErrMsg } {
   set errorFlag 0
   if { ${_cellContent} != "" && [string index ${_cellContent} 0] != "$" } {
      if { ! [string is integer ${_cellContent}] } {
	 set errorFlag 1
         upvar ${_outErrMsg} myOutputErrMsg
         set myOutputErrMsg "Invalid hour value: ${_cellContent}"
      }
   }
   return ${errorFlag}
}

proc ResourceView_validateDepExp { _expPath _flowNode _tableListWidget _cellRow  _cellColumn _cellContent _outErrMsg} {
   set errorFlag 0
   if { ${_cellContent} != "" && [string index ${_cellContent} 0] != "$" } {
      if { ! [file isdirectory ${_cellContent}] } {
	 set errorFlag 1
         upvar ${_outErrMsg} myOutputErrMsg
         set myOutputErrMsg "Experiment does not exists! ${_cellContent}"
      }
   }
   return ${errorFlag}
}

proc ResourceView_createDependsPopMenu { _tableListWidget _x _y } {
   set selections [${_tableListWidget} curselection]
   ::log::log debug "ResourceView_createDependsPopMenu selection: ${selections}"
   set nofSelection [llength ${selections}]

   set popMenu .popupMenu
   if { [winfo exists ${popMenu}] } {
      destroy ${popMenu}
   }
   menu ${popMenu} -title "popup"

   # ${popMenu} add separator
   ${popMenu} add command -label  "Add New Entry" -underline 0 -state normal \
      -command [list ResourceView_addNewDepEntry ${_tableListWidget} end] 


   if { ${nofSelection} == 1 } {
      set currentRow ${selections}
      ${popMenu} add command -label  "Add New Entry Before" -underline 0 -state normal \
         -command [list ResourceView_addNewDepEntry ${_tableListWidget} [expr ${currentRow}]] 
      ${popMenu} add command -label  "Add New Entry After" -underline 0 -state normal \
         -command [list ResourceView_addNewDepEntry ${_tableListWidget} [expr ${currentRow} + 1] ]
   }

   if { ${nofSelection} > 0 } {
      ${popMenu} add separator
      ${popMenu} add command -label  "Remove Entries" -underline 0 -state normal \
         -command [list ResourceView_removeDepEntry ${_tableListWidget} ${selections}]
   }

   tk_popup ${popMenu} ${_x} ${_y}

}

proc ResourceView_getDepResourceTableVar { _depFrame } {
   return ${_depFrame}.table_var
}

proc ResourceView_getDepNodeTableVar { _depFrame } {
   return ${_depFrame}.node_table_var
}

proc ResourceView_getDepTableVar { _tableListWidget } {
   return ${_tableListWidget}_var
}

proc ResourceView_createDependsWidget { _depFrame _expPath _moduleNode _flowNode } {
   ::log::log debug "ResourceView_createDependsWidget $_depFrame $_expPath $_moduleNode $_flowNode"
   global ResourceTableColumnMap

   set resourceLabel [label ${_depFrame}.res_label -text "Resource Dependencies (resource.xml)"]

   if { ! [info exists ResourceTableColumnMap] } {
      array set ResourceTableColumnMap {
         NodeColumnNumber 0
         StatusColumnNumber 1
         IndexColumnNumber 2
         LocalIndexColumnNumber 3
         HourColumnNumber 4
         ExpColumnNumber 5
      }
      # register ComboBox objects with the table
      tablelist::addBWidgetComboBox
   }

   # set defaultAlign center
   set defaultAlign left
   set columns [list 0 Node ${defaultAlign} \
                     0 Status ${defaultAlign} \
                     0 Index ${defaultAlign} \
                     0 "Local Index" ${defaultAlign} \
                     0 Hour ${defaultAlign} \
                     0 Exp ${defaultAlign}]
   set yscrollW ${_depFrame}.res_sy
   set xscrollW ${_depFrame}.res_sx

   set dependsTableW [
      tablelist::tablelist ${_depFrame}.table -selectmode extended -columns ${columns} \
         -arrowcolor white -spacing 1 -resizablecolumns 1 -movablecolumns 0 \
         -stretch all -relief flat -labelrelief flat -showseparators 1 -borderwidth 0 \
         -labelcommand tablelist::sortByColumn -labelpady 5 \
         -stripebg #e4e8ec -labelbd 1 -labelrelief raised \
         -yscrollcommand [list ${yscrollW} set] -xscrollcommand [list ${xscrollW} set] \
	 -editstartcommand [list ResourceView_editDepRowStartCallback ${_expPath} ${_flowNode}] \
	 -editendcommand [list ResourceView_editDepRowEndCallback ${_expPath} ${_flowNode}]
	 ]

   set resourceTableVar [ResourceView_getDepTableVar ${dependsTableW}]
   global ${resourceTableVar}
   ${dependsTableW} configure -listvariable ${resourceTableVar}
   ResourceView_registerVariable [winfo toplevel ${_depFrame}] ${resourceTableVar}
   ResourceView_registerStateChangeWidgets [winfo toplevel ${_depFrame}] "${dependsTableW} configure -state "

   # creating scrollbars
   scrollbar ${yscrollW} -command [list ${dependsTableW} yview]
   scrollbar ${xscrollW} -command [list ${dependsTableW} xview] -orient horizontal
   ::autoscroll::autoscroll ${yscrollW}
   ::autoscroll::autoscroll ${xscrollW}

   set nodeDependsLabelW [label ${_depFrame}.node_label -text "Node Dependencies (flow.xml)"]
   set yScrollNodeW ${_depFrame}.node_sy
   set xScrollNodeW ${_depFrame}.node_sx

   set nodeDependsTableW [
      tablelist::tablelist ${_depFrame}.node_table -selectmode extended -columns ${columns} \
         -arrowcolor white -spacing 1 -resizablecolumns 1 -movablecolumns 0 \
         -stretch all -relief flat -labelrelief flat -showseparators 1 -borderwidth 0 \
         -labelcommand tablelist::sortByColumn -labelpady 5 \
         -stripebg #e4e8ec  -labelbd 1 -labelrelief raised \
         -yscrollcommand [list ${yScrollNodeW} set] -xscrollcommand [list ${xScrollNodeW} set] \
	 -editstartcommand [list ResourceView_editNodeDepRowStartCallback ${_expPath} ${_moduleNode}] \
	 -editendcommand [list ResourceView_editDepRowEndCallback ${_expPath} ${_flowNode}] \
	 ]

   set nodeTableVar [ResourceView_getDepTableVar ${nodeDependsTableW}]
   global ${nodeTableVar}
   ${nodeDependsTableW} configure -listvariable ${nodeTableVar}
   ResourceView_registerVariable [winfo toplevel ${_depFrame}] ${nodeTableVar}

   # creating scrollbars
   scrollbar ${yScrollNodeW} -command [list ${nodeDependsTableW} yview]
   scrollbar ${xScrollNodeW} -command [list ${nodeDependsTableW} xview] -orient horizontal
   ::autoscroll::autoscroll ${yScrollNodeW}
   ::autoscroll::autoscroll ${xScrollNodeW}

  bind [${dependsTableW} bodytag] <Button-3> [list ResourceView_createDependsPopMenu ${dependsTableW} %X %Y]
  bind [${nodeDependsTableW} bodytag] <Button-3> [list ResourceView_createDependsPopMenu ${nodeDependsTableW} %X %Y]

   foreach columnIndex [list 0 1 2 3 4 5] {
     ${dependsTableW} columnconfigure ${columnIndex} -editable yes
     ${nodeDependsTableW} columnconfigure ${columnIndex} -editable yes
   }
   # configure the interactive editing of the Node and Status columnto be ComboBox
   ${nodeDependsTableW} columnconfigure $ResourceTableColumnMap(NodeColumnNumber) -editwindow ComboBox
   ${dependsTableW} columnconfigure $ResourceTableColumnMap(NodeColumnNumber) -editwindow ComboBox
   ${nodeDependsTableW} columnconfigure $ResourceTableColumnMap(StatusColumnNumber) -editwindow ComboBox
   ${dependsTableW} columnconfigure $ResourceTableColumnMap(StatusColumnNumber) -editwindow ComboBox

   grid ${resourceLabel} -row 0 -column 0 -padx 2 -pady 2 -sticky w
   grid ${dependsTableW} -row 1 -column 0 -padx 2 -pady 2 -sticky nsew
   grid ${yscrollW} -row 1 -column 1 -sticky nsew -padx 2 -pady 2
   grid ${xscrollW} -row 2 -sticky ew

   grid ${nodeDependsLabelW} -row 3 -column 0 -padx 2 -pady 2 -sticky w
   grid ${nodeDependsTableW} -row 4 -column 0 -padx 2 -pady 2 -sticky nsew
   grid ${yScrollNodeW} -row 4 -column 1 -sticky nsew -padx 2 -pady 2
   grid ${xScrollNodeW} -row 5 -sticky ew

   grid columnconfigure ${_depFrame} 0 -weight 1
   grid rowconfigure ${_depFrame} 1 -weight 1
   grid rowconfigure ${_depFrame} 4 -weight 1
}

proc ResourceView_updateNodeDependenciesWidgetState { _depFrame _newState } {
   ${_depFrame}.node_table configure -state ${_newState}
}

proc ResourceView_createAbortActionWidget { _abortActionFrame _expPath _moduleNode _flowNode } {
   set labelW ${_abortActionFrame}.abort_action
   set entryW ${_abortActionFrame}.abort_action_entry
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Abort Action:"
      set attrVariable [ResourceView_getAttrVariable ${_abortActionFrame} abortaction]
      global ${attrVariable}
      ComboBox ${entryW} -values { stop rerun } -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_abortActionFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_abortActionFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_abortActionFrame}] "${entryW} configure -state "
      grid ${labelW} -row 0 -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row 0 -column 1 -padx 2 -pady 2 -sticky nsew      
   }
}

proc ResourceView_createLoopWidget { _loopFrame _expPath _moduleNode _flowNode } {
   ResourceView_addLoopStartEntry ${_loopFrame} 0
   ResourceView_addLoopEndEntry ${_loopFrame} 1
   ResourceView_addLoopStepEntry ${_loopFrame} 2
   ResourceView_addLoopSetEntry ${_loopFrame} 3

   set orLabel [label ${_loopFrame}.label -justify left -text "(NOTE: Use of \"Loop Expresion\" disables Loop attributes above.)"]
   grid ${orLabel} -row 4 -column 0 -padx 2 -pady {20 2} -sticky w -columnspan 2

   set mySeparatorW [ttk::separator ${_loopFrame}.separator -orient horizontal]
   grid ${mySeparatorW} -row 5 -column 0 -padx 2 -pady {2 20} -sticky nsew -columnspan 2

   ResourceView_addLoopExprEntry ${_loopFrame} 6

   grid columnconfigure ${_loopFrame} 1 -weight 1
}

proc ResourceView_getAbortActionFrameWidget { _expPath _moduleNode _flowNode } {
   return [ResourceView_getTabFrameWidget ${_expPath} ${_moduleNode} ${_flowNode} action]
}

proc ResourceView_getBatchFrameWidget { _expPath _moduleNode _flowNode } {
   return [ResourceView_getTabFrameWidget ${_expPath} ${_moduleNode} ${_flowNode} batch]
}

proc ResourceView_getDependsFrameWidget { _expPath _moduleNode _flowNode } {
   return [ResourceView_getTabFrameWidget ${_expPath} ${_moduleNode} ${_flowNode} dep]
}

proc ResourceView_getLoopFrameWidget { _expPath _moduleNode _flowNode } {
   return [ResourceView_getTabFrameWidget ${_expPath} ${_moduleNode} ${_flowNode} loop]
}
 
proc ResourceView_getTabFrameWidget { _expPath _moduleNode _flowNode _tabName } {
   ::log::log debug "ResourceView_getTabFrameWidget  ${_expPath} ${_moduleNode} ${_tabName}"
   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]
   set noteBook ${topWidget}.note_book

   set tabFrame [${noteBook} getframe ${_tabName}]
   return ${tabFrame}
}

proc ResourceView_setAbortActionValue { _abortActionFrame _value } {
   set entryW ${_abortActionFrame}.abort_action_entry
   ${entryW} configure -text ${_value}
}

proc ResourceView_getAbortActionValue { _abortActionFrame } {
   set entryW ${_abortActionFrame}.abort_action_entry
   set value [string trim [${entryW} cget -text]]
   if { ${value} != "" && [string index ${value} 0] != "$" && ${value} != "stop" && ${value} != "rerun" } {
      error "Invalid abort action value: ${value}."
   }
   return ${value}
}

proc ResourceView_addLoopStartEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_start
   set entryW ${_loopFrame}.loop_start_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop Start:"
      set attrVariable [ResourceView_getAttrVariable ${_loopFrame} loopstart]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_loopFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_loopFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_loopFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
}

proc ResourceView_getLoopStartEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_start_entry
   set value [string trim [${entryW} cget -text]]
   if { ${value} != "" && [string index ${value} 0] != "$" 
        && ! [string is integer ${value}] } {
      error "Invalid loop start value \"${value}\" in loop settings."
   }
   return ${value}
}

proc ResourceView_addLoopSetEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_set
   set entryW ${_loopFrame}.loop_set_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop Set:"
      set attrVariable [ResourceView_getAttrVariable ${_loopFrame} loopset]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_loopFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_loopFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_loopFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
}

proc ResourceView_getLoopSetEntry { _loopFrame } {
   puts "ResourceView_getLoopSetEntry _loopFrame:$_loopFrame"
   set entryW ${_loopFrame}.loop_set_entry
   set value [string trim [${entryW} cget -text]]
   if { ${value} != "" && [string index ${value} 0] != "$" 
        && ! [string is integer ${value}] } {
      error "Invalid loop set value \"${value}\" in loop settings."
   }
   return ${value}
}

proc ResourceView_addLoopEndEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_end
   set entryW ${_loopFrame}.loop_end_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop End:"
      set attrVariable [ResourceView_getAttrVariable ${_loopFrame} loopend]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_loopFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_loopFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_loopFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
}

proc ResourceView_getLoopEndEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_end_entry
   set value [string trim [${entryW} cget -text]]

   if { ${value} != "" && [string index ${value} 0] != "$" 
        && ! [string is integer ${value}] } {
      error "Invalid loop start value \"${value}\" in loop settings."
   }
   return ${value}
}

proc ResourceView_addLoopStepEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_step
   set entryW ${_loopFrame}.loop_step_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop Step:"
      set attrVariable [ResourceView_getAttrVariable ${_loopFrame} loopstep]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_loopFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_loopFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_loopFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
}

proc ResourceView_getLoopStepEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_step_entry
   set value [string trim [${entryW} cget -text]]
   if { ${value} != "" && [string index ${value} 0] != "$" 
        && ! [string is integer ${value}] } {
      error "Invalid loop step value \"${value}\" in loop settings."
   }
   return ${value}
}

proc ResourceView_addLoopExprEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_expr
   set entryW ${_loopFrame}.loop_expr_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop Expression:"
      set attrVariable [ResourceView_getAttrVariable ${_loopFrame} loopexpr]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      ::tooltip::tooltip ${entryW} "Format start:end:step:set,start:end:step:set\nExample:1:256:1:32,512:768:1:32"
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_loopFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_loopFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_loopFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
}

proc ResourceView_getLoopExprEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_expr_entry
   set value [string trim [${entryW} cget -text]]
   if { ${value} != "" && [string index ${value} 0] != "$" } {
      set commaSplittedList [split ${value} ,]
      foreach loopValue ${commaSplittedList} {
         set colonSplittedList [split ${loopValue} :]
         foreach {mystart myend mystep myset} ${colonSplittedList} {}
	 if { ${mystart} != "" && ! [string is integer ${mystart}] } {
            error "Invalid loop start value \"${mystart}\" in loop expression \"${value}\" settings."
	 }
	 if { ${myend} != "" && ! [string is integer ${myend}] } {
            error "Invalid loop end value \"${myend}\" in loop expression  \"${value}\" settings."
	 }
	 if { ${mystep} != "" && ! [string is integer ${mystep}] } {
            error "Invalid loop step value \"${mystep}\" in loop expression  \"${value}\" settings."
	 }
	 if { ${myset} != "" && ! [string is integer ${myset}] } {
            error "Invalid loop set value \"${myset}\" in loop expression  \"${value}\" settings."
	 }
      }
   }
   return ${value}
}

# this command is called from a variable trace
# the proc definition requires 3 parameters for variable tracing
# however, defaults to empty strings...
proc ResourceView_setDataChanged { _sourceWidget _value {_name1 ""} {_name2 ""} {_op ""} } {
   set topLevelWidget [winfo toplevel ${_sourceWidget}]
   set dataChangeVariable ${topLevelWidget}_data_changed
   global ${dataChangeVariable}
   set ${dataChangeVariable} ${_value}
   ResourceView_registerVariable [winfo toplevel ${_sourceWidget}] ${dataChangeVariable}

   if { ${_value} == true } {
      ResourceView_updateSaveButtonState ${topLevelWidget} normal
   } else {
      ResourceView_updateSaveButtonState ${topLevelWidget} disabled
   }
}

proc ResourceView_editDepFlowNotify { _expPath _moduleNode _sourceWidget } {
   set editFlowVar ${_sourceWidget}_Flow_Edit_var
   global ${editFlowVar}
   set isContinue true

   if { [ExpModTree_getModInstances ${_expPath} ${_moduleNode}] > 1 } {
      if { ! [info exists ${editFlowVar}] } {

         # we only ask the user once
         set answer [MessageDlg .msg_window -icon warning -message "WARNING: You are about to edit a module used in more than one instance in the experiment." \
               -aspect 400 -title "Module Edit Notification" -type ok -justify center -parent ${_sourceWidget}]
         set ${editFlowVar} 1
      }
   }
   ResourceView_registerVariable [winfo toplevel ${_sourceWidget}] ${editFlowVar}
   return ${isContinue}
}


proc ResourceView_getDataChanged { _sourceWidget } {
   set topLevelWidget [winfo toplevel ${_sourceWidget}]
   set dataChangeVariable ${topLevelWidget}_data_changed
   global ${dataChangeVariable}
   
   set value false
   if { [info exists ${dataChangeVariable}] } {
      set value [set ${dataChangeVariable}]
   }
   return ${value}
}

proc ResourceView_getAttrVariable { _frameWidget _attrName } {
   set attrVar ${_frameWidget}_[string toupper ${_attrName}]
   return ${attrVar}
}

proc ResourceView_getEntryMACHINE { _batchFrame } {
   
   set entryW ${_batchFrame}.machine_entry
   set value [string trim [${entryW} cget -text]]
   return ${value}
}

proc ResourceView_addEntryMACHINE {_batchFrame _row {_value ""}} {
   
   set labelW ${_batchFrame}.machine
   set entryW ${_batchFrame}.machine_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Machine:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} machine]
      global ${attrVariable}
      ComboBox ${entryW} -values { pollux castor hadar spica \$FRONTEND \$BACKEND } -textvariable ${attrVariable} 
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "

      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew
      ::tooltip::tooltip ${entryW} "target cluster/host where job will execute"
   }

   if { ${_value} != "" } {
      ${entryW} configure -text ${_value}
   }
}

proc ResourceView_getEntryQUEUE {_batchFrame} {
   
   set entryW ${_batchFrame}.queue_entry
   set value [string trim [${entryW} cget -text]]
   return ${value}
}

proc ResourceView_addEntryQUEUE {_batchFrame _row {_value ""}} {
   set labelW ${_batchFrame}.queue
   set entryW ${_batchFrame}.queue_entry
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Queue:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} queue]
      global ${attrVariable}
      ComboBox ${entryW} -values { xfer fexfer daemon } -textvariable ${attrVariable} 
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
      ::tooltip::tooltip ${entryW} "specific queue on target host ex: \"xfer\""
   }
}

proc ResourceView_getEntryCATCHUP { _batchFrame {getint false} } {
   
   set entryW ${_batchFrame}.catchup_entry
   set value [string trim [${entryW} cget -text]]

   if { ${getint} == "true" } {
      switch ${value} {
         Normal {
            set value 8
         }
         Discretionary {
            set value 9
         }
      }
   }

   if { ${value} != "" && [string index ${value} 0] != "$" && ( ${value} < 0 || ${value} > 9 ) } {
      error "Invalid catchup value: ${value} in batch settings."
   }

   return ${value}
}

proc ResourceView_addEntryCATCHUP { _batchFrame _row {_value ""}} {
   set labelW ${_batchFrame}.catchup
   set entryW ${_batchFrame}.catchup_entry
   set values {1 2 3 4 5 6 7 Normal Discretionary}
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Catchup:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} catchup]
      ::log::log debug "ResourceView_addEntryCATCHUP attrVariable:${attrVariable}"
      global ${attrVariable}
      ComboBox ${entryW} -values ${values} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
      ::tooltip::tooltip ${entryW} "catchup value"
   }

   switch ${_value} {
      8 {
         set _value Normal
      }
      9 {
         set _value Discretionary 
      }
   }
   ${entryW} configure -text ${_value}
}

proc ResourceView_getEntryCPU {_batchFrame} {
   
   set entryW ${_batchFrame}.cpu_entry
   set value [string trim [${entryW} cget -text]]
   set errorFlag false
   if { ${value} != "" && [string index ${value} 0] != "$" } {
      # validate entry value
      switch [llength [split ${value} x]] {
         1 {
	    # integer value cpu
	    if { [scan ${value} %d var1] != 1 || ! [expr ${var1} > 0] } {
	       set errorFlag true
	    }
	 }
	 2 {
	    # n x m format
	    if { [scan ${value} %dx%d var1 var2] != 2
	         || ! [expr ${var1} > 0] || ! [expr ${var2} > 0] } {
	       set errorFlag true
	    }
	 }
	 3 {
	    # n x m x p format
	    if { [scan ${value} %dx%dx%d var1 var2 var3] != 3 
	         || ! [expr ${var1} > 0] || ! [expr ${var2} > 0] || ! [expr ${var3} > 0] } {
	       set errorFlag true
	    }
	 }
	 default {
	    # unsupported format
	    set errorFlag true
	 }
      }
   }
   if { ${errorFlag} == true } {
      error "Invalid cpu value \"${value}\" in batch settings."
   }

   return ${value}
}

proc ResourceView_addEntryCPU {_batchFrame _row {_value ""}} {
   
   set labelW ${_batchFrame}.cpu
   set entryW ${_batchFrame}.cpu_entry
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Cpu:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} cpu]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew
      ::tooltip::tooltip ${entryW} "number of cpus ex: \"1\" \"1x3\" \"1x3x4\""
   }

}

proc ResourceView_addEntryCPU_MULTIPLIER {_batchFrame _row {_value ""}} {
   
   set labelW ${_batchFrame}.cpu_mult
   set entryW ${_batchFrame}.cpu_mult_entry
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Cpu Multiplier:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} cpu_multiplier]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew
      ::tooltip::tooltip ${entryW} "cpu multiplier"
   }
}

proc ResourceView_getEntryCPU_MULTIPLIER {_batchFrame} {
   
   set entryW ${_batchFrame}.cpu_mult_entry
   set value [string trim [${entryW} cget -text]]
   set errorFlag false
   if { ${value} != "" && [string index ${value} 0] != "$" } {
      # validate entry value
      switch [llength [split ${value} x]] {
         1 {
	    # integer value cpu
	    if { [scan ${value} %d var1] != 1 || ! [expr ${var1} > 0] } {
	       set errorFlag true
	    }
	 }
	 2 {
	    # n x m format
	    if { [scan ${value} %dx%d var1 var2] != 2
	         || ! [expr ${var1} > 0] || ! [expr ${var2} > 0] } {
	       set errorFlag true
	    }
	 }
	 3 {
	    # n x m x p format
	    if { [scan ${value} %dx%dx%d var1 var2 var3] != 3 
	         || ! [expr ${var1} > 0] || ! [expr ${var2} > 0] || ! [expr ${var3} > 0] } {
	       set errorFlag true
	    }
	 }
	 default {
	    # unsupported format
	    set errorFlag true
	 }
      }
   }
   if { ${errorFlag} == true } {
      error "Invalid cpu multiplier value \"${value}\" in batch settings."
   }

   return ${value}
}

proc ResourceView_getEntryMPI { _batchFrame } {
   set attrVariable [ResourceView_getAttrVariable ${_batchFrame} mpi]
   global ${attrVariable}
   set value ""
   
   catch { set value [set ${attrVariable}] }
   return ${value}
}

proc ResourceView_addEntryMPI { _batchFrame _row {_value ""}} {
   
   set labelW ${_batchFrame}.mpi
   set entryW ${_batchFrame}.mpi_entry
   # ::tooltip::tooltip  ${entryW} "Check on to enable mpi job."

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Mpi:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} mpi]
      global ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      checkbutton ${entryW} -indicatoron true -onvalue 1 -offvalue "" -variable ${attrVariable}
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
      ::tooltip::tooltip ${entryW} "flag to set MPI job"
   }
}

proc ResourceView_getEntryMEMORY {_batchFrame} {
   
   set entryW ${_batchFrame}.memory_entry
   set value [string toupper [string trim [${entryW} cget -text]]]
   set errorFlag false

   if { ${value} != "" && [string index ${value} 0] != "$" } {
      switch [string index ${value} end] {
	 M {
	    if { [scan ${value} %dM var1] != 1 || ! [expr ${var1} > 0] } {
	       set errorFlag true
	    }
	 }

	 G {
	    if { [scan ${value} %dG var1] != 1 || ! [expr ${var1} > 0]} {
	       set errorFlag true
	    }
	 }

	 default {
	    set errorFlag true
	 }
      }
   }

   if { ${errorFlag} == true } {
      error "Invalid memory value \"${value}\" in batch settings."
   }

   return ${value}
}

proc ResourceView_addEntryMEMORY {_batchFrame _row {_value ""}} {
   ::log::log debug "ResourceView_addEntryMEMORY _value:$_value"
   set labelW ${_batchFrame}.memory
   set entryW ${_batchFrame}.memory_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Memory:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} memory]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
      ::tooltip::tooltip ${entryW} "memory required to run the job ex: \"512M\" \"2G\""
   }
}

proc ResourceView_getEntryWALLCLOCK {_batchFrame} {
   
   set entryW ${_batchFrame}.wallclock_entry
   set value [string trim [${entryW} cget -text]]
   if { ${value} != "" && [string index ${value} 0] != "$" 
        && (! [string is integer ${value}] || ! [expr ${value} > 0]) } {
      error "Invalid wallclock value \"${value}\" in batch settings."
   }
   
   return ${value}
}

proc ResourceView_addEntryWALLCLOCK {_batchFrame _row {_value ""}} {
   
   set labelW ${_batchFrame}.wallclock
   set entryW ${_batchFrame}.wallclock_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Wallclock:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} wallclock]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
      ::tooltip::tooltip ${entryW} "job execution wall clock time in minutes ex: \"15\""
   }
}

proc ResourceView_getEntrySOUMET_ARGS {_batchFrame} {
   
   set entryW ${_batchFrame}.generic_entry
   set value [string trim [${entryW} cget -text]]
   return ${value}
}

proc ResourceView_addEntrySOUMET_ARGS {_batchFrame _row {_value ""}} {
   
   set labelW ${_batchFrame}.generic
   set entryW ${_batchFrame}.generic_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Soumet_args:"
      set attrVariable [ResourceView_getAttrVariable ${_batchFrame} soumet_args]
      global ${attrVariable}
      Entry ${entryW} -textvariable ${attrVariable}
      trace add variable ${attrVariable} write "ResourceView_setDataChanged ${_batchFrame} true"
      ResourceView_registerVariable [winfo toplevel ${_batchFrame}] ${attrVariable}
      ResourceView_registerStateChangeWidgets [winfo toplevel ${_batchFrame}] "${entryW} configure -state "
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
      ::tooltip::tooltip ${entryW} "extra arguments to ord_soumet ex:\"-waste 5 -smt 2\""
   }
}

proc ResourceView_raiseError { _title _errMsg _parentW } {
   ::log::log debug "ResourceView_raiseError title:${_title} _errMsg:${_errMsg} _parentW:${_parentW}"
      MessageDlg .msg_window -icon error -message "${_errMsg}" \
         -title ${_title} -type ok -justify center -parent ${_parentW}
}

# register a widget command to be called whenever the read-only state of the
# resource xml file changes.
proc ResourceView_registerStateChangeWidgets { _topWidget _command } {
   set registerResourcePermission ${_topWidget}_ResourcePermission
   global ${registerResourcePermission}

   if { ! [info exists  ${registerResourcePermission}] } {
      set ${registerResourcePermission} {}
      ResourceView_registerVariable ${_topWidget} ${registerResourcePermission}
   }
   if { [lsearch [set ${registerResourcePermission}] ${_command}] == -1 }  {
      lappend ${registerResourcePermission} ${_command}
   }
}

proc ResourceView_invokeStateChangeWidgets { _topWidget _newState } {
   set registerResourcePermission ${_topWidget}_ResourcePermission
   global ${registerResourcePermission}
   if { [info exists ${registerResourcePermission}] } {
      foreach command [set ${registerResourcePermission}] {
         eval ${command} ${_newState}
      }
   }
}

proc ResourceView_registerVariable { _topWidget _varName } {
   set registerListVar ${_topWidget}_Register_var
   global ${registerListVar}
   if { ! [info exists  ${registerListVar}] } {
      set ${registerListVar} {}
   }
   if { [lsearch [set ${registerListVar}] ${_varName}] == -1 }  {
      lappend ${registerListVar} ${_varName}
   }
}

proc ResourceView_cleanRegisteredVariables { _topWidget {_name1 ""} {_name2 ""} {_op ""} } {
   ::log::log debug "ResourceView_cleanRegisteredVariables $_topWidget"
   set registerListVar ${_topWidget}_Register_var
   global ${registerListVar}
   if { [info exists ${registerListVar}] } {
      foreach var [set ${registerListVar}] {
         ::log::log debug "ResourceView_cleanRegisteredVariables unset ${var}"
         global ${var}
         catch { unset ${var} }
      }
      unset ${registerListVar}
   }
}

