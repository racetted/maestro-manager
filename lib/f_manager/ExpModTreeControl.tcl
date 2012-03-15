proc ExpModTreeControl_init { _sourceWidget _expPath } {

   if { [ExpModTreeView_isOpened ${_expPath}] == false } {
      # get exp first module
      set entryFlowFile [ExpLayout_getEntryModulePath ${_expPath}]/flow.xml

      # recursive read of all module flow.xml
      # the exp module tree is created at the same time
      ModuleFlow_readXml ${_expPath} ${entryFlowFile} ""

      # create the exp modules tree gui
      ExpModTreeView_createWidgets ${_expPath}

      # get exp first module
      set entryModTreeNode [ExpModTree_getEntryModRecord ${_expPath}]

      ExpModTreeView_draw ${_expPath} ${entryModTreeNode}
   } else {
      ExpModTreeView_toFront ${_expPath}
   }
}

#
# _moduleNode is experiment tree node name of the module
#             i.e. /enkf_mod/anal_mod/gem_mod
#
proc ExpModTreeControl_moduleSelection { _expPath _moduleNode {_sourceW .} } {
   puts "ExpModTreeControl_moduleSelection _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   set moduleColor [ExpModTreeView_getModuleColor ${_expPath} ${_moduleNode}]
   DrawUtil_setShadowColor ${modTreeNodeRecord} [ExpModTreeView_getCanvas ${_expPath}] ${moduleColor}
   if { [ModuleFlow_isModuleNew ${_expPath} ${_moduleNode}] == false } {
      ModuleFlowView_initModule ${_expPath} ${_moduleNode} ${_sourceW}
      ExpModTreeControl_addOpenedModule ${_expPath} ${_moduleNode}
   } else {
      puts "ExpModTreeControl_moduleSelection new module"
   }
}

proc ExpModTreeControl_moduleClosing { _expPath _moduleNode } {
   # reset module shadow color
   set shadowColor [SharedData_getColor SHADOW_COLOR]
   set modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   DrawUtil_setShadowColor ${modTreeNodeRecord} [ExpModTreeView_getCanvas ${_expPath}] ${shadowColor}
   ExpModTreeControl_removeOpenedModule ${_expPath} ${_moduleNode}
}

proc ExpModTreeControl_newExpFlow { _expPath _topWidget } {
   
   if { [ catch { 
      ExpLayout_flowBuilder ${_expPath}
   } errMsg ] } {
      MaestroConsole_addErrorMsg ${errMsg}
      MessageDlg .msg_window -icon error -message "An error happend generating the exp flow.xml file. Check the maestro console for more details." \
         -title "Failed Operation" -type ok -justify center -parent ${_sourceW}
      return
   }
   ExpModTreeControl_setModuleFlowChanged ${_expPath} false
   ModuleFlowView_setStatusMsg ${_topWidget} "experiment flow re-generated."
}

proc ExpModTreeControl_closeWindow { _expPath _topWidget } {
   set expChecksum [::crc::cksum ${_expPath}]
   global OpenedModules_${expChecksum}
   global ${_topWidget}_status_afterid env
   global FlowHasChanged_${expChecksum}

   if { [ExpModTreeControl_isModuleFlowChanged ${_expPath}] == true } {
      set answer [MessageDlg .msg_window -icon warning -message "You have changed a module flow but did not re-generate \
               your experiment flow, are you sure you want to continue?" \
            -aspect 400 -title "Module Center Quit Notification" -type okcancel -justify center -parent ${_topWidget}]
      if { ${answer} == 1 } {
         return
      }
   }
   MaestroConsole_addMsg "Closing experiment ${_expPath}."

   # recursive delete all module records from the tree of modules
   set entryModTreeNode [ExpModTree_getEntryModRecord ${_expPath}]
   catch { ExpModTreeView_deleteNode ${_expPath} ${entryModTreeNode} }

   # delete the working directory of the exp
   catch { ExpLayout_clearWorkDir ${_expPath} }

   # delete widgets
   destroy ${_topWidget}

   # clean any callback waiting
   if { [info exists ${_topWidget}_status_afterid] } {
      after cancel [set ${_topWidget}_status_afterid]
   }

   catch { unset OpenedModules_${expChecksum} }
   catch { unset FlowHasChanged_${expChecksum} }

}

# this proc is used as a callback when a module node is being deleted from
# a module flow. The deleted module is a referenced module that was used
# within a module and that is not used anymore.
# _expPath is path to the experiment
# _moduleNode is experiment tree node name of the module
#             i.e. /enkf_mod/anal_mod/gem_mod
proc ExpModTreeControl_moduleDeleted { _expPath _moduleNode } {

   puts "ExpModTreeControl_moduleDeleted: _expPath=${_expPath} _moduleNode=${_moduleNode}"
   ExpModTree_deleteModule ${_expPath} ${_moduleNode}

   DrawUtil_clearCanvas [ExpModTreeView_getCanvas ${_expPath}]
   ExpModTreeView_draw ${_expPath} [ExpModTree_getEntryModRecord ${_expPath}]
}

# this proc is used as a callback when a module node is being added to
# a module flow.
# _parentModuleNode is in the form /enkf_mod/anal_mod
# _moduleNode is experiment tree node name of the module
#             i.e. /enkf_mod/anal_mod/gem_mod
proc ExpModTreeControl_moduleAdded { _expPath _parentModuleNode _moduleNode } {

   puts "ExpModTreeControl_moduleAdded: _expPath=${_expPath} _parentModuleNode:${_parentModuleNode} _moduleNode=${_moduleNode}"
   
   ExpModTree_addModule ${_expPath} ${_moduleNode} [ExpModTree_getRecordName ${_expPath} ${_parentModuleNode}]

   # refresh module tree
   DrawUtil_clearCanvas [ExpModTreeView_getCanvas ${_expPath}]
   ExpModTreeView_draw ${_expPath} [ExpModTree_getEntryModRecord ${_expPath}]
}

# redraw the experiment tree... this is a callback when
# a user refreshes a module flow, the experiment needs to be updated as well
proc ExpModTreeControl_redraw { _expPath } {
   DrawUtil_clearCanvas [ExpModTreeView_getCanvas ${_expPath}]
   ExpModTreeView_draw ${_expPath} [ExpModTree_getEntryModRecord ${_expPath}]
}

proc ExpModTreeControl_isOpenedModule { _expPath _moduleNode } {
   set expChecksum [::crc::cksum ${_expPath}]
   global OpenedModules_${expChecksum}
   if { [info exists OpenedModules_${expChecksum}] && [lsearch [set OpenedModules_${expChecksum}] ${_moduleNode}] != -1 } {
      return true
   }
   return false
}

proc ExpModTreeControl_removeOpenedModule { _expPath _moduleNode } {
   set expChecksum [::crc::cksum ${_expPath}]
   global OpenedModules_${expChecksum}

   if { [info exists OpenedModules_${expChecksum}] } {
      set foundIndex [lsearch [set OpenedModules_${expChecksum}] ${_moduleNode}]
      if { ${foundIndex} != -1 } {
         set OpenedModules_${expChecksum} [lreplace [set OpenedModules_${expChecksum}] ${foundIndex} ${foundIndex}]
      }
   }
}

proc ExpModTreeControl_addOpenedModule { _expPath _moduleNode } {
   set expChecksum [::crc::cksum ${_expPath}]
   global OpenedModules_${expChecksum}
   if { ! [info exists OpenedModules_${expChecksum}] } {
      set OpenedModules_${expChecksum} {}
   }
   if { [lsearch [set OpenedModules_${expChecksum}] ${_moduleNode}] == -1 } {
      lappend OpenedModules_${expChecksum} ${_moduleNode}
   }
}

# should be called when a module has been saved, used to notify user to 
# save exp flow
# _isChanged is true or false
proc ExpModTreeControl_setModuleFlowChanged { _expPath _isChanged } {
   set expChecksum [::crc::cksum ${_expPath}]
   global FlowHasChanged_${expChecksum}
   
   set FlowHasChanged_${expChecksum} ${_isChanged}
}

proc ExpModTreeControl_isModuleFlowChanged { _expPath } {
   set expChecksum [::crc::cksum ${_expPath}]
   global FlowHasChanged_${expChecksum}

   set isChanged false
   if { [info exists FlowHasChanged_${expChecksum}] } {
      set isChanged [set FlowHasChanged_${expChecksum}]
   }
   return ${isChanged}
}