package require BWidget 1.9
package require tooltip
package require log

SharedData_init
SharedData_setMiscData IMAGE_DIR $env(SEQ_MANAGER_BIN)/../etc/images

#option add *activeBackground [SharedData_getColor ACTIVE_BG]
#option add *selectBackground [SharedData_getColor SELECT_BG]
 
MaestroConsole_init

proc ExpModTreeControl_init { _sourceWidget _expPath } {
   global errorInfo
   if { [ catch { 
      # tracing settings
      # by default errors and info level are enabled
      # debug is disabled, can be turned on from gui
      ::log::lvSuppress emergency 0
      ::log::lvSuppress alert 0
      ::log::lvSuppress critical 0
      ::log::lvSuppress error 0
      ::log::lvSuppress info 0
      ::log::lvSuppress debug
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
   } errMsg ] } {
      ::log::log error ${errorInfo}
      MessageDlg .msg_window -icon error -message "${errMsg}" -aspect 400 \
         -title "Application Error" -type ok -justify center -parent ${_sourceWidget}
      MaestroConsole_addErrorMsg ${errMsg}
   }
}

#
# _moduleNode is experiment tree node name of the module
#             i.e. /enkf_mod/anal_mod/gem_mod
#
proc ExpModTreeControl_moduleSelection { _expPath _moduleNode {_sourceW .} } {
   ::log::log debug "ExpModTreeControl_moduleSelection _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   set moduleColor [ExpModTreeView_getModuleColor ${_expPath} ${_moduleNode}]
   DrawUtil_setShadowColor ${modTreeNodeRecord} [ExpModTreeView_getCanvas ${_expPath}] ${moduleColor}
   if { [ModuleFlow_isModuleNew ${_expPath} ${_moduleNode}] == false } {
      ModuleFlowView_initModule ${_expPath} ${_moduleNode} ${_sourceW}
      ExpModTreeControl_addOpenedModule ${_expPath} ${_moduleNode}
   } else {
      ::log::log debug "ExpModTreeControl_moduleSelection new module"
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
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]

   if { [ExpModTree_isTreeChanged ${_expPath}] == true } {
      set answer [MessageDlg .msg_window -icon warning -message "There are unsaved changes in module flow(s), \
             are you sure you want to continue?" \
            -aspect 400 -title "Flow Manager Close Notification" -type okcancel -justify center -parent ${_topWidget}]
      if { ${answer} == 1 } {
         return
      }
   }

   if { [ExpModTreeControl_isModuleFlowChanged ${_expPath}] == true } {
      set answer [MessageDlg .msg_window -icon warning -message "You have changed a module flow but did not re-generate \
               your experiment flow, are you sure you want to continue?" \
            -aspect 400 -title "Flow Manager Close Notification" -type okcancel -justify center -parent ${_topWidget}]
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
   global ${_topWidget}_status_afterid
   if { [info exists ${_topWidget}_status_afterid] } {
      after cancel [set ${_topWidget}_status_afterid]
      unset ${_topWidget}_status_afterid
   }

   foreach globalVar [info globals ${expChecksum}*] {
      foreach globalVar [info globals ${expChecksum}*] {
         global [set globalVar]
         unset [set globalVar]
      }
   }
}

# this proc is used as a callback when a module node is being deleted from
# a module flow. The deleted module is a referenced module that was used
# within a module and that is not used anymore.
# _expPath is path to the experiment
# _moduleNode is experiment tree node name of the module
#             i.e. /enkf_mod/anal_mod/gem_mod
proc ExpModTreeControl_moduleDeleted { _expPath _moduleNode } {

   ::log::log debug "ExpModTreeControl_moduleDeleted: _expPath=${_expPath} _moduleNode=${_moduleNode}"
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

   ::log::log debug "ExpModTreeControl_moduleAdded: _expPath=${_expPath} _parentModuleNode:${_parentModuleNode} _moduleNode=${_moduleNode}"
   
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
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   global ${expChecksum}_OpenedModules
   if { [info exists ${expChecksum}_OpenedModules] && [lsearch [set ${expChecksum}_OpenedModules] ${_moduleNode}] != -1 } {
      return true
   }
   return false
}

proc ExpModTreeControl_removeOpenedModule { _expPath _moduleNode } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   global ${expChecksum}_OpenedModules

   if { [info exists ${expChecksum}_OpenedModules] } {
      set foundIndex [lsearch [set ${expChecksum}_OpenedModules] ${_moduleNode}]
      if { ${foundIndex} != -1 } {
         set ${expChecksum}_OpenedModules [lreplace [set ${expChecksum}_OpenedModules] ${foundIndex} ${foundIndex}]
      }
   }
}

proc ExpModTreeControl_addOpenedModule { _expPath _moduleNode } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   global ${expChecksum}_OpenedModules
   if { ! [info exists ${expChecksum}_OpenedModules] } {
      set ${expChecksum}_OpenedModules {}
   }
   if { [lsearch [set ${expChecksum}_OpenedModules] ${_moduleNode}] == -1 } {
      lappend ${expChecksum}_OpenedModules ${_moduleNode}
   }
}

# should be called when a module has been saved, used to notify user to 
# save exp flow
# _isChanged is true or false
proc ExpModTreeControl_setModuleFlowChanged { _expPath _isChanged } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   global ${expChecksum}_FlowHasChanged
   
   set ${expChecksum}_FlowHasChanged ${_isChanged}
}

proc ExpModTreeControl_isModuleFlowChanged { _expPath } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   global ${expChecksum}_FlowHasChanged

   set isChanged false
   if { [info exists ${expChecksum}_FlowHasChanged] } {
      set isChanged [set ${expChecksum}_FlowHasChanged]
   }
   return ${isChanged}
}

proc ExpModTreeControl_debugChanged { _expPath } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   global ${expChecksum}_DebugOn
   set isOn [set ${expChecksum}_DebugOn]
   if { ${isOn} == true } {
      ::log::lvSuppress debug 0
   } else {
      ::log::lvSuppress debug
   }
}