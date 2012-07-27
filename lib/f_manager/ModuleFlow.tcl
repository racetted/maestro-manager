package require struct::record
package require tdom
package require textutil::trim

namespace import ::struct::record::*

#######################################################################
#######################################################################
# The code in this file contains logic to 
# - parse a module flow.xml
# - any logic related to management of a node within a module context
#
# It should not contain any GUI related logic.
# 
# It creates a module tree using the ModuleNode structure.
#
#
#######################################################################
#######################################################################

# this structure is used to build the
# module flow only, not used for
# experiment modules tree.
#
# name - name of node (only leaf part)
# children - contained children (full name).
#           the parent & children relation allows us to walk down a tree
#           as the sequencer would see it.
# type  - string representing node type (FamilyNode, ModuleNode, etc)
# submits - flow children (full name), nodes submitted by current node
# submitter - node that submits the current node; 
#                 if the node is submitted by a task, then the submitter is 
#                 the submitter task which is different than the parent which must
#                 be of type container
#                 The submits & submitter relation allows us to walk down
#                 a tree as it is shown by the GUI.
#
# status - i'm using this to know whether a node has just been created by the user
#          or not; current possible values "normal" | "new"
# is_work_unit - true means the container is a work_unit, all child nodes will be submitted
#                as single reservation i.e. supertask

record define FlowNode {
   name
   children
   type
   submits
   submitter
   { status normal }
   { work_unit false }
}

#record define FamilyNode {
#   {record FlowNode flow}
#   {type "FamilyNode"}
#}

#record define ModuleNode {
#   {record FlowNode flow}
#}

#record define TaskNode {
#   {record FlowNode flow}
#   {type "FlowTask"}
#}

#record define NpassTask {
#   {record FlowNode flow}
#   {record_type "FlowLoop"}
#}

record define LoopNode {
   {record FlowNode flow}
}

# reads the experiment modules tree xml file
# and build the tree in memory using ExpModTreeNode
#
# _expPath is path to experiment 
# _moduleXmlFile is path of module flow.xml file
# _parentFlowRecord is record of parent node container... empty if first call
# _modName is used only for a module node reference, when
#   the name used in the flow is different than the module reference name
proc ModuleFlow_readXml { _expPath _moduleXmlFile _parentFlowRecord {_modName ""} } {
   ::log::log debug "ModuleFlow_readXml _moduleXmlFile:${_moduleXmlFile} _modName:${_modName}"
   MaestroConsole_addMsg "read xml file: ${_moduleXmlFile}"
   if { ! [file readable ${_moduleXmlFile}] } {
      MaestroConsole_addErrorMsg "xml file not readable: ${_moduleXmlFile}"
      error "Cannot read ${_moduleXmlFile}!"
      return
   }

   if [ catch { set xmlSrc [exec cat ${_moduleXmlFile}] } ] {
      # let caller handle the exception
      MaestroConsole_addErrorMsg "while reading: ${_moduleXmlFile}"
      error "ModuleFlow_readXml error reading XML Document : ${_moduleXmlFile}"
      return
   }
   set xmlSrc [string trim ${xmlSrc}]

   set doc [dom parse ${xmlSrc} ]
   set rootNode [${doc} documentElement]

   # get the root module, it is a domNode object
   set topXmlNode [${rootNode} selectNodes /MODULE]
   set isXmlRootNode true
   ModuleFlow_parseXmlNode ${_expPath} ${topXmlNode} ${_parentFlowRecord} ${isXmlRootNode} ${_modName}

   # free the dom tree
   ${doc} delete
}

proc ModuleFlow_saveXml { _moduleXmlFile _modRootFlowNode } {
   set xmlDoc [dom createDocument MODULE]
   set xmlRootNode [${xmlDoc} documentElement]
   set date [clock format [clock seconds] -format "%d %b %Y"]

   ${xmlRootNode} setAttribute name [${_modRootFlowNode} cget -name]
   if { [${_modRootFlowNode} cget -work_unit] == true } {
      ${xmlRootNode} setAttribute work_unit 1
   }

   # create the first node
   foreach submitNode [ModuleFlow_getSubmitRecords ${_modRootFlowNode}] {
      set xmlSubmitNode [${xmlDoc} createElement SUBMITS]
      ${xmlSubmitNode} setAttribute sub_name [${submitNode} cget -name]
      ${xmlRootNode} appendChild ${xmlSubmitNode}
   }

   foreach submitNode [ModuleFlow_getSubmitRecords ${_modRootFlowNode}] {
      # iterate through all submits
      ModuleFlow_flowNodeRecord2Xml ${submitNode} ${xmlDoc} ${xmlRootNode}
   }

   MaestroConsole_addMsg "save flow xml file:${_moduleXmlFile}"
   set result [${xmlDoc} asXML]
   set fileId [open ${_moduleXmlFile} w 0664]
   puts ${fileId} ${result}
   close ${fileId}

   ${xmlDoc} delete
}

# creates a dummy flow xml file with the module as the only node
# This is meant to be called when a user creates a new module from scratch.
# _moduleXmlFile is path to flow.xml file i.e. SEQ_EXP_HOME/modules/gem_mod/flow.xml
proc ModuleFlow_initXml { _moduleXmlFile _moduleNode } {
   set xmlDoc [dom createDocument MODULE]
   set xmlRootNode [${xmlDoc} documentElement]
   set date [clock format [clock seconds] -format "%d %b %Y"]
   ::log::log debug "ModuleFlow_initXml creating file:${_moduleXmlFile}"

   ${xmlRootNode} setAttribute name [file tail ${_moduleNode}]

   MaestroConsole_addMsg "create flow xml file:${_moduleXmlFile}"
   set result [${xmlDoc} asXML]
   set fileId [open ${_moduleXmlFile} w 0664]
   puts ${fileId} ${result}
   close ${fileId}

   ${xmlDoc} delete
}

proc ModuleFlow_flowNodeRecord2Xml { _flowNodeRecord _xmlDoc _xmlParentNode } {

   set FlowNodeTypeMap {   TaskNode TASK 
                           FamilyNode FAMILY 
                           LoopNode LOOP
                           ModuleNode MODULE
                           NpassTaskNode NPASS_TASK
                       }
   ::log::log debug "ModuleFlow_flowNodeRecord2Xml _flowNodeRecord:${_flowNodeRecord}"
   set nodeType [${_flowNodeRecord} cget -type]
   set xmlNodeName [string map ${FlowNodeTypeMap} ${nodeType}]

   ::log::log debug "ModuleFlow_flowNodeRecord2Xml xmlNodeName:${xmlNodeName}"
   set xmlDomNode [${_xmlDoc} createElement ${xmlNodeName}]
   ${xmlDomNode} setAttribute name [${_flowNodeRecord} cget -name]
   if { [${_flowNodeRecord} cget -work_unit] == true } {
      ${xmlDomNode} setAttribute work_unit 1
   }
   ${_xmlParentNode} appendChild ${xmlDomNode}

   # we stop here for module nodes
   if { ${nodeType} != "ModuleNode" } {
      # create submits tag first
      foreach submitNode [ModuleFlow_getSubmitRecords ${_flowNodeRecord}] {   
         # create submit tag
         set xmlSubmitNode [${_xmlDoc} createElement SUBMITS]
         ${xmlDomNode} appendChild ${xmlSubmitNode}
         ${xmlSubmitNode} setAttribute sub_name [${submitNode} cget -name]
         switch [${submitNode} cget -type] {
            NpassTaskNode {
               # set this attribute so that the npass task is not submitted by the sequencer
               ${xmlSubmitNode} setAttribute type "user"
            }
         }
      }

      # create the flow node elements
      foreach submitNode [ModuleFlow_getSubmitRecords ${_flowNodeRecord}] {
         if { [ModuleFlow_isContainer ${_flowNodeRecord}] } {
            # following nodes belong to the new container node
            ModuleFlow_flowNodeRecord2Xml ${submitNode} ${_xmlDoc} ${xmlDomNode}
         } else {
            # following nodes belong to the previous container node
            ModuleFlow_flowNodeRecord2Xml ${submitNode} ${_xmlDoc} ${_xmlParentNode}
         }
      }
   }
}

# _modName is used only for a module node reference, when
# the name is different than the reference leaf part
proc ModuleFlow_parseXmlNode { _expPath _domNode _parentFlowRecord {_isXmlRootNode false} { _modName "" } } {
   ::log::log debug "ModuleFlow_parseXmlNode _parentFlowRecord:${_parentFlowRecord}"
   set xmlNodeName [${_domNode} nodeName]
   set parentFlowNode ${_parentFlowRecord}
   set flowNode ""
   ::log::log debug "ModuleFlow_parseXmlNode xmlNodeName:${xmlNodeName}"
   set FlowNodeTypeMap {   TASK "TaskNode"
                           FAMILY "FamilyNode"
                           LOOP "LoopNode"
                           MODULE "ModuleNode"
                           NPASS_TASK "NpassTaskNode"
                       }
   if { ${xmlNodeName} == "MODULE" && ${_isXmlRootNode} == false } {
      # don't process the referenced module node
      # go read the module flow
      set nodeName [${_domNode} getAttribute name]
      set moduleNode ${parentFlowNode}/${nodeName}
      set moduleXmlFile [ModuleLayout_getFlowXml ${_expPath} ${moduleNode}]
      ::log::log debug "ModuleFlow_parseXmlNode moduleFlowFile:${moduleXmlFile}"
      if { [file exists ${moduleXmlFile}] } {
         if { ${_modName} != "" } {
            ModuleFlow_readXml ${_expPath} ${moduleXmlFile} ${_parentFlowRecord} ${_modName}
         } else {
            ModuleFlow_readXml ${_expPath} ${moduleXmlFile} ${_parentFlowRecord} ${nodeName}
         }
         return
      } else {
         # should send this to a console
         ::log::log error "ERROR: Cannot read module xml file: ${moduleXmlFile}"
         MaestroConsole_addWarningMsg "Cannot read xml file: ${moduleXmlFile}"
      }
   }

   switch ${xmlNodeName} {
      "MODULE" -
      "FAMILY" -
      "LOOP" -
      "TASK" -
      "NPASS_TASK" {
         set nodeName [${_domNode} getAttribute name]
         set flowNode ${parentFlowNode}/${nodeName}
         if { ${_modName} != "" } {
            set flowNode ${parentFlowNode}/${_modName}
         }
         set nodeType [string map $FlowNodeTypeMap ${xmlNodeName}]  
         set recordName [ModuleFlow_getRecordName ${_expPath} ${flowNode}]
         ::log::log debug "ModuleFlow_parseXmlNode xmlNodeName:${xmlNodeName} flowNode:${flowNode} nodeName:${nodeName} nodeType:${nodeType}"
         # submit parent is relative to parent container node
         FlowNode ${recordName} -name [file tail ${flowNode}] -type ${nodeType} -submitter [ModuleFlow_searchSubmitter ${_parentFlowRecord} ${recordName}]

         if { ${parentFlowNode}  != "" } {
            ModuleFlow_addChildNode ${parentFlowNode} ${flowNode}
         }
      }
      default {
      }
   }

   # build module tree
   # need to get the parent module
   # the record of the module node in the exp tree is build using the exp node name
   # but with a different prefix to avoid name clash
   if { ${xmlNodeName} == "MODULE" } {
      set parentModTreeName ""
      if { ${_parentFlowRecord} != "" } {
         set parentModule [ModuleFlow_getModuleContainer ${recordName}]
         set parentModName [ModuleFlow_record2NodeName ${parentModule}]
         set parentModTreeName [ExpModTree_getRecordName ${_expPath} ${parentModName}]
         set flowNode [ModuleFlow_record2NodeName ${recordName}]
      }
      ExpModTree_addModule ${_expPath} ${flowNode} ${parentModTreeName} ${nodeName}
   }

   # process child nodes
   if { ${flowNode} != "" } {
      ModuleFlow_xmlParseSubmits ${recordName} ${_domNode}
      if { [${_domNode} hasChildNodes] } {
         set xmlChildren [${_domNode} childNodes]
         foreach xmlChild $xmlChildren {
            ModuleFlow_parseXmlNode ${_expPath} $xmlChild ${recordName} false
         }
      }
   }
}

# get the submits relation of an xml node
#
proc ModuleFlow_xmlParseSubmits { _flowNodeRecord _xmlNode } {
   set submitNodes [${_xmlNode} selectNodes SUBMITS]
   set flowChildren ""
   if { [ModuleFlow_isContainer ${_flowNodeRecord}] == false } {
      set submitParent [ModuleFlow_getParentContainer ${_flowNodeRecord}]
   } else {
      set submitParent ${_flowNodeRecord}
   }

   foreach submitNode ${submitNodes} {
      set flowSubmitName [${submitNode} getAttribute sub_name ""]
      set flowChildNode ${submitParent}/${flowSubmitName}
      ::log::log debug "ModuleFlow_xmlParseSubmits ::textutil::trim::trimPrefix ${flowChildNode} ${submitParent}"
      lappend flowChildren ${flowSubmitName}
   }
   ${_flowNodeRecord} configure -submits ${flowChildren}
}

# refreshes the module flow by deleting all records
# belonging to the node and rereading the xml flow
# This is required for instance when a user refreshes or exits
# a modified flow withouth saving...
#
proc ModuleFlow_refresh { _expPath _moduleNode } {
   ::log::log debug "ModuleFlow_refresh _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set modNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   set parentNodeRecord [ModuleFlow_getParentContainer ${modNodeRecord}]

   # delete all module node records in the module flow
   ModuleFlow_deleteRecord ${_expPath} ${_moduleNode}

   # delete all module node records in the exp module tree
   ExpModTree_deleteRecord ${_expPath} ${_moduleNode}

   # reread module flow xml
   set moduleFlowXml [ModuleLayout_getFlowXml ${_expPath} ${_moduleNode}]
   ModuleFlow_readXml ${_expPath} ${moduleFlowXml} ${parentNodeRecord} [file tail ${_moduleNode}]
}

# _currentNodeRecord record of submitter node
# _newName name of new node to be created, only leaf part
# _nodeType TaskNode | NpassTaskNode | LoopNode | ModuleNode | FamilyNode
# _insertPosition position where the node is inserted with respect to the submitter node (serial | 0 | 1 etc )
# _modPath only used for _nodeType == ModuleNode, refers to the path of the module i.e. /home/binops/afsi/sio/components/modules/gem_mod
# _useModLink only used for _nodeType == ModuleNode, indicates whether or not to use a link to
#       create the module instead of creating  a local module
proc ModuleFlow_createNewNode { _expPath _currentNodeRecord _newName _nodeType _insertPosition _isWorkUnit { _modPath "" } {_useModLink true} } {
   ::log::log debug "ModuleFlow_createNewNode _currentNodeRecord:${_currentNodeRecord} _newName:${_newName} _nodeType:${_nodeType} _insertPosition:${_insertPosition} _isWorkUnit:${_isWorkUnit} _modPath:${_modPath} _useModLink:${_useModLink}"
   
   # if parent is not container, get the container
   if { ${_insertPosition} == "parent" } {
      set containerNodeRecord [ModuleFlow_getParentContainer ${_currentNodeRecord}]
   } else {
      if { [ModuleFlow_isContainer ${_currentNodeRecord}] == true } {
         set containerNodeRecord ${_currentNodeRecord}
      } else {
         set containerNodeRecord [ModuleFlow_getParentContainer ${_currentNodeRecord}]
      }
   }

   set newNodeRecord [ModuleFlow_getRecordName ${_expPath} ${containerNodeRecord}/${_newName}]
   set newNode [ModuleFlow_record2NodeName ${newNodeRecord}]
   if { [record exists instance ${newNodeRecord}] } {
      error NodeDuplicate
      return
   }

   # create new node
   ::log::log debug "ModuleFlow_createNewNode FlowNode ${newNodeRecord} -name ${_newName} -type ${_nodeType} -submitter ${_currentNodeRecord}"
   FlowNode ${newNodeRecord} -name ${_newName} -type ${_nodeType} -status new -work_unit ${_isWorkUnit}
   
   set parentModRecord [ModuleFlow_getModuleContainer ${newNodeRecord}]
   set moduleNode [ModuleFlow_record2NodeName ${parentModRecord}]

   # create node in modules directory
   if { [ExpLayout_isModuleWritable ${_expPath} ${moduleNode}] == true } {
      
      if { ${_nodeType} == "ModuleNode" } {
         ModuleFlowControl_addPostSaveCmd ${_expPath} ${moduleNode} \
            [list ModuleLayout_createNode ${_expPath} ${moduleNode} \
            [ModuleFlow_record2NodeName ${newNodeRecord}] ${_nodeType} ${_modPath} ${_useModLink}]
      } else {
         ModuleLayout_createNode ${_expPath} ${moduleNode} [ModuleFlow_record2NodeName ${newNodeRecord}] ${_nodeType} ${_modPath} ${_useModLink}
      }
   }
   # attach to submitter
   set insertParentPos ${_insertPosition}

   switch ${_insertPosition} {
      serial {
         set insertParentPos 0
         # we need to shift all nodes to the right; they become new submits
         # of the new node
         # - assign all submits of the current node to the new node
         set submittedNodeRecords [ModuleFlow_getSubmitRecords ${_currentNodeRecord}]
         set childPosition 0
         foreach submitNodeRecord ${submittedNodeRecords} {
            ModuleFlow_addSubmitNode ${newNodeRecord} ${submitNodeRecord} ${childPosition}
            incr childPosition
         }

         # - assign the new node as the only submitted node of current node
         ${_currentNodeRecord} configure -submits ""
         ModuleFlow_addSubmitNode ${_currentNodeRecord} ${newNodeRecord}

         # if new node is container need to re-assign children at the container level
         # - all submitted nodes until the next container is a new child
         # - All nodes that are children (to the right) of the new container nodes needs to be renamed
         # because the record name is built using the experiment containment tree
         if { [ModuleFlow_isContainer ${newNodeRecord}] == true } {
            # I have to go down the submits path until the end or until bumping another container
            set childPosition 0
            foreach submitNodeRecord ${submittedNodeRecords} {
               ModuleFlow_assignNewContainerDir  ${_expPath} ${moduleNode} ${submitNodeRecord} ${newNodeRecord}
               ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${newNodeRecord} ${childPosition}
               incr childPosition
            }
         }
      }
      parent {
         # current node will be submitted by new node

         # first action: submitter of current node now submits new node
         set submitter [ModuleFlow_getSubmitter ${_currentNodeRecord}]
         set currentNodePosition [ModuleFlow_getSubmitPosition ${_currentNodeRecord}]
         ModuleFlow_removeSubmitNode ${submitter} ${_currentNodeRecord}
         ModuleFlow_addSubmitNode ${submitter} ${newNodeRecord} ${currentNodePosition}

         # next, assign current node as only submitted node of new node
         ModuleFlow_addSubmitNode ${newNodeRecord} ${_currentNodeRecord}

         # if new node is container need to re-assign children at the container level
         if { [ModuleFlow_isContainer ${newNodeRecord}] == true } {
            ModuleFlow_assignNewContainerDir  ${_expPath} ${moduleNode} ${_currentNodeRecord} ${newNodeRecord}
            ModuleFlow_assignNewContainer ${_expPath} ${_currentNodeRecord} ${newNodeRecord} 0
         }
         set containerNodeRecord [ModuleFlow_getParentContainer ${_currentNodeRecord}]
         set insertParentPos end
      }
      default {
         # add current node as a submitted node to the submitter
         ModuleFlow_addSubmitNode ${_currentNodeRecord} ${newNodeRecord} ${_insertPosition}
      }
   }

   # attach to parent container
   ModuleFlow_addChildNode ${containerNodeRecord} ${newNodeRecord} ${insertParentPos}
}

proc ModuleFlow_deleteNode { _expPath _origFlowNodeRecord _flowNodeRecord {_isRecursive false} } {
   ::log::log debug "ModuleFlow_deleteNode _origFlowNodeRecord:${_origFlowNodeRecord} _flowNodeRecord:${_flowNodeRecord}"

   set submitter [ModuleFlow_getSubmitter ${_flowNodeRecord}]
   set submittedNodeRecords [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set flowNodePosition [ModuleFlow_getSubmitPosition ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]
   set parentContainer [ModuleFlow_getParentContainer ${_flowNodeRecord}]
   set parentModRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleNode [ModuleFlow_record2NodeName ${parentModRecord}]
   set origModuleNodeRecord [ModuleFlow_getModuleContainer ${_origFlowNodeRecord}]
   set origModuleNode [ModuleFlow_record2NodeName ${origModuleNodeRecord}]
   set keepChildNodes true
   if { ${_isRecursive} == true } {
      # remove submitted nodes first
      foreach submitNodeRecord ${submittedNodeRecords} {
         ModuleFlow_deleteNode ${_expPath} ${_origFlowNodeRecord} ${submitNodeRecord} ${_isRecursive}
      }
      set keepChildNodes false
   } else {

      # if deleted node is a container, need to re-assign children at the container level
      # - all submitted nodes until the next container become child nodes of
      #   their grandparent container (mmm...programming concepts!)
      # - All nodes that are children (to the right) of the deleted container nodes needs to be renamed
      # because the record name is build using the experiment containment tree
      if { [ModuleFlow_isContainer ${_flowNodeRecord}] == true } {
         # I have to go down the submits path until the end or until bumping another container
         set childPosition 0
         foreach submitNodeRecord ${submittedNodeRecords} {
            ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${parentContainer} ${childPosition}
            incr childPosition
         }
      }

      # if the node is submitting other nodes, assign those to the current submitter
      set submittedNames [${_flowNodeRecord} cget -submits]
      # assign the new nodes at the same position as the current
      foreach submitName ${submittedNames} {
         set submitNode ${parentContainer}/${submitName}
         ::log::log debug "ModuleFlow_deleteNode ModuleFlow_addSubmitNode ${submitter} ${submitNode} ${flowNodePosition}"
         ModuleFlow_addSubmitNode ${submitter} ${submitNode} ${flowNodePosition}
         incr flowNodePosition
      }
   }


   # all submit nodes are removed, now delete current node
   # - remove node reference from submitter
   ModuleFlow_removeSubmitNode ${submitter} ${_flowNodeRecord}

   # - remove node reference from parent container
   ModuleFlow_removeChild ${parentContainer} ${_flowNodeRecord}

   # delete single node
   record delete instance ${_flowNodeRecord}

   # delete node from module container directory only if the current node belongs to the original module.
   # Nodes that belong to a reference module will be cleared at another level if the module reference count
   # is 0
   if { [ExpLayout_isModuleWritable ${_expPath} ${moduleNode}] == true } {
      if { ${origModuleNode} == ${moduleNode} } {
         # delete node and resource
         ModuleLayout_deleteNode ${_expPath} ${moduleNode} ${flowNode} ${nodeType} false ${keepChildNodes}
      } else {
         # delete resource only
         ModuleLayout_deleteNode ${_expPath} ${moduleNode} ${flowNode} ${nodeType} true ${keepChildNodes}
      }
   }
}

proc ModuleFlow_renameNode { _expPath _flowNodeRecord _newName } {
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set submitter [ModuleFlow_getSubmitter ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]
   set parentModRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleNode [ModuleFlow_record2NodeName ${parentModRecord}]
   set submittedNodeRecords [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]

   set containerNodeRecord [ModuleFlow_getParentContainer ${_flowNodeRecord}]
   set newNodeRecord [ModuleFlow_getRecordName ${_expPath} ${containerNodeRecord}/${_newName}]
   set newNode [ModuleFlow_record2NodeName ${newNodeRecord}]
   
   if { [record exists instance ${newNodeRecord}] } {
      error NodeDuplicate
      return
   }
   if { ${nodeType} == "ModuleNode" } {
      set isLink  [ExpLayout_isModuleLink ${_expPath} ${flowNode}]
      set linkTarget ""
      if { ${isLink} == true } {
         set linkTarget [ExpLayout_getModLinkTarget ${_expPath} ${flowNode}]
      }
      ExpLayout_checkModPathExists ${_expPath} ${newNode} ${linkTarget} ${isLink}
   }

   # create new node
   ::log::log debug "ModuleFlow_renameNode FlowNode ${newNodeRecord} -name ${_newName} -type ${nodeType} -submitter ${submitter}"
   FlowNode ${newNodeRecord} -name ${_newName} -type ${nodeType} -submits [${_flowNodeRecord} cget -submits] -children [${_flowNodeRecord} cget -children] \
      -submitter [${_flowNodeRecord} cget -submitter] -status new

   # if new node is container need to re-assign children at the container level
   # - all submitted nodes until the next container is a new child
   # - All nodes that are children (to the right) of the new container nodes needs to be renamed
   # because the record name is build using the experiment containment tree
   if { [ModuleFlow_isContainer ${newNodeRecord}] == true } {
      # I have to go down the submits path until the end or until bumping another container
      set childPosition 0
      foreach submitNodeRecord ${submittedNodeRecords} {
         # ModuleFlow_assignNewContainerDir  ${_expPath} ${moduleNode} ${submitNodeRecord} ${newNodeRecord}
         ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${newNodeRecord} ${childPosition}
         incr childPosition
      }
   } else {
      # need to change the submitter value of the nodes being submitted by 
      # the current node because the submitter value is non-empty when is it not submitted by a container
      foreach submitRecord ${submittedNodeRecords} {
         ModuleFlow_setSubmitter ${submitRecord} ${newNodeRecord}
      }
   }
   # set all child nodes status to new
   ModuleFlow_changeStatus ${_expPath} ${newNode} new true

   # current submit position from submitter
   set submitPosition [ModuleFlow_getSubmitPosition ${_flowNodeRecord}]

   # remove node reference from submitter
   ModuleFlow_removeSubmitNode ${submitter} ${_flowNodeRecord}

   # remove node from parent container
   ModuleFlow_removeChild ${containerNodeRecord} ${_flowNodeRecord}

   # delete single node
   record delete instance ${_flowNodeRecord}

   # add new node reference to submitter
   ModuleFlow_addSubmitNode ${submitter} ${newNodeRecord} ${submitPosition}

   # add new node to parent container
   ModuleFlow_addChildNode ${containerNodeRecord} ${newNodeRecord} end

   # rename node from experiment module directory
   ModuleLayout_renameNode ${_expPath} ${moduleNode} ${flowNode} ${_newName} ${nodeType}
}

# recursively assigns a new parent container starting from the starting node until
# it hits the end
# - newly given child nodes must be renamed
# - newly given child nodes must be removed from existing parent container
# It follows the submit tree of the starting node but does not change the submits relation
#
proc ModuleFlow_assignNewContainer { _expPath _flowNodeRecord _newContainerRecord _childPosition } {
   ::log::log debug "ModuleFlow_assignNewContainer _flowNodeRecord:${_flowNodeRecord} _newContainerRecord:${_newContainerRecord}"

   # first the node needs to be removed from its current container node
   ModuleFlow_removeChild [ModuleFlow_getParentContainer ${_flowNodeRecord}] ${_flowNodeRecord}

   # the node gets the new container parent node
   # since the name of the node is build within the experiment tree, it needs to be changed
   # to take into account the new container in the way
   set recordName [ModuleFlow_getRecordName ${_expPath} ${_newContainerRecord}/[${_flowNodeRecord} cget -name]]
   FlowNode ${recordName} -name [${_flowNodeRecord} cget -name] -type [${_flowNodeRecord} cget -type] \
      -submits [${_flowNodeRecord} cget -submits] -children [${_flowNodeRecord} cget -children] \
      -submitter [${_flowNodeRecord} cget -submitter]

   # satisfy same relation on the new container parent node
   # the new child is added to the parent container node
   ModuleFlow_addChildNode ${_newContainerRecord} ${_flowNodeRecord} ${_childPosition}

   # continue down the submit path if not container
   set submits [${_flowNodeRecord} cget -submits]
   set childPosition 0
   foreach submitNode ${submits} {
      #set submitNodeName [ModuleFlow_getParentContainer ${_flowNodeRecord}]/${submitNode}
      if { [ModuleFlow_isContainer ${_flowNodeRecord}] == true } {
         set submitNodeName ${_flowNodeRecord}/${submitNode}
         set parentContainer ${recordName}
      } else {
         set parentContainer ${_newContainerRecord}
         set submitNodeName [ModuleFlow_getParentContainer ${_flowNodeRecord}]/${submitNode}
      }
      ModuleFlow_assignNewContainer ${_expPath} ${submitNodeName} ${parentContainer} ${childPosition}
      incr childPosition
   }

   # delete previous record of the node
   ::log::log debug "ModuleFlow_assignNewContainer deleting record ${_flowNodeRecord}"
   record delete instance ${_flowNodeRecord}
}

# 
# recursively assigns a new container directory in the module directory structure
# starting from the starting node until
# it hits the end or until it hits another container node
# - newly given child nodes must be removed from existing parent container
#   and moved to the new parent directory
# It follows the submit tree of the starting node but does not change the submits relation
#

proc ModuleFlow_assignNewContainerDir { _expPath _moduleNode _flowNodeRecord _newContainerRecord } {
   ::log::log debug "ModuleFlow_assignNewContainerDir _flowNodeRecord:${_flowNodeRecord} _newContainerRecord:${_newContainerRecord}"
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set containerNode [ModuleFlow_record2NodeName ${_newContainerRecord}]
   ModuleLayout_assignNewContainer ${_expPath} ${_moduleNode} ${containerNode} ${flowNode} [${_flowNodeRecord} cget -type]
   if { ! [ModuleFlow_isContainer ${_flowNodeRecord}] } {
      set submits [${_flowNodeRecord} cget -submits]
      foreach submitNode ${submits} {
         set submitNodeName [ModuleFlow_getParentContainer ${_flowNodeRecord}]/${submitNode}
         ModuleFlow_assignNewContainerDir ${_expPath} ${_moduleNode} ${submitNodeName} ${_newContainerRecord}
      }
   }
}

# removes a child node from the current list of children
# does not touch submits relation
# does not delete the child node record
proc ModuleFlow_removeChild { _flowNodeRecord _childNode } {
   ::log::log debug "ModuleFlow_removeChild _flowNodeRecord:${_flowNodeRecord} _childNode:${_childNode}"
   set currentChilds [${_flowNodeRecord} cget -children]
   set childToSearch [${_childNode} cget -name]
   set childNodeIndex [lsearch ${currentChilds} ${childToSearch}]
   if { ${childNodeIndex} != -1 } {
      set newChilds [lreplace ${currentChilds} ${childNodeIndex} ${childNodeIndex}]
      ${_flowNodeRecord} configure -children ${newChilds}
   } 
}

# searches does the submit path and look for a module node
# returns the first module found or else returns an empty value
#
# _modNodes is a variable that is passed by reference recursively
#
proc ModuleFLow_getChildModuleNodes { _flowNodeRecord _modNodes } {
   upvar ${_modNodes} localModNodes

   ::log::log debug "ModuleFLow_getChildModuleNodes _flowNodeRecord:${_flowNodeRecord} ${_modNodes}"
   set submitRecords [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]
   foreach submitRecord ${submitRecords} {
      if { [${submitRecord} cget -type] == "ModuleNode" } {
         lappend localModNodes [ModuleFlow_record2NodeName ${submitRecord}]
      }
      ModuleFLow_getChildModuleNodes ${submitRecord} localModNodes
   }
}

# returns true if the node is the root node of the module
# returns false otherwise
# 
# considered root node if the record has only one slash
proc ModuleFlow_isExpRootNode { _flowNodeRecord } {
   if { [llength [split ${_flowNodeRecord} /]] == 2 } {
      return true
   }
   #if { [file dirname ${_flowNodeRecord}] == "ModuleNode_" } {
   #   return true
   #}
   return false
}

proc ModuleFlow_isContainer { _flowNodeRecord } {
   if { [${_flowNodeRecord} cget -type] == "TaskNode" || [${_flowNodeRecord} cget -type] == "NpassTaskNode" } {
      return false
   }
   return true
}

# returns the node path of the new node to be created based on its parent,
# whether it is a container or not
# _flowNodeRecord is the record of the node submitting the new node
# _newNodeName is the name of the new node, not the full path
# returns node as in /enkf_mod/family_1/node1
proc ModuleFlow_getNewNode { _flowNodeRecord _newNodeName } {
   if { [ModuleFlow_isContainer ${_flowNodeRecord}] == true } {
      set newNodeRecord  ${_flowNodeRecord}/${_newNodeName}
   } else {
      set newNodeRecord [ModuleFlow_getParentContainer ${_flowNodeRecord}]/${_newNodeName}
   }
   return [ModuleFlow_record2NodeName ${newNodeRecord}]
}

# search upwards the node to find the module contianer
proc ModuleFlow_getModuleContainer { _flowNodeRecord } {
   ::log::log debug "ModuleFlow_getModuleContainer _flowNodeRecord:${_flowNodeRecord}"
   set node ${_flowNodeRecord}
   set done false
   set foundNode ""
   while { ${done} == false && ${node} != "" } {
      set parentNode [ModuleFlow_getParentContainer ${node}]
      if { ${parentNode} != "" && [${parentNode} cget -type] == "ModuleNode" } {
         set done true  
         set foundNode ${parentNode}
      }
      set node ${parentNode}
   }

   ::log::log debug "ModuleFlow_getModuleContainer _flowNodeRecord:${_flowNodeRecord} foundNode:${foundNode}"
   return ${foundNode}
}

# returns the position that in which the _flowNodeRecord is submitted from it's current
# submitter
proc ModuleFlow_getSubmitPosition { _flowNodeRecord } {
   set position 0
   if { [ModuleFlow_isExpRootNode ${_flowNodeRecord}] == false } {
      set submitterNode [ModuleFlow_getSubmitter ${_flowNodeRecord}]
      set submitterSubmits [${submitterNode} cget -submits]
      set foundIndex [lsearch ${submitterSubmits} [${_flowNodeRecord} cget -name]]
      if { ${foundIndex} != -1 } {
         set position ${foundIndex}
      }
   }
   return ${position}
}

# the submits are stored as node containing the relative path from the
# parent container... this is a shortcut that will return the submits
# with real node records
# for instance if task /f1/t1 submits task /f1/t2
# the values of submits stored in node /f1/t1 will be /t2 and not /f1/t2
#
#
# this function will return the record for node /f1/t2
#
proc ModuleFlow_getSubmitRecords { _flowNodeRecord } {
   set submits [${_flowNodeRecord} cget -submits]
   set newSubmits {}
   if { [ModuleFlow_isContainer ${_flowNodeRecord}] } {
      set parentContainer ${_flowNodeRecord}
   } else {
      set parentContainer [ModuleFlow_getParentContainer ${_flowNodeRecord}]
   }
   set count 0
   foreach submitNode ${submits} {
      lappend newSubmits ${parentContainer}/${submitNode}
   }

   ::log::log debug "ModuleFlow_getSubmitRecords _flowNodeRecord:${_flowNodeRecord} newSubmits:${newSubmits}"
   return ${newSubmits}
}

# add node _submitNode to the list of nodes submitted by _flowNodeRecord at position _position
# _flowNodeRecord & _submitNode are FlowNode records
proc ModuleFlow_addSubmitNode { _flowNodeRecord _submitNodeRecord { _position end } } {
   ::log::log debug "ModuleFlow_addSubmitNode _flowNodeRecord:${_flowNodeRecord} _submitNodeRecord:${_submitNodeRecord} _position:${_position}"
   # attach to submitter
   # submits are stored as relative path to the parent container
   set currentSubmits [${_flowNodeRecord} cget -submits]
   set currentSubmits [linsert ${currentSubmits} ${_position} [${_submitNodeRecord} cget -name]]
   ${_flowNodeRecord} configure -submits ${currentSubmits}

   # set the _flowNodeRecord as submit parent of the _submitNode
   ModuleFlow_setSubmitter ${_submitNodeRecord} ${_flowNodeRecord}
}

# remove node _submitNode from the list of nodes submitted by _flowNodeRecord
# _flowNodeRecord & _submitNode are FlowNode records
proc ModuleFlow_removeSubmitNode { _flowNodeRecord _submitNode } {
   ::log::log debug "ModuleFlow_removeSubmitNode _flowNodeRecord:${_flowNodeRecord} _submitNode:${_submitNode}"
   # detach from submitter
   set submits [${_flowNodeRecord} cget -submits]
   set submitIndex [lsearch ${submits} [${_submitNode} cget -name]]
   if { ${submitIndex} != -1 } {
      set submits [lreplace ${submits} ${submitIndex} ${submitIndex}]
      ${_flowNodeRecord} configure -submits ${submits}
   }
}

proc ModuleFlow_setSubmitter { _flowNodeRecord _submitterNodeRecord } {
   # submits are stored as relative path to the parent container
   if { [ModuleFlow_isContainer ${_submitterNodeRecord}] == true } {
      ${_flowNodeRecord} configure -submitter ""
   } else {
      ${_flowNodeRecord} configure -submitter [file tail ${_submitterNodeRecord}]
   }
}

# returns the node submitting the given _flowNodeRecord
proc ModuleFlow_getSubmitter { _flowNodeRecord } {
   set submitter [file dirname ${_flowNodeRecord}]
   if { [${_flowNodeRecord} cget -submitter] != "" } {
      # submitter is relative to parent container
      set submitter ${submitter}/[${_flowNodeRecord} cget -submitter]
   }
   return ${submitter}
}

proc ModuleFlow_addChildNode { _flowNodeRecord _childNode { _position end } } {
   # child nodes are stored as relative path to the parent container
   set childrenNodes [${_flowNodeRecord} cget -children]
   if { [lsearch ${childrenNodes} [${_childNode} cget -name] ] == -1 } {
      set childrenNodes [linsert ${childrenNodes} ${_position} [${_childNode} cget -name]]
      ::log::log debug "ModuleFlow_addChildNode _flowNodeRecord:${_flowNodeRecord} _childNode: ${_childNode} childrenNodes:${childrenNodes}"
      ${_flowNodeRecord} configure -children ${childrenNodes}
   }
}

proc ModuleFlow_getParentContainer { _flowNodeRecord } {
   if { [ModuleFlow_isExpRootNode ${_flowNodeRecord}] == true } {
      return ""
   }
   return [file dirname ${_flowNodeRecord}]
}

# search down the given flow node submits tree to see which one submits the given node
# submit parent is stored as relative to container node
# if submitter is a container, returns ""
# if submitter is task, returns leaf part of task node
proc ModuleFlow_searchSubmitter { _submitNodeRecord _flowNodeRecord } {
   ::log::log debug "ModuleFlow_searchSubmitter _submitNodeRecord:${_submitNodeRecord} _flowNodeRecord: ${_flowNodeRecord}"

   if { ${_submitNodeRecord} == "" } {
         return ""
   }

   set foundNode "-1"
   set currentNode ${_submitNodeRecord}
   # get the submits of the current node
   set submitsNode [${currentNode} cget -submits]

   # search for the node
   set searchSubmitNode [file tail ${_flowNodeRecord}]
   set foundIndex [lsearch ${submitsNode} ${searchSubmitNode} ]
   if { ${foundIndex} != -1 } {
      ::log::log debug "ModuleFlow_searchSubmitter found node _submitNodeRecord:${_submitNodeRecord} _flowNodeRecord: ${_flowNodeRecord}"
      if { [ModuleFlow_isContainer ${_submitNodeRecord}] == true } {
         set foundNode ""
      } else {
         set foundNode [file tail ${_submitNodeRecord}]
      }
   } else {
      # not found continue down the path
      set childNodes [${currentNode} cget -children]
      foreach childNode ${childNodes} {
         set fullChildNode ${currentNode}/${childNode}
         set foundNode [ModuleFlow_searchSubmitter ${fullChildNode} ${_flowNodeRecord}]
         if { ${foundNode} != "-1" } {
            break
         }
      }
   }

   return ${foundNode}
}

# this proc returns true if the submitter node that submits _flowNodeRecord
# also submits other nodes
# other returns true...
proc ModuleFlow_hasSubmitSiblings { _flowNodeRecord } {
   if { [ModuleFlow_isExpRootNode ${_flowNodeRecord}] } {
      return false
   }

   set hasSiblings false
   set submitterRecord [ModuleFlow_getSubmitter ${_flowNodeRecord}]
   if { ${submitterRecord} != "" } {
      if { [llength [${submitterRecord} cget -submits]] > 1 } {
         set hasSiblings true
      }
   }
   return ${hasSiblings}
}

# add specific prefix to avoid name class with other records since
# a record name automatically becomes a tcl command
# flow node record is composed of mnode_${checksum_exppath}_${flow_node}
# i.e. mnode_123456_/enkf_mod/assim/gem_mod
proc ModuleFlow_getRecordName { _expPath _nodeName } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]

   ::log::log debug "ModuleFlow_getRecordName _nodeName:${_nodeName}"
   set prefix mnode_${expChecksum}_
   if { [string first ${prefix} ${_nodeName}] == -1 } {
      return ${prefix}${_nodeName}
   }
   return ${_nodeName}
}

# gets the node name from a record_name
# flow node record is composed of mnode_${checksum_exppath}_${flow_node}
# i.e. mnode_123456_/enkf_mod/assim/gem_mod
# would return /enkf_mod/assim/gem_mod
proc ModuleFlow_record2NodeName { _recordName } {
   ::log::log debug "ModuleFlow_record2NodeName _recordName:${_recordName}"
   set scannedItems [scan ${_recordName} "mnode_%d_%s" moduleid nodeName]
   if { ${scannedItems} == 2 } {
      return ${nodeName}
   } else {
      return ${_recordName}
   }
}

# change the status field of the node
# if _isRecursive is true, sets the new status value
# for all child nodes as well
proc ModuleFlow_changeStatus { _expPath _flowNode _newStatus {_isRecursive true}} {
   set flowNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_flowNode}]
   if { ${_isRecursive} == true } {
      # set child nodes status first
      foreach childName [${flowNodeRecord} cget -children] {
         set childNode ${_flowNode}/${childName}
         ModuleFlow_changeStatus ${_expPath} ${childNode} ${_newStatus} ${_isRecursive}
      }
   }
   ${flowNodeRecord} configure -status ${_newStatus}
}

# recursively deletes all records from a module down
# following the container relations
proc ModuleFlow_deleteRecord { _expPath _flowNode {_isRecursive true}} {
   set flowNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_flowNode}]
   if { ${_isRecursive} == true } {
      # remove child nodes first
      foreach childName [${flowNodeRecord} cget -children] {
         set childNode ${_flowNode}/${childName}
         ModuleFlow_deleteRecord ${_expPath} ${childNode} ${_isRecursive}
      }
   }
   ::log::log debug "ModuleFlow_deleteRecord delete instance ${flowNodeRecord}"
   record delete instance ${flowNodeRecord}
}

# this deletes any module flow records that is defined
# for a specific module node
# It does not care about the container relationship between the nodes;
# This should be called when the user is done managing an experiment
# and the env needs to be cleaned up
proc ModuleFlow_cleanRecords { _expPath _flowNode } {
   set expId [ExpLayout_getExpChecksum ${_expPath}]
   
   ::log::log debug "ModuleFlow_cleanRecords delete instance ${_flowNode}"
   # get all the records defined for the module node
   # with respect to the current experiment
   set nodeRecords [info commands ::mnode_${expId}_${_flowNode}*]
   foreach nodeRecord ${nodeRecords} {
      if { [record exists instance ${nodeRecord}] } {
         # we only want to delete the real node records and not the
         # ones that appear in the info commands but are not really records.
         record delete instance ${nodeRecord}
      }
   }
}

# this function is called to set the edited state to true when
# a node is added or deleted to a module flow
proc ModuleFlow_setModuleChanged { _expPath _moduleNode _isChanged } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]

   # when the flow is changed, the following global var is set to true
   # the module flow listens to this var to notify the user when
   # he refreshes or quit the module flow window
   global ${moduleId}_FlowChanged
   set ${moduleId}_FlowChanged ${_isChanged}
}

proc ModuleFlow_isModuleChanged { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_FlowChanged
   if { [info exists ${moduleId}_FlowChanged] } {
      return [set ${moduleId}_FlowChanged]
   }
   return false
}

# returns true if module node i being created and has not been saved yet
# returns false otherwise
proc ModuleFlow_isModuleNew { _expPath _moduleNode } {
   set flowNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   ::log::log debug "ModuleFlow_isModuleNew ${_expPath} ${_moduleNode} flowNodeRecord=${flowNodeRecord}"
   if { [record exists instance ${flowNodeRecord}] && [${flowNodeRecord} cget -status] == "new" } {
      return true
   }
   return false
}

proc ModuleFlow_cleanup { _expPath _moduleNode } {
   set moduleId [ExpLayout_getModuleChecksum ${_expPath} ${_moduleNode}]
   global ${moduleId}_FlowChanged

   catch { unset ${moduleId}_FlowChanged }
}

proc ModuleFlow_printNode { _domNode } {
   puts "ModuleFlow_printNode"
   puts "nodeName: [${_domNode} nodeName]"
   puts "nodeType: [${_domNode} nodeType]"
   puts "nodeValue: [${_domNode} nodeValue]"
   puts "name attribute: [${_domNode} getAttribute name]"
   puts "version_number attribute: [${_domNode} getAttribute version_number "" ]"
   puts "date attribute: [${_domNode} getAttribute date]"
   #puts "nodeType: [${_domNode} nodeType]"
   #puts "nodeType: [${_domNode} nodeType]"
}
