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
package require cksum



proc ModuleFlowControl_configSelected { _expPath _flowNodeRecord } {
   ::log::log debug "ModuleFlowControl_configSelected _expPath:${_expPath} _flowNodeRecord:${_flowNodeRecord}"
   # for now use flat modules
   # the naming of the _flowNodeRecord contains the path of the node
   # within the whole experiment
   # but for now, we need to get the relative path since we use
   # flat modules instead of exp tree
   set flowNode [ModuleFlow_getLayoutNode ${_flowNodeRecord}] 
   if { [${_flowNodeRecord} cget -type] == "ModuleNode" } {
      set moduleLayoutNode [ModuleFlow_getLayoutNode ${_flowNodeRecord}] 
   } else {
      # get the parent module
      set moduleNodeRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
      set moduleLayoutNode [ModuleFlow_getLayoutNode ${moduleNodeRecord}] 
   }
   set nodeType [${_flowNodeRecord} cget -type]

   if { [${_flowNodeRecord} cget -status] == "new" } {
      # it's a new node not saved yet, edit the file from working dir
      set configFile [ModuleLayout_getNodeConfigPath ${_expPath} ${moduleLayoutNode} ${flowNode} ${nodeType} true]
   } else {
      # get the relative path within the module container
      set configFile [ModuleLayout_getNodeConfigPath ${_expPath} ${moduleLayoutNode} ${flowNode} ${nodeType}]
   }

   ::log::log debug "ModuleFlowControl_configSelected configFile:${configFile}"

   if { ! [file readable ${configFile}] } {
      MaestroConsole_addWarningMsg "file ${configFile} does not exists."
   }
   ModuleFlowView_goEditor ${configFile}
}

proc ModuleFlowControl_sourceSelected { _expPath _flowNodeRecord } {
   ::log::log debug "ModuleFlowControl_sourceSelected _expPath:${_expPath} _flowNodeRecord:${_flowNodeRecord}"

   # for now use flat modules
   # the naming of the _flowNodeRecord contains the path of the node
   # within the whole experiment
   # but for now, we need to get the relative path since we use
   # flat modules instead of exp tree
   set flowNode [ModuleFlow_getLayoutNode ${_flowNodeRecord}] 
   set nodeType [${_flowNodeRecord} cget -type]

   # get the container module
   set moduleNodeRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleNode [ModuleFlow_record2NodeName ${moduleNodeRecord}]
   set moduleLayoutNode [ModuleFlow_getLayoutNode ${moduleNodeRecord}] 
   if { [${_flowNodeRecord} cget -status] == "new" } {
      # it's a new node not saved yet, edit the file from snapshot dir
      set sourceFile [ModuleLayout_getNodeSourcePath ${_expPath} ${moduleLayoutNode} ${flowNode} ${nodeType} true]
   } else {
      # get the relative path within the module container
      #set relativePath [::textutil::trim::trimPrefix ${_flowNodeRecord} ${moduleNodeRecord}]
      set sourceFile [ModuleLayout_getNodeSourcePath ${_expPath} ${moduleLayoutNode} ${flowNode} ${nodeType}]
   }

   ::log::log debug "ModuleFlowControl_sourceSelected sourceFile:${sourceFile}"

   if { ! [file readable ${sourceFile}] } {
      MaestroConsole_addWarningMsg "file ${sourceFile} does not exists."
   }
   ModuleFlowView_goEditor ${sourceFile}
}

proc ModuleFlowControl_resourceSelected { _expPath _canvas _flowNodeRecord {goXml false} } {
   set flowNode [ModuleFlow_record2RealNode ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]

   if { [ModuleFlow_isExpRootNode ${_flowNodeRecord}] == true } {
      set moduleNode [${_flowNodeRecord} cget -flow_path]
   } else {
      if { ${nodeType} == "ModuleNode" } {
         set currentModule [file tail [ModuleFlowView_getModNode ${_canvas}]]
         if { [file tail ${_flowNodeRecord}] == ${currentModule} } {
            # module node is the current module being edited
            set moduleNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
         } else {
            set moduleNodeRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
            set moduleNode [ModuleFlow_record2NodeName ${moduleNodeRecord}]
         }
      } else {
         # get the container module
         set moduleNodeRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
         set moduleNode [ModuleFlow_record2NodeName ${moduleNodeRecord}]
      }
   }

   if { [${_flowNodeRecord} cget -status] == "new" } {
      # it's a new node not saved yet, edit the file from snapshot dir
      set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${moduleNode} ${flowNode} ${nodeType} true]
   } else {
      set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${moduleNode} ${flowNode} ${nodeType}]
   }

   ::log::log debug "ModuleFlowControl_resourceSelected resourceFile:${resourceFile}"

   if { ${goXml} == true } {
      ModuleFlowView_goEditor ${resourceFile}
   } else {
      ResourceControl_init ${_expPath} ${moduleNode} ${_flowNodeRecord}
   }
}

proc ModuleFlowControl_addNodeOk { _topWidget _expPath _moduleNode _parentFlowNodeRecord } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   ::log::log debug "ModuleFlowControl_addNodeOk ${_expPath} _moduleNode:${_moduleNode} _parentFlowNodeRecord:${_parentFlowNodeRecord}"
   global errorInfo ${moduleId}_Link_Module ${moduleId}_work_unit ${moduleId}_SwitchModeOption
   # get entry values
   set positionSpinW [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} addnode_pos_spinbox]
   set insertPosition [${positionSpinW} get]
   set typeOption [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_type_option] 
   set nodeType [${typeOption} cget -text]
   set nameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_name_entry]
   set nodeName [${nameEntry} get]

   if { ${nodeName} == "" } {
      MessageDlg .msg_window -icon error -message "The name field must be provided!" \
         -title "Add New Node Error" -type ok -justify center -parent ${nameEntry}
      return
   }

   if { ${insertPosition} == "serial" && ${nodeType} == "ModuleNode" } {
      MessageDlg .msg_window -icon error -message "Nodes of type ModuleNode cannot be added in serial position!" \
         -title "Add New Node Error" -type ok -justify center -parent ${_topWidget}
      return
   }

   set isWorkUnit [set ${moduleId}_work_unit]
   set extraArgList [list is_work_unit ${isWorkUnit}]

   # creating a module node, check if we need to use a link for the module or not
   switch ${nodeType} {
      ModuleNode {
         set modPathEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_entry]
         set modulePath [${modPathEntry} cget -text]
	 set derivedModulePath ""
	 if { [file pathtype ${modulePath}] == "relative" } {
            set derivedModulePath [file normalize ${modulePath}]
	 }

         if { ${derivedModulePath} != "" && ! [file exists ${derivedModulePath}/flow.xml] } {
            MessageDlg .msg_window -icon error -message "Invalid module path: ${modulePath}. Module flow.xml not found." \
               -aspect 400 -title "Module selection error" -type ok -justify center -parent ${_topWidget}
            return
         }

         catch { set useModuleLink [set ${moduleId}_Link_Module] }

         if { ${modulePath} != "" && [ExpLayout_isModPathExists ${_expPath} ${_parentFlowNodeRecord}/${nodeName} ${derivedModulePath} ${useModuleLink}] == true } {
            set answer [MessageDlg .msg_window -icon question -message "Module directory or link already exists. Do you want to reuse?" \
               -title "Add Module Node" -type okcancel -justify center -parent ${_topWidget} ]
            if { ${answer} == 1 } {
               # cancel and return to create window
               return
            }
         }

         lappend extraArgList use_mod_link ${useModuleLink} mod_path ${modulePath}
      }

      SwitchNode {
         set switchModeOption [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_switchmode_option] 
         set switchMode [${switchModeOption} cget -text]
         set switchItems [ModuleFlowView_getSwitchNodeItems ${_expPath} ${_moduleNode}]
         puts "ModuleFlowControl_addNodeOk switchItems:${switchItems}"
         if { ${insertPosition} == "serial" && ${switchItems} == "" } {
            MessageDlg .msg_window -icon error -message "In serial position, you must provide switch items!" \
               -title "Add New Node Error" -type ok -justify center -parent ${_topWidget}
            return
         }
         lappend extraArgList switch_mode ${switchMode}
         lappend extraArgList switch_items ${switchItems}
      }
   }
 
   if { [ catch { ModuleFlow_createNewNode ${_expPath} ${_parentFlowNodeRecord} ${nodeName} ${nodeType} ${insertPosition} ${extraArgList} } errMsg] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
      if { ${errMsg} == "NodeDuplicate" } {
         MessageDlg .msg_window -icon error -message "A node with the same name already exists!" \
            -title "Add New Node Error" -type ok -justify center -parent ${_topWidget}
      } else {
         MessageDlg .msg_window -icon error -message "${errMsg}. See Console Window fore more details." \
            -title "Add New Node Error" -type ok -justify center -parent ${_topWidget}
         MaestroConsole_show
      }
      return
   }

   set modFlowTopWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
   # notify module tree of new module being added
   if { ${nodeType} == "ModuleNode" } {
      set newModuleNode [ModuleFlow_getNewNode ${_parentFlowNodeRecord} ${nodeName}]
      ExpModTreeControl_moduleAdded ${_expPath} ${_moduleNode} ${newModuleNode}
   }

   # refresh module flow
   ModuleFlowView_draw ${_expPath} ${_moduleNode}
   
   # send msg in status bar
   ModuleFlowView_setStatusMsg ${modFlowTopWidget} "New ${nodeType} ${nodeName} added."

   # enable save
   ModuleFlowView_saveStatus ${_expPath} ${_moduleNode} normal

   # destroy source window
   after idle destroy ${_topWidget}
}

proc ModuleFlowControl_editNodeOk { _topWidget _expPath _moduleNode _flowNodeRecord } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   ::log::log debug "ModuleFlowControl_editNodeOk ${_expPath} _moduleNode:${_moduleNode} _flowNodeRecord:${_flowNodeRecord}"
   global errorInfo
   set nodeType [${_flowNodeRecord} cget -type]
   switch ${nodeType} {
      "SwitchNode" {
         set switchItems [ModuleFlowView_getSwitchNodeItems ${_expPath} ${_moduleNode}]
         ${_flowNodeRecord} configure -switch_items ${switchItems}
         foreach switchItem ${switchItems} {
            ModuleFlow_addNewSwitchItem ${_flowNodeRecord} ${switchItem}
         }
         if { [${_flowNodeRecord} cget -curselection] == "" && ${switchItems} != "" } {
            ${_flowNodeRecord} configure -curselection [lindex ${switchItems} 0]
         }
      }
      default {
      }
   }
 
   # refresh module flow
   ModuleFlowView_draw ${_expPath} ${_moduleNode}
   
   set modFlowTopWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]

   # send msg in status bar
   ModuleFlowView_setStatusMsg ${modFlowTopWidget} "Edit ${nodeType} [file tail ${_flowNodeRecord}] done."

   # enable save
   ModuleFlowView_saveStatus ${_expPath} ${_moduleNode} normal

   # destroy source window
   after idle destroy ${_topWidget}
}

proc ModuleFlowControl_renameNodeOk { _topWidget _expPath _moduleNode _flowNodeRecord {_allModules false} } {
   global ::errorInfo
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]

   ::log::log debug "ModuleFlowControl_renameNodeOk ${_expPath} _moduleNode:${_moduleNode} _flowNodeRecord:${_flowNodeRecord} _allModules:${_allModules}"
   global ${moduleId}_Link_Module
   # get entry values
   set nameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} rename_name_entry]
   set nodeName [${nameEntry} get]
   set newNameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} rename_new_name_entry]
   set newNodeName [${newNameEntry} get]

   if { ${nodeType} == "ModuleNode" } {
      set modInstances [ExpModTree_getModInstances ${_expPath} ${flowNode}]
      set useCopy false
      ::log::log debug "ModuleFlowControl_renameNodeOk modInstances:${modInstances} _allModules:${_allModules}"
      if { ${modInstances} > 1 && ${_allModules} == false } {
         # user wants to rename only selected module node... leave other module unaffected
         # copy the module instead of a move
         set useCopy true
         ::log::log debug "ModuleFlowControl_renameNodeOk useCopy true"
      }
      # rename of module's dir is only done at save
      ModuleFlowControl_addPostSaveCmd ${_expPath} ${_moduleNode} \
         [list ModuleLayout_renameModule ${_expPath} ${flowNode} ${newNodeName} ${useCopy}]

      # save flow xml file of referenced node at save time
      # note: this is temporary... we should remove the name attribute of the module node tag
      # from the module flow.xml
      set newModuleNode [file dirname ${flowNode}]/${newNodeName}
      set moduleFlowXml [ModuleLayout_getFlowXml ${_expPath} ${newModuleNode}]
      ModuleFlowControl_addPostSaveCmd ${_expPath} ${_moduleNode} \
         [list ModuleFlow_saveXml ${moduleFlowXml} [ModuleFlow_getRecordName ${_expPath} ${newModuleNode}]]
   }

   if { ${newNodeName} == "" } {
      MessageDlg .msg_window -icon error -message "The new name field must be provided!" \
         -title "Rename New Node Error" -type ok -justify center -parent ${newNameEntry}
      return
   }

   if { [ catch { ModuleFlow_renameNode ${_expPath} ${_flowNodeRecord} ${newNodeName} } errMsg] } {
      if { ${errMsg} == "NodeDuplicate" } {
         MessageDlg .msg_window -icon error -message "A node with the same name already exists!" \
            -title "Rename New Node Error" -type ok -justify center -parent ${_topWidget}
      } elseif { ${errMsg} == "ModulePathExists" } {
         MessageDlg .msg_window -icon error -message "The new module path already exists!" \
            -title "Rename New Node Error" -type ok -justify center -parent ${_topWidget}
      } else {
         MessageDlg .msg_window -icon error -message $errMsg \
            -title "Rename New Node Error" -type ok -justify center -parent ${_topWidget}
         if { ${::errorInfo} != "" } {
            MaestroConsole_addErrorMsg ${::errorInfo}
         } else {
            MaestroConsole_addErrorMsg ${errMsg}
         }
      }
      return
   }

   # rename last node listing at save time
   ModuleFlowControl_addPostSaveCmd ${_expPath} ${_moduleNode} \
      [list ExpLayout_renameListing ${_expPath} ${flowNode} ${newNodeName}]
   
   set modFlowTopWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]

   # refresh module flow
   ModuleFlowView_draw ${_expPath} ${_moduleNode}
   
   # send msg in status bar
   ModuleFlowView_setStatusMsg ${modFlowTopWidget} "${nodeName} renamed to ${newNodeName}."

   # enable save
   ModuleFlowView_saveStatus ${_expPath} ${_moduleNode} normal

   # destroy source window
   after idle destroy ${_topWidget}
}

# _deleteBranch can have the following values:
#               - true: for a non-switching node, deletes the whole branch to the right of the node
#               - false: only delete current node
#               - ${switch_item_branch}: for switching node, deletes the selected branch
proc ModuleFlowControl_deleteNodeSelected { _expPath _moduleNode _canvas _flowNodeRecord {_deleteBranch false} }  {
   ::log::log debug "ModuleFlowControl_deleteNodeSelected _flowNodeRecord:${_flowNodeRecord} _deleteBranch:${_deleteBranch}"
   global HighLightRestoreCmd
   # hightlight parent flow node
   set HighLightRestoreCmd ""

   if { [ModuleFlowView_multiEditNotify ${_expPath} ${_moduleNode} ${_canvas}] == false } {
      return
   }

   if { [ModuleFlowView_outsideModRefNotify ${_expPath} ${_moduleNode} ${_canvas}] == false } {
      return
   }

   if { [ catch { 
      MiscTkUtils_busyCursor [winfo toplevel ${_canvas}]

   if { ${_deleteBranch} != false } {
      ModuleFlowView_highLightBranch ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd
   } else {
      DrawUtil_highLightNode ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd
   }

   switch ${_deleteBranch} {
      true {
         set titleValue "Delete Branch Confirmation"
      }
      false {
         set titleValue "Delete Node Confirmation"
      }
      default {
         set titleValue "Delete Switch Branch Confirmation"
      }
   }

   set answer [MessageDlg .delete_window -icon question -message "Are you sure you want to delete selected node(s)?" \
      -title ${titleValue} -type okcancel -justify center -parent ${_canvas} ]

   ::log::log debug "ModuleFlowControl_deleteNodeSelected answer:${answer}"

   # clears the highlighted node
   DrawUtil_resetHighLightNode ${HighLightRestoreCmd}

   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]

   if { ${answer} == 0 } {
      if { [${_flowNodeRecord} cget -type] == "ModuleNode" } {
         # if the node to be deleted is a module, we delete everything to the right
         ModuleFlow_deleteNode ${_expPath} ${_flowNodeRecord} ${_flowNodeRecord} true

         # see if we need to delete the module directory as well
         set refCount [ExpModTree_getModInstances ${_expPath} ${flowNode}]
         if { ${refCount} == 1 } {
            set modulePath [ExpLayout_getModulePath ${_expPath} ${flowNode}]
            set answer [MessageDlg .delete_window -icon question -aspect 400 \
               -message "The [file tail ${flowNode}] module is not being used anymore, do you want to delete the module from \$SEQ_EXP_HOME/modules directory as well?" \
               -title "Delete Module Confirmation" -type yesno -justify center -parent ${_canvas} ]
            ::log::log debug "ModuleFlowControl_deleteNodeSelected the directory as well answer:${answer}"
            if { ${answer} == 0 } {
               # register module deletion
               ::log::log debug "ModuleFlowControl_deleteNodeSelected ModuleFlowControl_addPostSaveCmd ModuleLayout_deleteModule ${_expPath} ${_moduleNode} ${flowNode}"
               ModuleFlowControl_addPostSaveCmd ${_expPath} ${_moduleNode} \
                  [list ModuleLayout_deleteModule ${_expPath} ${_moduleNode} ${flowNode}]
            }
         }

         # notify exp flow that a module has been deleted
         ExpModTreeControl_moduleDeleted ${_expPath} ${flowNode}
      } else {
         set deletedModNodes ""
         set deletedModNodes [ModuleFLow_getChildModuleNodes ${_flowNodeRecord} ${deletedModNodes}]
         ModuleFlow_deleteNode ${_expPath} ${_flowNodeRecord} ${_flowNodeRecord} ${_deleteBranch}
         foreach deletedMod ${deletedModNodes} {
            # notify exp flow that a module has been deleted
            ExpModTreeControl_moduleDeleted ${_expPath} ${deletedMod}
         }
      }

      # refresh module flow
      ModuleFlowView_draw ${_expPath} ${_moduleNode}

      # enable save
      ModuleFlowView_saveStatus ${_expPath} ${_moduleNode} normal

      ModuleFlowView_setStatusMsg [winfo toplevel ${_canvas}] "${flowNode} node deleted."
   }

   } errMsg] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
   }
   MiscTkUtils_normalCursor [winfo toplevel ${_canvas}]
}

proc ModuleFlowControl_cancelWrite { _expPath _moduleNode _failedOp _sourceW } {
   MessageDlg .msg_window -icon error -message "An error happend during the ${_failedOp}. Check the maestro console for more details. Operation cancelled." \
      -title "Failed Operation" -type ok -justify center -parent ${_sourceW}

   MaestroConsole_show
   # clear module working dir
   ModuleLayout_clearWorkingDir ${_expPath} ${_moduleNode}
   ModuleFlow_setModuleChanged ${_expPath} ${_moduleNode} false
   ModuleFlowControl_refreshSelected ${_expPath} ${_moduleNode} ${_sourceW}
}

proc ModuleFlowControl_saveSelected { _expPath _moduleNode _topWidget } {
   ::log::log debug "ModuleFlowControl_saveSelected _expPath:${_expPath} _moduleNode:${_moduleNode}"
   if { [ModuleFlowControl_validateModuleNode ${_expPath} ${_moduleNode} ${_topWidget}] == false } {
      return
   }

   set moduleNodeRecord  [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   set moduleLayoutNode [ModuleFlow_getLayoutNode ${moduleNodeRecord}] 

   # the flow xml must be saved in the module work dir
   set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${moduleLayoutNode}]
   set moduleFlowXml ${modWorkDir}/flow.xml

   if { [ catch { 
      # save flow xml file
      ModuleFlow_saveXml ${moduleFlowXml} ${moduleNodeRecord}
   } errMsg] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
      ModuleFlowControl_cancelWrite ${_expPath} ${_moduleNode} "module save flow.xml" ${_topWidget}
      return
   }

   if { [ catch { 
      # any unused module to be deleted?
      ModuleFlowControl_goPostSaveCmd ${_expPath} ${_moduleNode}

      # save module container directory
      ModuleLayout_saveWorkingDir ${_expPath} ${moduleLayoutNode}
   } errMsg] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
      ModuleFlowControl_cancelWrite ${_expPath} ${_moduleNode} "module directory save" ${_topWidget}
      return
   }

   if { [ catch { 

      MiscTkUtils_busyCursor ${_topWidget}
      # clear module working dir
      ModuleLayout_clearWorkingDir ${_expPath} ${moduleLayoutNode}

      # reset module change status
      ModuleFlow_setModuleChanged ${_expPath} ${_moduleNode} false

      # change exp status to changed
      ExpModTreeControl_setModuleFlowChanged ${_expPath} true

      ModuleFlowControl_refreshSelected ${_expPath} ${_moduleNode} ${_topWidget}
      ModuleFlowView_setStatusMsg ${_topWidget} "Module ${_moduleNode} saved."

   } errMsg] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
   }

   MiscTkUtils_normalCursor ${_topWidget}
}

proc ModuleFlowControl_refreshSelected { _expPath _moduleNode _topWidget } {
   ::log::log debug "ModuleFlowControl_refreshSelected _expPath:${_expPath} _moduleNode:${_moduleNode}"
   if { [ModuleFlowControl_validateModuleNode ${_expPath} ${_moduleNode} ${_topWidget}] == false } {
      return
   }
   # update idletasks
   set modNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   set parentNodeRecord [ModuleFlow_getContainer ${modNodeRecord}]


   if { [ catch { 

      MiscTkUtils_busyCursor ${_topWidget}

      if { [ModuleFlow_isModuleChanged ${_expPath} ${_moduleNode}] == false || 
        [ModuleFlowView_flowChangeNotify ${_expPath} ${_moduleNode} ${_topWidget}] == true  } {

         ModuleFlowView_clearStatusMsg ${_topWidget}

         # clear module working dir
         ModuleLayout_clearWorkingDir ${_expPath} ${_moduleNode}

         # clears current node records and reread module flow.xml
         ModuleFlow_refresh ${_expPath} ${_moduleNode}

         # redraw flow
         ModuleFlowView_draw ${_expPath} ${_moduleNode}

         # reset save
         ModuleFlowView_saveStatus ${_expPath} ${_moduleNode} disabled

         # redraw exp tree from
         ExpModTreeControl_redraw ${_expPath}

         ModuleFlowControl_clearPostSaveCmd ${_expPath} ${_moduleNode}

         ModuleFlow_setModuleChanged ${_expPath} ${_moduleNode} false
      }

   } errMsg] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
   }

   MiscTkUtils_normalCursor ${_topWidget}
}

proc ModuleFlowControl_copyLocalSelected { _expPath _moduleNode } {
   ::log::log debug "ModuleFlowControl_copyLocalSelected _expPath:${_expPath} _moduleNode:${_moduleNode}"
   # first delete module link
   if { [ExpLayout_isModuleLink ${_expPath} ${_moduleNode}] == true } {
      ExpLayout_copyModule ${_expPath} ${_moduleNode}
   }
}

# this is mainly used to postpone the creation, deletion, renaming of modules
# under the directory $SEQ_EXP_HOME/modules until the user actually saves
# the flow. If the user decides to not save the flow and cancel the
# operation, there is no impact on the modules directory structure since
# it was has not been touched until the save is done.
proc ModuleFlowControl_addPostSaveCmd { _expPath _moduleNode _cmdArgs } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   global ${moduleId}_gPostSave
   ::log::log debug "ModuleFlowControl_addPostSaveCmd _expPath:${_expPath} _moduleNode:${_moduleNode} ${moduleId}_gPostSave"
   lappend ${moduleId}_gPostSave ${_cmdArgs} 
}

# Go on and process any operations that were postponed. this is called at flow save time.
proc ModuleFlowControl_goPostSaveCmd { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   ::log::log debug "ModuleFlowControl_goPostSaveCmd _expPath:${_expPath} _moduleNode:${_moduleNode}"
   global ${moduleId}_gPostSave
   if { [info exists ${moduleId}_gPostSave] } {
      foreach cmd [set ${moduleId}_gPostSave] {
         catch {
            ::log::log debug "ModuleFlowControl_goPostSaveCmd cmd:${cmd}"
            eval ${cmd}
         }
      }
      ModuleFlowControl_clearPostSaveCmd ${_expPath} ${_moduleNode}
   }
}

# clears postponed cmds
proc ModuleFlowControl_clearPostSaveCmd { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_gPostSave
   catch { unset ${moduleId}_gPostSave }
}

# reads user defined configuration (mc_mod_depot)
# for modules depot location and fetches the modules
# found in that depot...
# any directory containing a flow.xml file will be collected
# as a module
#
# returns a list containing the path of each module
#
proc ModuleFlowControl_getDepotModules {} {
   set modules {}
   set modDepotConfig [ModuleFlowControl_getModDefaultDepot]
   if [ catch {
      if { ${modDepotConfig} != "" } {
         set modDepots [split ${modDepotConfig} :]
         foreach modDepot ${modDepots} {
            MaestroConsole_addMsg "Locating modules from ${modDepot}..."
            set moduleDirs [exec find ${modDepot} -name flow.xml]
            foreach moduleDir ${moduleDirs} {
               lappend modules [file dirname ${moduleDir}]
            }
         }
      }
   } errMsg ] {
      MaestroConsole_addErrorMsg ${errMsg}
   }
   
   return [lsort -ascii -unique ${modules}]
}

# returns the first value found from configuration mc_mod_depot
# or ~afsisio/components/modules if not found
proc ModuleFlowControl_getModDefaultDepot {} {
   global DefaultModDepotVar
   set defaultDepot ""
   if { [info exists DefaultModDepotVar] } {
      set defaultDepot ${DefaultModDepotVar}
   }
   set modDepotConfig [SharedData_getMiscData MC_MOD_DEPOT]
   if [ catch {
      if { ${modDepotConfig} != "" } {
         set modDepots [split ${modDepotConfig} :]
         set defaultDepot [lindex ${modDepots} 0]
      }
   } errMsg ] {
      MaestroConsole_addErrorMsg ${errMsg}
   }
   return ${defaultDepot}
}

proc ModuleFlowControl_validateModuleNode { _expPath _moduleNode { _sourceWidget ""} } {
   set modNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   if { ! [record exists instance ${modNodeRecord}] } {
      MessageDlg .msg_window -icon error -message "The module node does not exists! The module window should be closed." -aspect 400 \
         -title "Flow Manager Error" -type ok -justify center -parent ${_sourceWidget}
      return false
   }

   return true
}
