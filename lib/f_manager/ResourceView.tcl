package require tablelist
package require autoscroll


proc ResourceView_createWidgets { _expPath _moduleNode _flowNodeRecord } {
   puts "ResourceView_createWidgets _expPath:${_expPath} _moduleNode:${_moduleNode} _flowNodeRecord:${_flowNodeRecord}"
   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]
   if { [winfo exists ${topWidget}] } {
      destroy ${topWidget}
   }

   toplevel ${topWidget}
   ModuleFlowView_registerToplevel ${_expPath} ${_moduleNode} ${topWidget}

   set flowNode [${_flowNodeRecord} cget -flow_path]
   wm title ${topWidget} "Resource Settings ([ModuleFlow_record2NodeName ${_flowNodeRecord}])"
   set flowCanvas [ModuleFlowView_getCanvas ${_expPath} ${_moduleNode}]
   MiscTkUtils_positionWindow ${flowCanvas} ${topWidget}

   set noteBook [NoteBook ${topWidget}.note_book -height 300 -width 500 -tabbevelsize 2]

   ${noteBook} insert 0 batch -text Batch
   ${noteBook} insert 1 dep -text Dependencies
   ${noteBook} insert 2 action -text Abort_action

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
      -command [list ResourceControl_populateData ${_expPath} ${_moduleNode} ${_flowNodeRecord}]]
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

proc ResourceView_createBatchWidget { _batchFrame _expPath _moduleNode _flowNode } {

   ResourceView_addEntryMACHINE ${_batchFrame} 1
   ResourceView_addEntryQUEUE ${_batchFrame} 2
   ResourceView_addEntryCPU ${_batchFrame} 3
   ResourceView_addEntryMEMORY ${_batchFrame} 4
   ResourceView_addEntryWALLCLOCK ${_batchFrame} 5
   ResourceView_addEntryCATCHUP ${_batchFrame} 6
   ResourceView_addEntryMPI ${_batchFrame} 7
   ResourceView_addEntrySOUMET_ARGS ${_batchFrame} 8

   grid columnconfigure ${_batchFrame} 1 -weight 1
}

proc ResourceView_addNewDepEntry { _tableListWidget _expPath _flowNode _position } {
   set nodeId [ExpLayout_getModuleChecksum ${_expPath} ${_flowNode}]
   global Resource_${nodeId}_depends

   set Resource_${nodeId}_depends [linsert [set Resource_${nodeId}_depends] ${_position} [list node "" end "" "" "" ""]]
}

proc ResourceView_removeDepEntry { _tableListWidget _expPath _flowNode _positions } {
   set nodeId [ExpLayout_getModuleChecksum ${_expPath} ${_flowNode}]
   global Resource_${nodeId}_depends
   set reversePositions [lsort -decreasing ${_positions}]
   foreach deletePosition ${reversePositions} {
      set Resource_${nodeId}_depends [lreplace [set Resource_${nodeId}_depends] ${deletePosition} ${deletePosition}]
   }
}

proc ResourceView_createDependsPopMenu { _tableListWidget _expPath _flowNode  _x _y } {
   set selections [${_tableListWidget} curselection]
   puts "ResourceView_createDependsPopMenu selection: ${selections}"
   set nofSelection [llength ${selections}]

   set popMenu .popupMenu
   if { [winfo exists ${popMenu}] } {
      destroy ${popMenu}
   }
   menu ${popMenu} -title [file tail ${_flowNode}]

   # ${popMenu} add separator
   ${popMenu} add command -label  "Add New Entry" -underline 0 -state normal \
      -command [list ResourceView_addNewDepEntry ${_tableListWidget} ${_expPath} ${_flowNode} end]


   if { ${nofSelection} == 1 } {
      set currentRow ${selections}
      ${popMenu} add command -label  "Add New Entry Before" -underline 0 -state normal \
         -command [list ResourceView_addNewDepEntry ${_tableListWidget} ${_expPath} ${_flowNode} [expr ${currentRow} - 1]]
      ${popMenu} add command -label  "Add New Entry After" -underline 0 -state normal \
         -command [list ResourceView_addNewDepEntry ${_tableListWidget} ${_expPath} ${_flowNode} [expr ${currentRow} + 1]]
   }

   if { ${nofSelection} > 0 } {
      ${popMenu} add separator
      ${popMenu} add command -label  "Remove Entries" -underline 0 -state normal \
         -command [list ResourceView_removeDepEntry ${_tableListWidget} ${_expPath} ${_flowNode} ${selections}]
   }

   tk_popup ${popMenu} ${_x} ${_y}

}

proc ResourceView_createDependsWidget { _depFrame _expPath _moduleNode _flowNode } {
   set nodeId [ExpLayout_getModuleChecksum ${_expPath} ${_flowNode}]
   puts "ResourceView_createDependsWidget nodeId:${nodeId}"
   global Resource_${nodeId}_depends

   # set defaultAlign center
   set defaultAlign left
   set columns [list 0 Type ${defaultAlign} \
                     0 Node ${defaultAlign} \
                     0 Status ${defaultAlign} \
                     0 Index ${defaultAlign} \
                     0 "Local Index" ${defaultAlign} \
                     0 Hour ${defaultAlign} \
                     0 Exp ${defaultAlign}]
   set yscrollW ${_depFrame}.sy
   set xscrollW ${_depFrame}.sx

   set dependsTableW [
      tablelist::tablelist ${_depFrame}.table -selectmode extended -columns ${columns} \
         -arrowcolor white -spacing 1 -resizablecolumns 1 -movablecolumns 0 \
         -stretch all -relief flat -labelrelief flat -showseparators 0 -borderwidth 0 \
         -labelcommand tablelist::sortByColumn -labelpady 5 \
         -stripebg #e4e8ec \
         -labelbd 1 -labelrelief raised -listvariable Resource_${nodeId}_depends \
         -yscrollcommand [list ${yscrollW} set] -xscrollcommand [list ${xscrollW} set] \
         -editendcommand [list ResourceControl_dependsRowEditEndCallback]
  ]

  # bind [${dependsTableW} bodytag] <Button-3> [list ResourceControl_dependsRightClickCallback ${dependsTableW} %X %Y]]
  bind [${dependsTableW} bodytag] <Button-3> [list ResourceView_createDependsPopMenu ${dependsTableW} ${_expPath} ${_flowNode}  %X %Y]

   # for now don't allow editing of the type field
   foreach columnIndex [list 1 2 3 4 5 6 ] {
     ${dependsTableW} columnconfigure ${columnIndex} -editable yes
   }

   # creating scrollbars
   scrollbar ${yscrollW} -command [list ${dependsTableW} yview]
   scrollbar ${xscrollW} -command [list ${dependsTableW} xview] -orient horizontal
   ::autoscroll::autoscroll ${yscrollW}
   ::autoscroll::autoscroll ${xscrollW}

   grid ${dependsTableW} -padx 2 -pady 2 -sticky nsew
   grid ${yscrollW} -row 0 -column 1 -sticky nsew -padx 2 -pady 2
   grid ${xscrollW} -sticky ew

   grid columnconfigure ${_depFrame} 0 -weight 1
   grid rowconfigure ${_depFrame} 0 -weight 1
}

proc ResourceView_createAbortActionWidget { _abortActionFrame _expPath _moduleNode _flowNode } {
   set labelW ${_abortActionFrame}.abort_action
   set entryW ${_abortActionFrame}.abort_action_entry
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Abort Action:"
      ComboBox ${entryW} -values { stop rerun }
      grid ${labelW} -row 0 -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row 0 -column 1 -padx 2 -pady 2 -sticky nsew      
   }
}

proc ResourceView_createLoopWidget { _loopFrame _expPath _moduleNode _flowNode } {
   ResourceView_addLoopStartEntry ${_loopFrame} 0
   ResourceView_addLoopEndEntry ${_loopFrame} 1
   ResourceView_addLoopStepEntry ${_loopFrame} 2
   ResourceView_addLoopSetEntry ${_loopFrame} 3
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
   puts "ResourceView_getTabFrameWidget  ${_expPath} ${_moduleNode} ${_tabName}"
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
   set value [${entryW} cget -text]
   return ${value}
}

proc ResourceView_addLoopStartEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_start
   set entryW ${_loopFrame}.loop_start_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop Start:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }

   ${entryW} delete 0 end
   if { ${_value} != "" } {
      ${entryW} insert 0 ${_value}
   }
}

proc ResourceView_getLoopStartEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_start_entry
   set value [${entryW} cget -text]
}

proc ResourceView_addLoopSetEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_set
   set entryW ${_loopFrame}.loop_set_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop Set:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }

   ${entryW} delete 0 end
   if { ${_value} != "" } {
      ${entryW} insert 0 ${_value}
   }
}

proc ResourceView_getLoopSetEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_set_entry
   set value [${entryW} cget -text]
}

proc ResourceView_addLoopEndEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_end
   set entryW ${_loopFrame}.loop_end_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop End:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }

   ${entryW} delete 0 end
   if { ${_value} != "" } {
      ${entryW} insert 0 ${_value}
   }
}

proc ResourceView_getLoopEndEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_end_entry
   set value [${entryW} cget -text]
}

proc ResourceView_addLoopStepEntry { _loopFrame _row {_value ""}} {
   
   set labelW ${_loopFrame}.loop_step
   set entryW ${_loopFrame}.loop_step_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Loop Step:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }

   ${entryW} delete 0 end
   if { ${_value} != "" } {
      ${entryW} insert 0 ${_value}
   }
}

proc ResourceView_getLoopStepEntry { _loopFrame } {
   set entryW ${_loopFrame}.loop_step_entry
   set value [${entryW} cget -text]
}

proc ResourceView_getEntryMACHINE { _attr_frame_w } {
   
   set entryW ${_attr_frame_w}.machine_entry
   set value [${entryW} cget -text]
   return ${value}
}

proc ResourceView_addEntryMACHINE {_attr_frame_w _row {_value ""}} {
   
   set labelW ${_attr_frame_w}.machine
   set entryW ${_attr_frame_w}.machine_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Machine:"
      ComboBox ${entryW} -values { alef dorval-ib pollux castor hadar spica }

      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew
   }

   if { ${_value} != "" } {
      ${entryW} configure -text ${_value}
   }
}

proc ResourceView_getEntryQUEUE {_attr_frame_w} {
   
   set entryW ${_attr_frame_w}.queue_entry
   set value [${entryW} cget -text]
   return ${value}
}

proc ResourceView_addEntryQUEUE {_attr_frame_w _row {_value ""}} {
   set labelW ${_attr_frame_w}.queue
   set entryW ${_attr_frame_w}.queue_entry
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Queue:"
      ComboBox ${entryW} -values { xfer fexfer daemon }
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }

   ${entryW} configure -text ${_value}
}

proc ResourceView_getEntryCATCHUP { _attr_frame_w {getint false} } {
   
   set entryW ${_attr_frame_w}.catchup_entry
   set value [${entryW} cget -text]
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

   return ${value}
}

proc ResourceView_addEntryCATCHUP { _attr_frame_w _row {_value ""}} {
   set labelW ${_attr_frame_w}.catchup
   set entryW ${_attr_frame_w}.catchup_entry
   set values {1 2 3 4 5 6 7 Normal Discretionary}
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Catchup:"
      ComboBox ${entryW} -values ${values}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }

   ${entryW} configure -text ${_value}
}

proc ResourceView_getEntryCPU {_attr_frame_w} {
   
   set entryW ${_attr_frame_w}.cpu_entry
   set value [${entryW} cget -text]
   return ${value}
}

proc ResourceView_addEntryCPU {_attr_frame_w _row {_value ""}} {
   
   set labelW ${_attr_frame_w}.cpu
   set entryW ${_attr_frame_w}.cpu_entry
   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Cpu:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew
   }

   ${entryW} delete 0 end
   ${entryW} insert 0 ${_value}
}

proc ResourceView_getEntryMPI { _attr_frame_w } {
   global ${_attr_frame_w}_mpi_entry
   set value false
   
   catch { set value [set ${_attr_frame_w}_mpi_entry] }
   return ${value}
}

proc ResourceView_addEntryMPI {_attr_frame_w _row {_value ""}} {
   
   set labelW ${_attr_frame_w}.mpi
   set entryW ${_attr_frame_w}.mpi_entry
   # ::tooltip::tooltip  ${entryW} "Check on to enable mpi job."

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Mpi:"
      checkbutton ${_attr_frame_w}.mpi_entry -indicatoron true \
      -onvalue 1 -offvalue "" -variable ${_attr_frame_w}_mpi_entry
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
   if { ${_value} == "1" } {
      ${entryW} select
   } else {
      ${entryW} deselect
   }
}

proc ResourceView_getEntryMEMORY {_attr_frame_w} {
   
   set entryW ${_attr_frame_w}.memory_entry
   set value [${entryW} cget -text]
   return ${value}
}

proc ResourceView_addEntryMEMORY {_attr_frame_w _row {_value ""}} {
   puts "ResourceView_addEntryMEMORY _value:$_value"
   set labelW ${_attr_frame_w}.memory
   set entryW ${_attr_frame_w}.memory_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Memory:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
   ${entryW} delete 0 end
   ${entryW} insert 0 ${_value}
}

proc ResourceView_getEntryWALLCLOCK {_attr_frame_w} {
   
   set entryW ${_attr_frame_w}.wallclock_entry
   set value [${entryW} cget -text]
   return ${value}
}

proc ResourceView_addEntryWALLCLOCK {_attr_frame_w _row {_value ""}} {
   
   set labelW ${_attr_frame_w}.wallclock
   set entryW ${_attr_frame_w}.wallclock_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Wallclock:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
   ${entryW} delete 0 end
   ${entryW} insert 0 ${_value}
}

proc ResourceView_getEntrySOUMET_ARGS {_attr_frame_w} {
   
   set entryW ${_attr_frame_w}.generic_entry
   set value [${entryW} cget -text]
   return ${value}
}

proc ResourceView_addEntrySOUMET_ARGS {_attr_frame_w _row {_value ""}} {
   
   set labelW ${_attr_frame_w}.generic
   set entryW ${_attr_frame_w}.generic_entry

   if { ! [winfo exists ${labelW}] } {
      label ${labelW} -text "Soumet_args:"
      Entry ${entryW}
      grid ${labelW} -row ${_row} -column 0 -padx 2 -pady 2 -sticky w
      grid ${entryW} -row ${_row} -column 1 -padx 2 -pady 2 -sticky nsew      
   }
   ${entryW} delete 0 end
   ${entryW} insert 0 ${_value}
}

