
proc ResourceControl_init { _expPath _moduleNode _flowNodeRecord } {
   ResourceView_createWidgets ${_expPath} ${_moduleNode} ${_flowNodeRecord}
   ResourceControl_retrieveData ${_expPath} ${_moduleNode} ${_flowNodeRecord}
}

proc ResourceControl_retrieveData { _expPath _moduleNode _flowNodeRecord } {
   puts "ResourceControl_retrieveData ${_expPath} ${_moduleNode} ${_flowNodeRecord}"
   set flowNode [${_flowNodeRecord} cget -flow_path]
   set nodeType [${_flowNodeRecord} cget -type]

   set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${_moduleNode} ${flowNode} ${nodeType}]
   if { [file readable ${resourceFile}] } {
      set resourceXmlDoc [ResourceXml_parseFile ${resourceFile}]
   } else {
      set resourceXmlDoc [ResourceXml_createDocument]
   }

   set batchFrame [ResourceView_getBatchFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   foreach resAttribute { machine queue cpu memory wallclock catchup mpi soumet_args} {
      set savedValue [ResourceXml_getBatchAttribute ${resourceXmlDoc} ${resAttribute}]
      set procName "ResourceView_addEntry[string toupper ${resAttribute}]"
      puts "ResourceControl_retrieveData ${procName} 0 \"${savedValue}\""
      ${procName} ${batchFrame} 0 ${savedValue}
   }

   set dependsFrame [ResourceView_getDependsFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   ResourceControl_retrieveDepData ${_expPath} ${_moduleNode} ${_flowNodeRecord} ${dependsFrame} ${resourceXmlDoc}

   set abortActionFrame [ResourceView_getAbortActionFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   ResourceControl_retrieveActionData ${_expPath} ${_moduleNode} ${_flowNodeRecord} ${abortActionFrame} ${resourceXmlDoc}

   if { [${_flowNodeRecord} cget -type] == "LoopNode" } {
      set loopFrame [ResourceView_getLoopFrameWidget  ${_expPath} ${_moduleNode} ${flowNode}]
      ResourceControl_retrieveLoopData ${_expPath} ${_moduleNode} ${_flowNodeRecord} ${loopFrame} ${resourceXmlDoc}
   }
}

proc ResourceControl_retrieveBatchData { _expPath _moduleNode _flowNodeRecord _batchFrameWidget _resourceXmlDoc } {
   foreach resAttribute { machine queue cpu memory wallclock catchup mpi soumet_args} {
      set savedValue [ResourceXml_getBatchAttribute ${_resourceXmlDoc} ${resAttribute}]
      set procName "ResourceView_addEntry[string toupper ${resAttribute}]"
      puts "ResourceControl_retrieveBatchData ${procName} 0 \"${savedValue}\""
      ${procName} ${_batchFrameWidget} 0 ${savedValue}
   }
}

proc ResourceControl_retrieveActionData { _expPath _moduleNode _flowNodeRecord _actionFrameWidget _resourceXmlDoc } {
   set abortActionValue [ResourceXml_getAbortActionValue ${_resourceXmlDoc}]
   ResourceView_setAbortActionValue ${_actionFrameWidget} ${abortActionValue}
}

proc ResourceControl_retrieveDepData { _expPath _moduleNode _flowNodeRecord _depFrame _resourceXmlDoc} {
   puts "ResourceControl_retrieveDepData $_expPath $_moduleNode $_flowNodeRecord ${_depFrame}"
   set flowNode [${_flowNodeRecord} cget -flow_path]

   # the nodeId is used to set the variable that holds the values for the dependency table
   set nodeId [ExpLayout_getModuleChecksum ${_expPath} ${flowNode}]
   global Resource_${nodeId}_depends

   # get the dependency info from the resource xml file
   set Resource_${nodeId}_depends [ResourceXml_getDependencyList ${_resourceXmlDoc}]
}

proc ResourceControl_retrieveLoopData { _expPath _moduleNode _flowNodeRecord _loopFrame _resourceXmlDoc} {

   set loopStart [ResourceXml_getLoopAttribute ${_resourceXmlDoc} start]
   set loopEnd [ResourceXml_getLoopAttribute ${_resourceXmlDoc} end]
   set loopStep [ResourceXml_getLoopAttribute ${_resourceXmlDoc} step]
   set loopSet [ResourceXml_getLoopAttribute ${_resourceXmlDoc} set]

   ResourceView_addLoopStartEntry ${_loopFrame} 0 ${loopStart}
   ResourceView_addLoopEndEntry ${_loopFrame} 1 ${loopEnd}
   ResourceView_addLoopStepEntry ${_loopFrame} 2 ${loopStep}
   ResourceView_addLoopSetEntry ${_loopFrame} 3 ${loopSet}
}

proc ResourceControl_saveBatchData { _expPath _moduleNode _flowNodeRecord _batchFrameWidget _resourceXmlDoc} {
   puts "ResourceControl_saveBatchData $_expPath $_moduleNode $_flowNodeRecord $_batchFrameWidget"

   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} queue [ResourceView_getEntryQUEUE ${_batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} machine [ResourceView_getEntryMACHINE ${_batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} cpu [ResourceView_getEntryCPU ${_batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} memory [ResourceView_getEntryMEMORY ${_batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} wallclock [ResourceView_getEntryWALLCLOCK ${_batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} catchup [ResourceView_getEntryCATCHUP ${_batchFrameWidget} true]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} mpi [ResourceView_getEntryMPI ${_batchFrameWidget}]
   ResourceXml_saveBatchAttribute ${_resourceXmlDoc} soumet_args [ResourceView_getEntrySOUMET_ARGS ${_batchFrameWidget}]
}

proc ResourceControl_saveActionData { _expPath _moduleNode _flowNodeRecord _actionFrameWidget _resourceXmlDoc} {
   puts "ResourceControl_saveActionData $_expPath $_moduleNode $_flowNodeRecord $_actionFrameWidget"
   set value [ResourceView_getAbortActionValue ${_actionFrameWidget}]
   ResourceXml_setAbortActionValue ${_resourceXmlDoc} ${value}
   
}

proc ResourceControl_saveDepsData { _expPath _moduleNode _flowNodeRecord _depFrame _resourceXmlDoc} {
   puts "ResourceControl_saveDepsData $_expPath $_moduleNode $_flowNodeRecord"
   set flowNode [${_flowNodeRecord} cget -flow_path]
   # the nodeId is used to set the variable that holds the values for the dependency table
   set nodeId [ExpLayout_getModuleChecksum ${_expPath} ${flowNode}]

   global Resource_${nodeId}_depends
   foreach depEntry [set Resource_${nodeId}_depends] {
      puts "depEntry:${depEntry}"
      set nameValueList [ list type [lindex ${depEntry} 0] \
                               dep_name [lindex ${depEntry} 1] \
                               status [lindex ${depEntry} 2] \
                               index [lindex ${depEntry} 3] \
                               local_index [lindex ${depEntry} 4] \
                               hour [lindex ${depEntry} 5] \
                               exp [lindex ${depEntry} 6] ]

      ResourceXml_addDependency ${_resourceXmlDoc} ${nameValueList}
   }
}

proc ResourceControl_saveLoopData { _expPath _moduleNode _flowNodeRecord _loopFrame _resourceXmlDoc } {
   puts "ResourceControl_saveLoopData $_expPath $_moduleNode $_flowNodeRecord $_loopFrame ${_resourceXmlDoc}" 
   set loopStartValue [ResourceView_getLoopStartEntry ${_loopFrame}]
   set loopStepValue [ResourceView_getLoopStepEntry ${_loopFrame}]
   set loopEndValue [ResourceView_getLoopEndEntry ${_loopFrame}]
   set loopSetValue [ResourceView_getLoopSetEntry ${_loopFrame}]

   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} start ${loopStartValue}
   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} end ${loopEndValue}
   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} step ${loopStepValue}
   ResourceXml_saveLoopAttribute ${_resourceXmlDoc} set ${loopSetValue}
}

proc ResourceControl_saveSelected { _expPath _moduleNode _flowNodeRecord } {
   set nodeType [${_flowNodeRecord} cget -type]
   set flowNode [${_flowNodeRecord} cget -flow_path]
   set resourceFile [ModuleLayout_getNodeResourcePath ${_expPath} ${_moduleNode} ${flowNode} ${nodeType}]

   # get a new xml document to work with
   set resourceXmlDoc [ResourceXml_createDocument]

   # stores the data from the GUI to the xml doc
   set batchFrame [ResourceView_getBatchFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   ResourceControl_saveBatchData ${_expPath} ${_moduleNode} ${_flowNodeRecord} ${batchFrame} ${resourceXmlDoc}

   set dependsFrame [ResourceView_getDependsFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   ResourceControl_saveDepsData ${_expPath} ${_moduleNode} ${_flowNodeRecord} ${dependsFrame} ${resourceXmlDoc}

   set abortActionFrame [ResourceView_getAbortActionFrameWidget ${_expPath} ${_moduleNode} ${flowNode}]
   ResourceControl_saveActionData ${_expPath} ${_moduleNode} ${_flowNodeRecord} ${abortActionFrame} ${resourceXmlDoc}

   if { [${_flowNodeRecord} cget -type] == "LoopNode" } {
      set loopFrame [ResourceView_getLoopFrameWidget  ${_expPath} ${_moduleNode} ${flowNode}]
      ResourceControl_saveLoopData ${_expPath} ${_moduleNode} ${_flowNodeRecord} ${loopFrame} ${resourceXmlDoc}
   }

   # save the xml file
   ResourceXml_saveDocument ${resourceFile} ${resourceXmlDoc} true
}

proc ResourceControl_closeSelected { _expPath _moduleNode _flowNodeRecord } {
   set topWidget [ModuleFlowView_getWidgetName  ${_expPath} ${_moduleNode} resource_top_widget]
   destroy ${topWidget}
   ModuleFlowView_unregisterToplevel ${_expPath} ${_moduleNode} ${topWidget}

   set flowNode [${_flowNodeRecord} cget -flow_path]
   set nodeId [ExpLayout_getModuleChecksum ${_expPath} ${flowNode}]

   global Resource_${nodeId}_depends
   catch { unset Resource_${nodeId}_depends }

}
