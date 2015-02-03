proc ResourceControl_init { _expPath _moduleNode _flowNodeRecord } {
   ResourceView_createWidgets ${_expPath} ${_moduleNode} ${_flowNodeRecord}
   ResourceControl_retrieveData ${_expPath} ${_moduleNode} ${_flowNodeRecord}
}

proc ResourceControl_retrieveData { _expPath _moduleNode _flowNodeRecord {refresh false} } {
   ::log::log debug "ResourceControl_retrieveData ${_expPath} ${_moduleNode} ${_flowNodeRecord}"
   set flowNode [${_flowNodeRecord} cget -flow_path]
   set nodeType [${_flowNodeRecord} cget -type]

   if { [${_flowNodeRecord} cget -status] == "new" } {
      # it's a new node not saved yet, edit the file from snapshot dir
      set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${_moduleNode} [ModuleFlow_record2RealNode ${_flowNodeRecord}] ${nodeType} true]
   } else {
      set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${_moduleNode} [ModuleFlow_record2RealNode ${_flowNodeRecord}] ${nodeType}]
   }
   ::log::log debug "ResourceControl_retrieveData ${_expPath} ${_moduleNode} ${_flowNodeRecord} looking for resource file:${resourceFile}"

   if { [file readable ${resourceFile}] } {
      set resourceXmlDoc [ResourceXml_parseFile ${resourceFile}]
   } else {
      set resourceXmlDoc [ResourceXml_createDocument]
   }


   ResourceControl_retrieveBatchData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc}
   ResourceControl_retrieveDepData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc} ${refresh}
   ResourceControl_retrieveActionData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc}

   if { [${_flowNodeRecord} cget -type] == "LoopNode" } {
      ResourceControl_retrieveLoopData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc}
   }

   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]
   ResourceView_setDataChanged ${topWidget} false

   if { [file writable [file dirname ${resourceFile}]] } {
      ResourceView_invokeStateChangeWidgets ${topWidget} normal
   } else {
      ResourceView_invokeStateChangeWidgets ${topWidget} disabled
   }
}

proc ResourceControl_retrieveBatchData { _expPath _moduleNode _flowNode _resourceXmlDoc } {
   set batchFrameWidget [ResourceView_getBatchFrameWidget ${_expPath} ${_moduleNode} ${_flowNode}]
   foreach resAttribute { machine queue cpu cpu_multiplier memory wallclock catchup mpi soumet_args} {
      set savedValue [ResourceXml_getBatchAttribute ${_resourceXmlDoc} ${resAttribute}]
      set attributeVariable [ResourceView_getAttrVariable ${batchFrameWidget} ${resAttribute}]
      global ${attributeVariable}
      ::log::log debug "ResourceControl_retrieveBatchData set ${attributeVariable} ${savedValue}"
      set ${attributeVariable} ${savedValue}

      set procName "ResourceView_addEntry[string toupper ${resAttribute}]"
      ::log::log debug "ResourceControl_retrieveBatchData ${procName} 0 \"${savedValue}\""
      # some attributes require special conversion from the xml to the GUI
      if { [info procs ${procName}] != "" } {
         ${procName} ${batchFrameWidget} 0 ${savedValue}
      }
   }
}

proc ResourceControl_retrieveActionData { _expPath _moduleNode _flowNode _resourceXmlDoc } {
   set abortActionValue [ResourceXml_getAbortActionValue ${_resourceXmlDoc}]
   set actionFrameWidget [ResourceView_getAbortActionFrameWidget ${_expPath} ${_moduleNode} ${_flowNode}]
   ResourceView_setAbortActionValue ${actionFrameWidget} ${abortActionValue}
}

proc ResourceControl_retrieveDepData { _expPath _moduleNode _flowNode _resourceXmlDoc {refresh false} } {
   ::log::log debug "ResourceControl_retrieveDepData $_expPath $_moduleNode $_flowNode"
   set flowNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_flowNode}]

   set depFrame [ResourceView_getDependsFrameWidget ${_expPath} ${_moduleNode} ${_flowNode}]
   set tableVar [ResourceView_getDepResourceTableVar ${depFrame}]
   global ${tableVar}

   # $tableVar is the variable that holds the values for the dependency table
   # get the dependency info from the resource xml file
   set ${tableVar} [ResourceXml_getDependencyList ${_resourceXmlDoc}]

   # get the dependency info from the module flow.xml file
   set moduleNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   set flowXmlFile [ModuleLayout_getFlowXml ${_expPath} ${_moduleNode}]
   set xmlDoc [ResourceXml_parseFile ${flowXmlFile}]

   set nodeTableVar [ResourceView_getDepNodeTableVar ${depFrame}]
   global ${nodeTableVar}
   # the dependencies have been read once already when the module flow was read...
   # however, in the case of a refresh we want to fetch again from the flow.xml
   if { ${refresh} == false || [${flowNodeRecord} cget -status] == "new" } {
      set ${nodeTableVar} [${flowNodeRecord} cget -deps]
   } else {
      set ${nodeTableVar} [ModuleFlowXml_getDependencies ${xmlDoc} ${moduleNodeRecord} ${flowNodeRecord}]
   }

   # change the look of the default entry widgets to more specialised widgets for specific columns
   ResourceView_updateDepTableWidgets ${_expPath} ${_moduleNode} ${_flowNode}

   if { [file writable ${flowXmlFile}] } { 
      ResourceView_updateNodeDependenciesWidgetState ${depFrame} normal
   } else {
      ResourceView_updateNodeDependenciesWidgetState ${depFrame} disabled
   }
}

proc ResourceControl_retrieveLoopData { _expPath _moduleNode _flowNode _resourceXmlDoc} {
   ::log::log debug "ResourceControl_retrieveLoopData $_expPath $_moduleNode $_flowNode $_resourceXmlDoc"

   set loopFrame [ResourceView_getLoopFrameWidget  ${_expPath} ${_moduleNode} ${_flowNode}]

   # get the global variables for each loop parameter
   set loopStartVar [ResourceView_getAttrVariable ${loopFrame} loopstart]
   set loopEndVar [ResourceView_getAttrVariable ${loopFrame} loopend]
   set loopStepVar [ResourceView_getAttrVariable ${loopFrame} loopstep]
   set loopSetVar [ResourceView_getAttrVariable ${loopFrame} loopset]
   global ${loopStartVar} ${loopEndVar} ${loopStepVar} ${loopSetVar}

   # set the variables for the loop parameters, automatically updates the GUI entries
   set ${loopStartVar} [ResourceXml_getLoopAttribute ${_resourceXmlDoc} start]
   set ${loopEndVar} [ResourceXml_getLoopAttribute ${_resourceXmlDoc} end]
   set ${loopStepVar} [ResourceXml_getLoopAttribute ${_resourceXmlDoc} step]
   set ${loopSetVar} [ResourceXml_getLoopAttribute ${_resourceXmlDoc} set]
}

proc ResourceControl_saveBatchData { _expPath _moduleNode _flowNode _resourceXmlDoc} {
   ::log::log debug "ResourceControl_saveBatchData $_expPath $_moduleNode $_flowNode"

   set batchFrameWidget [ResourceView_getBatchFrameWidget ${_expPath} ${_moduleNode} ${_flowNode}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} queue [ResourceView_getEntryQUEUE ${batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} machine [ResourceView_getEntryMACHINE ${batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} cpu [ResourceView_getEntryCPU ${batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} cpu_multiplier [ResourceView_getEntryCPU_MULTIPLIER ${batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} memory [ResourceView_getEntryMEMORY ${batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} wallclock [ResourceView_getEntryWALLCLOCK ${batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} catchup [ResourceView_getEntryCATCHUP ${batchFrameWidget} true]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} mpi [ResourceView_getEntryMPI ${batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} soumet_args [ResourceView_getEntrySOUMET_ARGS ${batchFrameWidget}]
}

proc ResourceControl_saveActionData { _expPath _moduleNode _flowNode _resourceXmlDoc} {
   ::log::log debug "ResourceControl_saveActionData $_expPath $_moduleNode $_flowNode"
   set actionFrameWidget [ResourceView_getAbortActionFrameWidget ${_expPath} ${_moduleNode} ${_flowNode}]
   set value [ResourceView_getAbortActionValue ${actionFrameWidget}]
   ResourceXml_setAbortActionValue ${_resourceXmlDoc} ${value}
   
}

proc ResourceControl_saveDepsData { _expPath _moduleNode _flowNode _resourceXmlDoc} {
   ::log::log debug "ResourceControl_saveDepsData $_expPath $_moduleNode $_flowNode"

   set depFrame [ResourceView_getDependsFrameWidget ${_expPath} ${_moduleNode} ${_flowNode}]
   set tableVar [ResourceView_getDepResourceTableVar ${depFrame}]
   global ${tableVar}

   ::log::log debug "ResourceControl_saveDepsData tableVar:${tableVar}"
   ::log::log debug "ResourceControl_saveDepsData [set ${tableVar}]"
   # handle resource dependencies
   # saves value to resource.xml
   set errorMsg ""
   if { [ResourceControl_validateDepsData ${tableVar} errorMsg] == false } {
      error "Error saving dependency entries for resource.xml. ${errorMsg}"
      return
   }
   # remove duplicate entries
   set depEntries [lsort -unique [set ${tableVar}] ]
   foreach depEntry ${depEntries} {
      ::log::log debug "depEntry:${depEntry}"
      set nameValueList [ list type node \
                               dep_name [lindex ${depEntry} 0] \
                               status [lindex ${depEntry} 1] \
                               index [lindex ${depEntry} 2] \
                               local_index [lindex ${depEntry} 3] \
                               hour [lindex ${depEntry} 4] \
                               exp [lindex ${depEntry} 5] ]
      ResourceXml_addDependency ${_resourceXmlDoc} ${nameValueList}
   }

   # Handle node dependencies. They are stored in the module's flow.xml file.
   # If the module flow is being edited or the current node is new, 
   #    we store the dependencies in the node record only; when
   #    the user saves the flow, the dependencies will be saved at the same time
   # Else saves value to the module's flow.xml

   set flowNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_flowNode}]
   set nodeTableVar [ResourceView_getDepNodeTableVar ${depFrame}]
   global ${nodeTableVar}

   if { [ResourceControl_validateDepsData ${nodeTableVar} errorMsg] == false } {
      error "Error saving dependency entries for flow.xml. ${errorMsg}"
      return
   }

   # save in the flow.xml if the node is not new
   if { [${flowNodeRecord} cget -status] != "new" } {
      # open the flow.xml doc
      set flowXmlFile [ModuleLayout_getFlowXml ${_expPath} ${_moduleNode}]
      set flowXmlDoc [ResourceXml_parseFile ${flowXmlFile}]

      set moduleNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]

      #remove the previous dependencies and add the new ones
      ModuleFlowXml_removeDependencies ${flowXmlDoc} ${moduleNodeRecord} ${flowNodeRecord}
      ::log::log debug "ResourceControl_saveDepsData nodeTableVar:${nodeTableVar}"
      ::log::log debug "ResourceControl_saveDepsData [set ${nodeTableVar}]"
      foreach depEntry [set ${nodeTableVar}] {
         set nameValueList [ list type [lindex ${depEntry} 0] \
                               dep_name [lindex ${depEntry} 1] \
                               status [lindex ${depEntry} 2] \
                               index [lindex ${depEntry} 3] \
                               local_index [lindex ${depEntry} 4] \
                               hour [lindex ${depEntry} 5] \
                               exp [lindex ${depEntry} 6] ]
         ModuleFlowXml_addDependency ${flowXmlDoc} ${moduleNodeRecord} ${flowNodeRecord} ${nameValueList}
      }

      # save the xml file and delete the xml doc
      ResourceXml_saveDocument ${flowXmlFile} ${flowXmlDoc} true
   }

   # store the dependencies in the  node record
   ${flowNodeRecord} configure -deps [set ${nodeTableVar}]

   ::log::log debug "ResourceControl_saveDepsData $_expPath $_moduleNode $flowNodeRecord DONE"
}

proc ResourceControl_validateDepsData { _tableVar _outErrMsg } {
   upvar ${_tableVar} myTableVar
   upvar ${_outErrMsg} myOutputErrMsg
 
   foreach depEntry ${myTableVar} {
      set nameValueList [ list type node \
                               dep_name [lindex ${depEntry} 1] \
                               status [lindex ${depEntry} 2] \
                               index [lindex ${depEntry} 3] \
                               local_index [lindex ${depEntry} 4] \
                               hour [lindex ${depEntry} 5] \
                               exp [lindex ${depEntry} 6] ]

      # check for mandatory fields: type dep_name status
      ::log::log debug "ResourceControl_validateDepsData checking: $depEntry"
      if { [lindex ${depEntry} 0] == "" || [lindex ${depEntry} 1] == "" } {
         set myOutputErrMsg "Type, Node and Status are mandatory fields." 
	 return false
      }
   }

   return true
}

proc ResourceControl_saveLoopData { _expPath _moduleNode _flowNode _resourceXmlDoc } {
   ::log::log debug "ResourceControl_saveLoopData $_expPath $_moduleNode $_flowNode ${_resourceXmlDoc}" 
   set loopFrame [ResourceView_getLoopFrameWidget  ${_expPath} ${_moduleNode} ${_flowNode}]

   set loopStartValue [ResourceView_getLoopStartEntry ${loopFrame}]
   set loopStepValue [ResourceView_getLoopStepEntry ${loopFrame}]
   set loopEndValue [ResourceView_getLoopEndEntry ${loopFrame}]
   set loopSetValue [ResourceView_getLoopSetEntry ${loopFrame}]

   if { [string is integer ${loopStartValue}] && [string is integer ${loopEndValue}] &&
        ${loopStartValue} > ${loopEndValue} } {
      error "Error saving loop settings: Loop start value must be smaller than loop end value."
      return
   }

   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} start ${loopStartValue}
   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} end ${loopEndValue}
   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} step ${loopStepValue}
   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} set ${loopSetValue}
}

proc ResourceControl_saveSelected { _expPath _moduleNode _flowNodeRecord } {
   set nodeType [${_flowNodeRecord} cget -type]
   set flowNode [${_flowNodeRecord} cget -flow_path]
   set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${_moduleNode} [ModuleFlow_record2RealNode ${_flowNodeRecord}] ${nodeType}]

   # get a new xml document to work with
   set resourceXmlDoc [ResourceXml_createDocument]
   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]

   if { [ catch { 
      MiscTkUtils_busyCursor ${topWidget}
      # stores the data from the GUI to the xml doc

      ResourceControl_saveBatchData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc}
      ResourceControl_saveDepsData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc}
      ResourceControl_saveActionData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc}

      if { [${_flowNodeRecord} cget -type] == "LoopNode" } {
         ResourceControl_saveLoopData ${_expPath} ${_moduleNode} ${flowNode} ${resourceXmlDoc}
      }
   
      # save the xml file
      ResourceXml_saveDocument ${resourceFile} ${resourceXmlDoc} true

      # force refresh
      ResourceView_setDataChanged ${topWidget} false
      ResourceControl_refreshSelected ${_expPath} ${_moduleNode} ${_flowNodeRecord}

   } errMsg ] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
      set answer [ MessageDlg .msg_window -icon error -message "${errMsg} Click on Ok to see console logs for more details." \
         -title "Resource Settings Error" -type okcancel -justify center -parent ${topWidget} ]
      if { ${answer} == 0 } {
         MaestroConsole_show
      }
   }

   MiscTkUtils_normalCursor ${topWidget}
}

proc ResourceControl_refreshSelected {_expPath _moduleNode _flowNodeRecord } {
   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]
   MiscTkUtils_busyCursor ${topWidget}

   if { [ catch { 

      if { [ResourceView_getDataChanged ${topWidget}] == true } {
         set answer [MessageDlg .msg_window -icon warning -message "Resource settings have changed, are you sure you want to continue?" \
            -aspect 400 -title "Refresh Notification" -type okcancel -justify center -parent ${topWidget}]
         if { ${answer} == 1 } {
            MiscTkUtils_normalCursor ${topWidget}
	    return
         }
         ResourceView_setDataChanged ${topWidget} false
      }

      ResourceControl_retrieveData ${_expPath} ${_moduleNode} ${_flowNodeRecord} true

   } errMsg ] } {
      MaestroConsole_addErrorMsg "$::errorInfo"
      set answer [ MessageDlg .msg_window -icon error -message "${errMsg} Click on Ok to see console logs for more details." \
         -title "Resource Settings Error" -type okcancel -justify center -parent ${topWidget} ]
      if { ${answer} == 0 } {
         MaestroConsole_show
      }
   }

   MiscTkUtils_normalCursor ${topWidget}
}

proc ResourceControl_closeSelected { _expPath _moduleNode _flowNodeRecord } {
   ::log::log debug "ResourceControl_closeSelected $_expPath $_moduleNode $_flowNodeRecord"
   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]

   # ask for confirmation if data changed
   if { [winfo exists ${topWidget}] && [ResourceView_getDataChanged ${topWidget}] == true } {
      set answer [MessageDlg .msg_window -icon warning -message "Resource settings have changed, are you sure you want to continue?" \
         -aspect 400 -title "Cancel Notification" -type okcancel -justify center -parent ${topWidget}]
      if { ${answer} == 1 } {
	 return false
      }
      ResourceView_setDataChanged ${topWidget} false
   }

   destroy ${topWidget}

   # remove child toplevel windows
   ModuleFlowView_unregisterToplevel ${_expPath} ${_moduleNode} ${topWidget}

   # remove all global variables created for this resource
   ResourceView_cleanRegisteredVariables ${topWidget}

   return true
}
