package require BWidget 1.9
package require cksum



proc ModuleFlowControl_configSelected { _expPath _flowNodeRecord } {
   # for now use flat modules
   # the naming of the _flowNodeRecord contains the path of the node
   # within the whole experiment
   # but for now, we need to get the relative path since we use
   # flat modules instead of exp tree
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   if { [${_flowNodeRecord} cget -type] == "ModuleNode" } {
      #set moduleNode ${_expPath}/modules/[${_flowNodeRecord} cget -name]
      set moduleNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   } else {
      # get the parent module
      set moduleNodeRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
      set moduleNode [ModuleFlow_record2NodeName ${moduleNodeRecord}]
   }
   set nodeType [${_flowNodeRecord} cget -type]

   if { [${_flowNodeRecord} cget -status] == "new" } {
      # it's a new node not saved yet, edit the file from working dir
      set configFile [ModuleLayout_getNodeConfigPath ${_expPath} ${moduleNode} ${flowNode} ${nodeType} true]
   } else {
      # get the relative path within the module container
      set configFile [ModuleLayout_getNodeConfigPath ${_expPath} ${moduleNode} ${flowNode} ${nodeType}]
   }

   puts "ModuleFlowControl_configSelected configFile:${configFile}"

   if { ! [file readable ${configFile}] } {
      MaestroConsole_addWarningMsg "file ${configFile} does not exists."
   }
   ModuleFlowView_goEditor ${configFile}
}

proc ModuleFlowControl_sourceSelected { _expPath _flowNodeRecord } {

   # for now use flat modules
   # the naming of the _flowNodeRecord contains the path of the node
   # within the whole experiment
   # but for now, we need to get the relative path since we use
   # flat modules instead of exp tree
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]

   # get the container module
   set moduleNodeRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleNode [ModuleFlow_record2NodeName ${moduleNodeRecord}]
   if { [${_flowNodeRecord} cget -status] == "new" } {
      # it's a new node not saved yet, edit the file from snapshot dir
      set sourceFile [ModuleLayout_getNodeSourcePath ${_expPath} ${moduleNode} ${flowNode} ${nodeType} true]
   } else {
      # get the relative path within the module container
      #set relativePath [::textutil::trim::trimPrefix ${_flowNodeRecord} ${moduleNodeRecord}]
      set sourceFile [ModuleLayout_getNodeSourcePath ${_expPath} ${moduleNode} ${flowNode} ${nodeType}]
   }

   puts "ModuleFlowControl_sourceSelected sourceFile:${sourceFile}"

   if { ! [file readable ${sourceFile}] } {
      MaestroConsole_addWarningMsg "file ${sourceFile} does not exists."
   }
   ModuleFlowView_goEditor ${sourceFile}
}

proc ModuleFlowControl_resourceSelected { _expPath _flowNodeRecord } {
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]

   # get the container module
   set moduleNodeRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleNode [ModuleFlow_record2NodeName ${moduleNodeRecord}]
   if { [${_flowNodeRecord} cget -status] == "new" } {
      # it's a new node not saved yet, edit the file from snapshot dir
      set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${moduleNode} ${flowNode} ${nodeType} true]
   } else {
      set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${moduleNode} ${flowNode} ${nodeType}]
   }

   puts "ModuleFlowControl_resourceSelected resourceFile:${resourceFile}"

   if { ! [file readable ${resourceFile}] } {
      MaestroConsole_addWarningMsg "file ${resourceFile} does not exists."
   }
   ModuleFlowView_goEditor ${resourceFile}
}

proc ModuleFlowControl_addNodeOk { _topWidget _expPath _moduleNode _parentFlowNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   puts "ModuleFlowControl_addNodeOk ${_expPath} _moduleNode:${_moduleNode} _parentFlowNode:${_parentFlowNode}"
   global errorInfo Link_Module_${moduleId}
   # get entry values
   set positionSpinW [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} addnode_pos_spinbox]
   set insertPosition [${positionSpinW} get]
   set typeOption [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_type_option] 
   set nodeType [${typeOption} cget -text]
   set nameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_name_entry]
   set nodeName [${nameEntry} get]

   set modulePath ""
   set useModuleLink false

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

   if { ${nodeType} == "ModuleNode" } {
      set modPathEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} addnode_ref_entry]
      set modulePath [${modPathEntry} cget -text]
      if { ${modulePath} != "" && ! [file exists ${modulePath}/flow.xml] } {
         MessageDlg .msg_window -icon error -message "Invalid module path: ${modulePath}. Module flow.xml not found." \
            -aspect 400 -title "Module selection error" -type ok -justify center -parent ${_topWidget}
         return
      }

      catch { set useModuleLink [set Link_Module_${moduleId}] }

      if { [ catch { ExpLayout_checkModPathExists ${_expPath} ${_parentFlowNode}/${nodeName} ${modulePath} ${useModuleLink} } errMsg] } {
            MessageDlg .msg_window -icon error -message "The new module path already exists!" \
               -title "Add New Node Error" -type ok -justify center -parent ${_topWidget}
            return
      }
   }

   if { [ catch { ModuleFlow_createNewNode ${_expPath} ${_parentFlowNode} ${nodeName} ${nodeType} ${insertPosition} ${modulePath} ${useModuleLink} } errMsg] } {
      MaestroConsole_addErrorMsg ${errMsg}
      if { ${errMsg} == "NodeDuplicate" } {
         MessageDlg .msg_window -icon error -message "A node with the same name already exists!" \
            -title "Add New Node Error" -type ok -justify center -parent ${_topWidget}
      } else {
         MessageDlg .msg_window -icon error -message $errMsg \
            -title "Add New Node Error" -type ok -justify center -parent ${_topWidget}
      }
      return
   }

   set modFlowTopWidget [ModuleFlowView_getTopLevel ${_expPath} ${_moduleNode}]
   # notify module tree of new module being added
   if { ${nodeType} == "ModuleNode" } {
      set newModuleNode [ModuleFlow_getNewNode ${_parentFlowNode} ${nodeName}]
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

proc ModuleFlowControl_renameNodeOk { _topWidget _expPath _moduleNode _flowNodeRecord {_allModules false} } {
   global ::errorInfo
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]

   puts "ModuleFlowControl_renameNodeOk ${_expPath} _moduleNode:${_moduleNode} _flowNodeRecord:${_flowNodeRecord} _allModules:${_allModules}"
   global Link_Module_${moduleId}
   # get entry values
   set nameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} rename_name_entry]
   set nodeName [${nameEntry} get]
   set newNameEntry [ModuleFlowView_getWidgetName ${_expPath} ${_moduleNode} rename_new_name_entry]
   set newNodeName [${newNameEntry} get]

   if { ${nodeType} == "ModuleNode" } {
      set modInstances [ExpModTree_getModInstances ${_expPath} ${flowNode}]
      set useCopy false
      puts "ModuleFlowControl_renameNodeOk modInstances:${modInstances} _allModules:${_allModules}"
      if { ${modInstances} > 1 && ${_allModules} == false } {
         # user wants to rename only selected module node... leave other module unaffected
         # copy the module instead of a move
         set useCopy true
         puts "ModuleFlowControl_renameNodeOk useCopy true"
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

proc ModuleFlowControl_deleteNodeSelected { _expPath _moduleNode _canvas _flowNodeRecord {_deleteBranch false} }  {
   global HighLightRestoreCmd
   # hightlight parent flow node
   set HighLightRestoreCmd ""
   if { ${_deleteBranch} == true } {
      ModuleFlowView_highLightBranch ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd
   } else {
      DrawUtil_highLightNode ${_flowNodeRecord} ${_canvas} HighLightRestoreCmd
   }

   set answer [MessageDlg .delete_window -icon question -message "Are you sure you want to delete selected node(s)?" \
      -title "Delete Node Confirmation" -type okcancel -justify center -parent ${_canvas} ]

   puts "ModuleFlowControl_deleteNodeSelected answer:${answer}"

   ModuleFlowView_checkReadOnlyNotify ${_expPath} ${_moduleNode}

   # clears the highlighted node
   DrawUtil_resetHighLightNode ${HighLightRestoreCmd}

   if { ${answer} == 0 } {
      if { [${_flowNodeRecord} cget -type] == "ModuleNode" } {
         set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
         # if the node to be deleted is a module, we delete everything to the right
         ModuleFlow_deleteNode ${_expPath} ${_flowNodeRecord} ${_flowNodeRecord} true

         # see if we need to delete the module directory as well
         set refCount [ExpModTree_getModInstances ${_expPath} ${flowNode}]
         if { ${refCount} == 1 } {
            set modulePath [ExpLayout_getModulePath ${_expPath} ${flowNode}]
            set answer [MessageDlg .delete_window -icon question -aspect 400 \
               -message "The [file tail ${flowNode}] module is not being used anymore, do you want to delete the module from \$SEQ_EXP_HOME/modules directory as well?" \
               -title "Delete Module Confirmation" -type yesno -justify center -parent ${_canvas} ]
            if { ${answer} == 0 } {
               # register module deletion
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

      ModuleFlowView_setStatusMsg [winfo toplevel ${_canvas}] "[ModuleFlow_record2NodeName ${_flowNodeRecord}] node deleted."
   }
}

proc ModuleFlowControl_cancelWrite { _expPath _moduleNode _failedOp _sourceW } {
   MessageDlg .msg_window -icon error -message "An error happend during the ${_failedOp}. Check the maestro console for more details. Operation cancelled." \
      -title "Failed Operation" -type ok -justify center -parent ${_sourceW}

   # clear module working dir
   ModuleLayout_clearWorkingDir ${_expPath} ${_moduleNode}
   ModuleFlow_setModuleChanged ${_expPath} ${_moduleNode} false
   ModuleFlowControl_refreshSelected ${_expPath} ${_moduleNode} ${_sourceW}
}

proc ModuleFlowControl_saveSelected { _expPath _moduleNode _topWidget } {
   # the flow xml must be saved in the module work dir
   set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
   set moduleFlowXml ${modWorkDir}/flow.xml

   if { [ catch { 
      # save flow xml file
      ModuleFlow_saveXml ${moduleFlowXml} [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   } errMsg] } {
      MaestroConsole_addErrorMsg ${errMsg}
      ModuleFlowControl_cancelWrite ${_expPath} ${_moduleNode} "module save flow.xml" ${_topWidget}
      return
   }

   if { [ catch { 
      # any unused module to be deleted?
      ModuleFlowControl_goPostSaveCmd ${_expPath} ${_moduleNode}

      # save module container directory
      ModuleLayout_saveWorkingDir ${_expPath} ${_moduleNode}
   } errMsg] } {
      MaestroConsole_addErrorMsg ${errMsg}
      ModuleFlowControl_cancelWrite ${_expPath} ${_moduleNode} "module directory save" ${_topWidget}
      return
   }

   # clear module working dir
   ModuleLayout_clearWorkingDir ${_expPath} ${_moduleNode}

   # reset module change status
   ModuleFlow_setModuleChanged ${_expPath} ${_moduleNode} false

   # change exp status to changed
   ExpModTreeControl_setModuleFlowChanged ${_expPath} true

   ModuleFlowControl_refreshSelected ${_expPath} ${_moduleNode} ${_topWidget}
   ModuleFlowView_setStatusMsg ${_topWidget} "Module ${_moduleNode} saved."
}

proc ModuleFlowControl_refreshSelected { _expPath _moduleNode _topWidget } {
   puts "ModuleFlowControl_refreshSelected _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set modNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   set parentNodeRecord [ModuleFlow_getParentContainer ${modNodeRecord}]

   if { [ModuleFlow_isModuleChanged ${_expPath} ${_moduleNode}] == false || 
        [ModuleFlowView_flowChangeNotify ${_expPath} ${_moduleNode} ${_topWidget}] == true  } {
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
}

proc ModuleFlowControl_copyLocalSelected { _expPath _moduleNode } {
   puts "ModuleFlowControl_copyLocalSelected _expPath:${_expPath} _moduleNode:${_moduleNode}"
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

   global gPostSave_${moduleId}
   puts "ModuleFlowControl_addPostSaveCmd _expPath:${_expPath} _moduleNode:${_moduleNode} gPostSave_${moduleId}"
   lappend gPostSave_${moduleId} ${_cmdArgs} 
}

# Go on and process any operations that were postponed. this is called at flow save time.
proc ModuleFlowControl_goPostSaveCmd { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   puts "ModuleFlowControl_goPostSaveCmd _expPath:${_expPath} _moduleNode:${_moduleNode}"
   global gPostSave_${moduleId}
   if { [info exists gPostSave_${moduleId}] } {
      foreach cmd [set gPostSave_${moduleId}] {
         catch {
            puts "ModuleFlowControl_goPostSaveCmd cmd:${cmd}"
            eval ${cmd}
         }
      }
      ModuleFlowControl_clearPostSaveCmd ${_expPath} ${_moduleNode}
   }
}

# clears postponed cmds
proc ModuleFlowControl_clearPostSaveCmd { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global gPostSave_${moduleId}
   catch { unset gPostSave_${moduleId} }
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
   set defaultDepot /home/binops/afsi/sio/components/modules
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