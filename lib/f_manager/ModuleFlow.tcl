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
# flow_path - value of the full node withouth the record id in front example: /enkf_mod/avg_anal_mod/gem/Transfer 
# children - contained children (full name).
#           the parent & children relation allows us to walk down a tree
#           as the sequencer would see it.
# type  - string representing node type (FamilyNode, ModuleNode, etc)
# submits - flow children, nodes submitted by current node (values is leaf part of node i.e. see name attribute)
# submitter - node that submits the current node; 
#                 This value is empty if the submitter is the parent container, it has a value only if the submitter is a task
#                 and the value of the submitter is then the name of the task node (not the full node)
#                 if the node is submitted by a task, then the submitter is 
#                 the submitter task which is different than the parent which must
#                 be of type container
#                 The submits & submitter relation allows us to walk down
#                 a tree as it is shown by the GUI.
#
# deps - Stores node internal dependencies coming from module flow.xml
#        Does not store dependencies from resource.xml file
#        format is a list of list in the following form {type node status index local_index hour exp}
#        ex:
#        { node /SHOP/GeneratePngWIS84 end "" "" "" "" }
#        { node /SHOP/GeneratePngWIS85a end "" "" "" "" }
#        { node /SHOP/GeneratePngWIS85b end "" "" "" "" }
#        { node /SHOP/GeneratePngWIS86 end "" "" "" "" }
#
# status - i'm using this to know whether a node has just been created by the user
#          or not; current possible values "normal" | "new"
# is_work_unit - true means the container is a work_unit, all child nodes will be submitted
#                as single reservation i.e. supertask
# switch_mode   - switching_mode for switch nodes "DatestampHour" or "DayOfWeek"
# 
# switch_items - for switching node, defines the switching items
#
# curselection - for a switch node, this is the current selected switch items
#                for other nodes, it is used to know if the node belongs to a switching branch
record define FlowNode {
   name
   flow_path
   children
   type
   submits
   submitter
   { deps {} }
   { status normal }
   { work_unit false }
   { switch_mode "" }
   { switch_items {} }
   { curselection "" }
}

record define LoopNode {
   {record FlowNode flow}
}

proc ModuleFlow_getXmlTypeFromNode { _nodeType } {
   set value [ModuleFlow_getTypeMapping ${_nodeType} xmltype]
   return $value
}

proc ModuleFlow_getNodeTypeFromXml { _nodeType } {
   set value [ModuleFlow_getTypeMapping ${_nodeType} nodetype]
   return $value
}

proc ModuleFlow_getTypeMapping { _key _direction } {
   global FlowNode2XmlMapping Xml2FlowNodeMapping
   if { ! [info exists FlowNode2XmlMapping] } {
      set FlowNode2XmlMapping {   TaskNode TASK 
                              FamilyNode FAMILY 
                              LoopNode LOOP
                              ModuleNode MODULE
                              NpassTaskNode NPASS_TASK
                              SwitchNode SWITCH
                              SwitchItem SWITCH_ITEM
                        }

      set Xml2FlowNodeMapping {   TASK TaskNode
                              FAMILY FamilyNode
                              LOOP LoopNode
                              MODULE ModuleNode
                              NPASS_TASK NpassTaskNode
                              SWITCH SwitchNode
                              SWITCH_ITEM SwitchItem
                        }
   }
   if { ${_direction} == "xmltype" } {
      set value [string map ${FlowNode2XmlMapping} ${_key}]
   } else {
      set value [string map ${Xml2FlowNodeMapping} ${_key}]
   }
   return ${value}
}

proc ModuleFlow_getXmlSwitchModeFromNode { _nodeSwitchMode } {
   global FlowNode2XmlSwitchMode
   if { ! [info exists FlowNode2XmlSwitchMode] } {
      set FlowNode2XmlSwitchMode { DatestampHour datestamp_hour
                                   DayOfWeek day_of_week
                                   DayOfMonth day_of_month
                                 }
   }
   set value [string map ${FlowNode2XmlSwitchMode} ${_nodeSwitchMode}]
}

proc ModuleFlow_getNodeSwitchModeFromXml { _xmlSwitchMode } {
   global Xml2FlowNodeSwitchMode
   if { ! [info exists FlowNode2XmlSwitchMode] } {
      set Xml2FlowNodeSwitchMode { datestamp_hour DatestampHour
                                   day_of_week DayOfWeek
                                   day_of_month DayOfMonth
                                 }
   }
   set value [string map ${Xml2FlowNodeSwitchMode} ${_xmlSwitchMode}]
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
   ModuleFlow_flowNodeRecord2Xml ${_modRootFlowNode} ${xmlDoc} "" ${_modRootFlowNode}
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

proc ModuleFlow_flowNodeRecord2Xml { _flowNodeRecord _xmlDoc _xmlParentNode _modRootFlowNode } {

   ::log::log debug "ModuleFlow_flowNodeRecord2Xml _flowNodeRecord:${_flowNodeRecord}"
   set nodeType [${_flowNodeRecord} cget -type]
   set xmlNodeName [ModuleFlow_getXmlTypeFromNode ${nodeType}]

   ::log::log debug "ModuleFlow_flowNodeRecord2Xml xmlNodeName:${xmlNodeName}"
   if {  ${_xmlParentNode} == "" } {
      # first node creation
      set xmlRootNode [${_xmlDoc} documentElement]
      set xmlDomNode ${xmlRootNode}
      # xmlParentNode is for recursive call
      set xmlParentNode ${xmlRootNode}
   } else {
      set xmlDomNode [${_xmlDoc} createElement ${xmlNodeName}]
      ${_xmlParentNode} appendChild ${xmlDomNode}
   }

   ${xmlDomNode} setAttribute name [${_flowNodeRecord} cget -name]
   if { [${_flowNodeRecord} cget -work_unit] == true } {
      ${xmlDomNode} setAttribute work_unit 1
   }

   # save internal dependencies
   ModuleFlow_dependencies2Xml ${_xmlDoc} ${xmlDomNode} ${_flowNodeRecord}

   if { ${nodeType} == "SwitchNode" } {
      ${xmlDomNode} setAttribute type [ModuleFlow_getXmlSwitchModeFromNode [${_flowNodeRecord} cget -switch_mode]]
      foreach switchItem [${_flowNodeRecord} cget switch_items] {
         set xmlSwitchItemNode [${_xmlDoc} createElement SWITCH_ITEM]
         ${xmlSwitchItemNode} setAttribute name ${switchItem}
         ${xmlDomNode} appendChild ${xmlSwitchItemNode}
         # need to set the curselection to be able to collect the submit records
         # for each switch items
         ${_flowNodeRecord} configure -curselection ${switchItem}
         foreach submitNodeRecord [ModuleFlow_getSubmitRecords ${_flowNodeRecord}] {
            ModuleFlow_addXmlSubmitTag ${_xmlDoc} ${xmlSwitchItemNode} ${submitNodeRecord}
            ModuleFlow_flowNodeRecord2Xml ${submitNodeRecord} ${_xmlDoc} ${xmlSwitchItemNode} ${_modRootFlowNode} 
         }
      }
      return
   }

   # we stop here for module node that is not root node
   if { ${nodeType} != "ModuleNode" || ${_modRootFlowNode} == ${_flowNodeRecord} } {
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
            ModuleFlow_flowNodeRecord2Xml ${submitNode} ${_xmlDoc} ${xmlDomNode} ${_modRootFlowNode} 
         } else {
            # following nodes belong to the previous container node
            ModuleFlow_flowNodeRecord2Xml ${submitNode} ${_xmlDoc} ${_xmlParentNode} ${_modRootFlowNode} 
         }
      }
   }
}

# converts the dependencies of the node to xml
#
proc ModuleFlow_dependencies2Xml { _xmlDoc _xmlDomNode _flowNodeRecord } {
   set dependencyList [${_flowNodeRecord} cget -deps]
   set nameList {type dep_name status index local_index hour exp}
   foreach dependEntry ${dependencyList} {
      set xmlDependsNode [${_xmlDoc} createElement DEPENDS_ON]
      set count 0
      foreach attrName ${nameList} {
         set attrValue [lindex ${dependEntry} ${count}]
         if { ${attrValue} != "" } {
            ${xmlDependsNode} setAttribute ${attrName} ${attrValue}
         }
	 incr count
      }
      ${_xmlDomNode} appendChild ${xmlDependsNode}
   }
}

proc ModuleFlow_addXmlSubmitTag { _xmlDoc _xmlDomNode _submitFlowNodeRecord } {
   # create submit tag
   set xmlSubmitNode [${_xmlDoc} createElement SUBMITS]
   ${_xmlDomNode} appendChild ${xmlSubmitNode}
   ${xmlSubmitNode} setAttribute sub_name [${_submitFlowNodeRecord} cget -name]
   switch [${_submitFlowNodeRecord} cget -type] {
      NpassTaskNode {
         # set this attribute so that the npass task is not submitted by the sequencer
         ${xmlSubmitNode} setAttribute type "user"
      }
   }
}

# _modName is used only for a module node reference, when
# the name is different than the reference leaf part
proc ModuleFlow_parseXmlNode { _expPath _domNode _parentFlowRecord {_isXmlRootNode false} { _modName "" } } {
   ::log::log debug "ModuleFlow_parseXmlNode _parentFlowRecord:${_parentFlowRecord}"
   set xmlNodeName [${_domNode} nodeName]
   set isWorkUnit false
   if { [${_domNode} nodeType] == "ELEMENT_NODE" } {
      set workUnitValue [${_domNode} getAttribute work_unit false]
      if { ${workUnitValue} == 1 } {
         set isWorkUnit true
      }
   }

   if { ${_parentFlowRecord} == "" } {
      set parentFlowNode ""
   } else {
      set parentFlowNode [${_parentFlowRecord} cget -flow_path]
   }

   set flowNode ""
   ::log::log debug "ModuleFlow_parseXmlNode xmlNodeName:${xmlNodeName}"
   if { ${xmlNodeName} == "MODULE" && ${_isXmlRootNode} == false } {
      # don't process the referenced module node
      # go read the module flow
      set nodeName [${_domNode} getAttribute name]
      set moduleNode ${parentFlowNode}/${nodeName}
      # need to create a record here to store the work_unit value of the module which is kept in the calling node rather than
      # where the module is defined
      ::log::log debug "ModuleFlow_parseXmlNode xmlNodeName:${xmlNodeName} flow node record:[ModuleFlow_getRecordName ${_expPath} ${parentFlowNode}/${nodeName}] -name ${nodeName} -type [ModuleFlow_getNodeTypeFromXml ${xmlNodeName}] -work_unit ${isWorkUnit} -flow_path ${parentFlowNode}/${nodeName}"
      FlowNode [ModuleFlow_getRecordName ${_expPath} ${parentFlowNode}/${nodeName}] -name ${nodeName} -type [ModuleFlow_getNodeTypeFromXml ${xmlNodeName}] \
         -work_unit ${isWorkUnit} -flow_path ${parentFlowNode}/${nodeName}

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
      "SWITCH" -
      "TASK" -
      "NPASS_TASK" {
         set nodeName [${_domNode} getAttribute name]
         set flowNode ${parentFlowNode}/${nodeName}
         if { ${_modName} != "" } {
            set flowNode ${parentFlowNode}/${_modName}
         }
         set nodeType [ModuleFlow_getNodeTypeFromXml ${xmlNodeName}]  
         set recordName [ModuleFlow_getRecordName ${_expPath} ${flowNode}]
         ::log::log debug "ModuleFlow_parseXmlNode xmlNodeName:${xmlNodeName} flowNode:${flowNode} nodeName:${nodeName} nodeType:${nodeType}"
         # submit parent is relative to parent container node
         if { ${xmlNodeName} == "MODULE" && [record exists instance ${recordName}] } {
            ${recordName} configure -submitter [ModuleFlow_searchSubmitter ${_parentFlowRecord} ${recordName}]
         } else {
            ::log::log debug "ModuleFlow_parseXmlNode flow node record:${recordName} -name [file tail ${flowNode}] -type ${nodeType} -flow_path ${flowNode}"
            FlowNode ${recordName} -name [file tail ${flowNode}] -type ${nodeType} -submitter [ModuleFlow_searchSubmitter ${_parentFlowRecord} ${recordName}] -work_unit ${isWorkUnit} -flow_path ${flowNode}
         }

         if { ${parentFlowNode}  != "" } {
            ModuleFlow_addChildNode ${_parentFlowRecord} ${recordName}
         }
	 ModuleFlow_xmlParseDependencies ${recordName} ${_domNode}
      }
      default {
      }
   }

   switch ${xmlNodeName} {
      "MODULE" {
         # build module tree
         # need to get the parent module
         # the record of the module node in the exp tree is build using the exp node name
         # but with a different prefix to avoid name clash
         set parentModTreeName ""
         if { ${_parentFlowRecord} != "" } {
            set parentModule [ModuleFlow_getModuleContainer ${recordName}]
            set parentModName [ModuleFlow_record2NodeName ${parentModule}]
            set parentModTreeName [ExpModTree_getRecordName ${_expPath} ${parentModName}]
            set flowNode [ModuleFlow_record2NodeName ${recordName}]
         }
         # if the node is within a switch branch, at the module tree level, it doesn't care
         # so we get the real layout node (i.e. withouth any notion of switching branching)
         # set layoutNode [ModuleFlow_getLayoutNode ${recordName}]
         ExpModTree_addModule ${_expPath} ${flowNode} ${parentModTreeName} ${nodeName}
      }
      "SWITCH" {
         # ${recordName} configure -switch_mode [ModuleFlow_getNodeSwitchModeFromXml [${_domNode} getAttribute type datestamp_hour]]
         ModuleFlow_parseSwitchingNode ${_expPath} ${recordName} ${_domNode}
      }
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

# _flowNodeRecord must be record for an instance of a switching node
# _xmlNode is the xml dom node of the switching record in the flow.xml file
proc ModuleFlow_parseSwitchingNode { _expPath _flowNodeRecord _xmlNode } {
   # puts "ModuleFlow_parseSwitchingNode _flowNodeRecord:${_flowNodeRecord}"
   # get the switching mode
   set switchMode [ModuleFlow_getNodeSwitchModeFromXml [${_xmlNode} getAttribute type datestamp_hour]]
   ${_flowNodeRecord} configure -switch_mode ${switchMode}
   # get the switching items
   set switchItems {}
   set switchingItemXmlNodes [${_xmlNode} selectNodes SWITCH_ITEM]
   set flowNode [${_flowNodeRecord} cget -flow_path]
   foreach switchItemXmlNode ${switchingItemXmlNodes} {
      set switchItemNodeName [${switchItemXmlNode} getAttribute name ""]
      if { ${switchItemNodeName} != "" } {
         lappend switchItems ${switchItemNodeName}
         set switchItemRecord ${_flowNodeRecord}/${switchItemNodeName}
         FlowNode ${switchItemRecord} -name ${switchItemNodeName} -type SwitchItem -flow_path ${flowNode}/${switchItemNodeName}
         # puts "ModuleFlow_parseSwitchingNode FlowNode ${switchItemRecord} -name ${switchItemNodeName} -type SwitchItem -flow_path ${flowNode}/${switchItemNodeName}"

         # process child nodes
         if { ${flowNode} != "" } {
            ModuleFlow_xmlParseSubmits ${switchItemRecord} ${switchItemXmlNode}
            if { [${switchItemXmlNode} hasChildNodes] } {
               set xmlChildren [${switchItemXmlNode} childNodes]
               foreach xmlChild $xmlChildren {
                  ModuleFlow_parseXmlNode ${_expPath} $xmlChild ${switchItemRecord} false
               }
            }
         }
      }
   }
   ${_flowNodeRecord} configure -switch_items ${switchItems} -curselection [lindex ${switchItems} 0] 
   # puts "ModuleFlow_parseSwitchingNode _flowNodeRecord:[${_flowNodeRecord} configure]"
}

# get the submits relation of an xml node
#
proc ModuleFlow_xmlParseSubmits { _flowNodeRecord _xmlNode } {
   set submitNodes [${_xmlNode} selectNodes SUBMITS]
   set flowChildren ""
   if { [ModuleFlow_isContainer ${_flowNodeRecord}] == false } {
      set submitParent [ModuleFlow_getContainer ${_flowNodeRecord}]
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

proc ModuleFlow_xmlParseDependencies { _flowNodeRecord _xmlNode } {
   set depXmlNodes [${_xmlNode} selectNodes DEPENDS_ON]
   set depsList {}
   # list of attributes supported for dependency
   # set attributeNames [list dep_name status type index local_index hour exp]
   foreach depXmlNode ${depXmlNodes} {
      set depList {}
      set typeValue [${depXmlNode} getAttribute type ""]
      set depNameValue [${depXmlNode} getAttribute dep_name ""]
      set statusValue [${depXmlNode} getAttribute status ""]
      set indexValue [${depXmlNode} getAttribute index ""]
      set localIndexValue [${depXmlNode} getAttribute local_index ""]
      set expValue [${depXmlNode} getAttribute exp ""]
      set hourValue [${depXmlNode} getAttribute hour ""]

      lappend depsList [list ${typeValue} ${depNameValue} ${statusValue} ${indexValue} ${localIndexValue} ${hourValue} ${expValue}]
   }
   ::log::log debug "ModuleFlow_xmlParseDependencies _flowNodeRecord:${_flowNodeRecord} _xmlNode:${_xmlNode} depsList:$depsList"
   ${_flowNodeRecord} configure -deps ${depsList}
   return ${depsList}
}

# refreshes the module flow by deleting all records
# belonging to the node and rereading the xml flow
# This is required for instance when a user refreshes or exits
# a modified flow withouth saving...
#
proc ModuleFlow_refresh { _expPath _moduleNode } {
   ::log::log debug "ModuleFlow_refresh _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set modNodeRecord [ModuleFlow_getRecordName ${_expPath} ${_moduleNode}]
   set parentNodeRecord [ModuleFlow_getContainer ${modNodeRecord}]

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
# _extraArgList is a name value list to allow the passing of additional data needed on a per type basis
#               The  _extraArgList must be convertible to an array
# extra parameters supported per type:
# Containers:
#    is_work_unit true|false
# ModuleNode:
#    use_mod_link true|false indicates whether or not to use a link to
#                            create the module instead of creating  a local module
#    mod_path module_path, refers to the path of the module i.e. /home/binops/afsi/sio/components/modules/gem_mod
# SwitchNode:
#    switchMode
proc ModuleFlow_createNewNode { _expPath _currentNodeRecord _newName _nodeType _insertPosition _extraArgList } {
   ::log::log debug "ModuleFlow_createNewNode _currentNodeRecord:${_currentNodeRecord} _newName:${_newName} _nodeType:${_nodeType} _insertPosition:${_insertPosition} _extraArgList:${_extraArgList}"

   array set extraArgs ${_extraArgList}

   # if parent is not container, get the container
   if { ${_insertPosition} == "parent" } {
      set containerNodeRecord [ModuleFlow_getContainer ${_currentNodeRecord}]
   } else {
      if { [ModuleFlow_isContainer ${_currentNodeRecord}] == true } {
         set containerNodeRecord ${_currentNodeRecord}
      } else {
         set containerNodeRecord [ModuleFlow_getContainer ${_currentNodeRecord}]
      }
   }

   if { [${_currentNodeRecord} cget -type] == "SwitchNode" } {
      set currentSwitchItem [${_currentNodeRecord} cget -curselection]
      set newNodeRecord ${_currentNodeRecord}/${currentSwitchItem}/${_newName}
      set newNode [${_currentNodeRecord} cget -flow_path]/${currentSwitchItem}/${_newName}
      set containerNodeRecord ${_currentNodeRecord}/${currentSwitchItem}
   } else {
      set newNodeRecord [ModuleFlow_getRecordName ${_expPath} ${containerNodeRecord}]/${_newName}
      set newNode [${containerNodeRecord} cget -flow_path]/${_newName}
   }

   if { [record exists instance ${newNodeRecord}] } {
      error NodeDuplicate
      return
   }

   set isWorkUnit $extraArgs(is_work_unit)


   # create new node
   ::log::log debug "ModuleFlow_createNewNode flow node record:${newNodeRecord} -name ${_newName} -type ${_nodeType} -flow_path ${newNode}"
   FlowNode ${newNodeRecord} -name ${_newName} -type ${_nodeType} -status new -work_unit ${isWorkUnit} -flow_path ${newNode}
   # special case for SwitchNode: switch_items must also be created
   if { ${_nodeType} == "SwitchNode" } {
      set switchMode $extraArgs(switch_mode)
      set switchItems $extraArgs(switch_items)
      ::log::log debug "ModuleFlow_createNewNode ${newNodeRecord} configure -switch_mode ${switchMode} -switch_items ${switchItems}"
      ${newNodeRecord} configure -switch_mode ${switchMode} -switch_items ${switchItems}
      if { ${switchItems} != "" } {
         ${newNodeRecord} configure curselection [lindex  ${switchItems} 0]
      }
      foreach switchItem ${switchItems} {
         # I create a node for each switch item
         set switchItemRecord ${newNodeRecord}/${switchItem}
         ::log::log debug "ModuleFlow_createNewNode FlowNode ${switchItemRecord} -name ${switchItem} -type SwitchItem -flow_path ${newNode}"
         FlowNode ${switchItemRecord} -name ${switchItem} -type SwitchItem -flow_path ${newNode}/${switchItem}
      }
   }

   set parentModRecord [ModuleFlow_getModuleContainer ${newNodeRecord}]
   set moduleNode [ModuleFlow_record2NodeName ${parentModRecord}]

   # create node in modules directory
   set moduleLayoutNode [ModuleFlow_getLayoutNode ${parentModRecord}] 
      set useModLink false
      set modPath ""
      if { [ModuleFlow_getNodeRefCount ${newNodeRecord}] == 0 } {
         if { ${_nodeType} == "ModuleNode" } {
            # only create the module layout node if not already exists
            set useModLink $extraArgs(use_mod_link)
            set modPath $extraArgs(mod_path)
            ModuleFlowControl_addPostSaveCmd ${_expPath} ${moduleNode} \
               [list ModuleLayout_createNode ${_expPath} ${moduleLayoutNode} \
               [ModuleFlow_getLayoutNode ${newNodeRecord}] ${_nodeType} ${_extraArgList}]
         } else {
            # For switching items, I don't create the layout node if it's already there
            ModuleLayout_createNode ${_expPath} ${moduleLayoutNode} [ModuleFlow_getLayoutNode ${newNodeRecord}] ${_nodeType} ${_extraArgList}
         }
      } else {
         ::log::log debug "ModuleFlow_createNewNode not creating layout for node: ${newNodeRecord}"
      }
   # attach to submitter
   set insertParentPos ${_insertPosition}
   set nodeRecordsToDelete {}

   switch ${_insertPosition} {
      serial {
         set insertParentPos 0
         # we need to shift all nodes to the right; they become new submits
         # of the new node
         # - assign all submits of the current node to the new node
         set submittedNodeRecords [ModuleFlow_getSubmitRecords ${_currentNodeRecord}]
         set childPosition 0
         if { [${newNodeRecord} cget -type] == "SwitchNode" } {
            # get all switching items
            set switchingItemsNodeRecords [ModuleFlow_getAllSwitchItemFlowNodeRecord ${newNodeRecord}]
            ::log::log debug "ModuleFlow_createNewNode switchingItemsNodeRecords: ${switchingItemsNodeRecords}"
            # assign the nodes to each one of the switching items
            foreach switchingItemsNodeRecord ${switchingItemsNodeRecords} {
               set childPosition 0
               foreach submitNodeRecord ${submittedNodeRecords} {
                  ModuleFlow_addSubmitNode ${switchingItemsNodeRecord} ${submitNodeRecord} ${childPosition}
                  incr childPosition
               }
            }
         } else {
            foreach submitNodeRecord ${submittedNodeRecords} {
               ModuleFlow_addSubmitNode ${newNodeRecord} ${submitNodeRecord} ${childPosition}
               incr childPosition
            }
         }

         # - assign the new node as the only submitted node of current node
         if { [${_currentNodeRecord} cget -type] == "SwitchNode" } {
            # for switchnode, the submitter is really inside the switch item
            set switchItemRecord [ModuleFlow_getCurrentSwitchItemRecord ${_currentNodeRecord}]
            ${switchItemRecord} configure -submits ""
            ModuleFlow_addSubmitNode ${switchItemRecord} ${newNodeRecord}
         } else {
            ${_currentNodeRecord} configure -submits ""
            ModuleFlow_addSubmitNode ${_currentNodeRecord} ${newNodeRecord}
         }

         # if new node is container need to re-assign children at the container level
         # - all submitted nodes of the current node (until the next container) become submitted nodes of the new node
         # - All submitted nodes (to the right) of the new container nodes needs to be renamed
         # because the record name is built using the experiment containment tree (not submit tree)
         if { [ModuleFlow_isContainer ${newNodeRecord}] == true } {
            # I have to go down the submits path until the end or until bumping another container
            if { [${newNodeRecord} cget -type] == "SwitchNode" } {
               set childPosition 0
               foreach submitNodeRecord ${submittedNodeRecords} {
                  ModuleFlow_assignNewContainerDir  ${_expPath} ${moduleNode} ${submitNodeRecord} ${newNodeRecord}
                  incr childPosition
               }
               # get all switching items
               set switchingItemsNodeRecords [ModuleFlow_getAllSwitchItemFlowNodeRecord ${newNodeRecord}]
               ::log::log debug "ModuleFlow_createNewNode switchingItemsNodeRecords: ${switchingItemsNodeRecords}"
               # assign the nodes to each one of the switching items
               foreach switchingItemsNodeRecord ${switchingItemsNodeRecords} {
                  set childPosition 0
                  foreach submitNodeRecord ${submittedNodeRecords} {
                     ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${switchingItemsNodeRecord} ${childPosition} nodeRecordsToDelete
                     incr childPosition
                  }
               }
            } else {
               set childPosition 0
               foreach submitNodeRecord ${submittedNodeRecords} {
                  ModuleFlow_assignNewContainerDir  ${_expPath} ${moduleNode} ${submitNodeRecord} ${newNodeRecord}
                  ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${newNodeRecord} ${childPosition} nodeRecordsToDelete
                  incr childPosition
               }
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
            ModuleFlow_assignNewContainer ${_expPath} ${_currentNodeRecord} ${newNodeRecord} 0 nodeRecordsToDelete
         }
         set containerNodeRecord [ModuleFlow_getContainer ${_currentNodeRecord}]
         set insertParentPos end
      }
      default {
         # add current node as a submitted node to the submitter
         ModuleFlow_addSubmitNode ${_currentNodeRecord} ${newNodeRecord} ${_insertPosition}
      }
   }

   # attach to parent container
   ModuleFlow_addChildNode ${containerNodeRecord} ${newNodeRecord} ${insertParentPos}

   foreach recordToDelete ${nodeRecordsToDelete} {
      record delete instance ${recordToDelete}
   }
}

proc ModuleFlow_copySubmitTree { _sourceFlowNodeRecord _targetFlowNodeRecord } {
   if { ! [record exists instance ${_targetFlowNodeRecord}] } {
      FlowNode ${_targetFlowNodeRecord}
   }
   set parentContainerRecord [ModuleFlow_getContainer ${_targetFlowNodeRecord}]
   set flowPath [${parentContainerRecord} cget -flow_path]/[${_sourceFlowNodeRecord} cget -name]
   ${_targetFlowNodeRecord} configure -children [${_sourceFlowNodeRecord} cget -children] \
      -name [${_sourceFlowNodeRecord} cget -name] \
      -flow_path ${flowPath} \
      -type [${_sourceFlowNodeRecord} cget -type] \
      -submits [${_sourceFlowNodeRecord} cget -submits] \
      -submitter [${_sourceFlowNodeRecord} cget -submitter] \
      -work_unit [${_sourceFlowNodeRecord} cget -work_unit] \
      -switch_mode [${_sourceFlowNodeRecord} cget -switch_mode] \
      -switch_items [${_sourceFlowNodeRecord} cget -switch_items]

   foreach childNodeName [${_sourceFlowNodeRecord} cget -children] {
      set childSourceNodeRecord ${_sourceFlowNodeRecord}/${childNodeName}
      set childTargetNodeRecord ${_targetFlowNodeRecord}/${childNodeName}
      ModuleFlow_copySubmitTree ${childSourceNodeRecord} ${childTargetNodeRecord}
   }
}

# creates a record node for a switching item
# remember that the switching item is a notion that only lives within the flow.xml...
# Besides that, the task and config do not have any knowledge of switching item
proc ModuleFlow_addNewSwitchItem { _flowNodeRecord _newSwitchItem } {
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set newNode [${_flowNodeRecord} cget -flow_path]/${_newSwitchItem}
      set newNodeRecord ${_flowNodeRecord}/${_newSwitchItem}
      ::log::log debug "ModuleFlow_addNewSwitchItem FlowNode ${newNodeRecord} -name ${_newSwitchItem} -type SwitchItem -flow_path ${newNode}"
      if { ! [record exists instance ${newNodeRecord}] } {
         FlowNode ${newNodeRecord} -name ${_newSwitchItem} -type SwitchItem -flow_path ${newNode}
      }
   }
}

# in some cases, there might valeus along the path that are not used in the
# modules layout directory... for instance, switch_items
# This proc removes the nodes that are not seen at the module layout level.
proc ModuleFlow_getLayoutNode { _recordName } {
   set tokenNames [split ${_recordName} /]
   set tokenLength [llength ${tokenNames}]
   set layoutNode /[lindex ${tokenNames} 1]
   if { ${tokenLength} > 2 } {
      set rootNode [lindex ${tokenNames} 0]/[lindex ${tokenNames} 1]
      set workedNode ${rootNode}
      set count 2
      while { ${count} < ${tokenLength} } {
         set token [lindex ${tokenNames} ${count}]
         set workedNode ${workedNode}/${token}
         # puts "workedNode:$workedNode"
         if { [${workedNode} cget -type] != "SwitchItem" } {
            # switch items are not visible within the container directories 
            # only exists in the flow.xml
            set layoutNode ${layoutNode}/${token}
         }
         incr count
      }
   }

   return ${layoutNode}
}

# _deleteBranch can have the following values:
#               - true: for a non-switching node, deletes the whole branch to the right of the node
#               - false: only delete current node
#               - ${switch_item_branch}: for switching node, deletes the selected branch
proc ModuleFlow_deleteNode { _expPath _origFlowNodeRecord _flowNodeRecord {_deleteBranch false} } {
   ::log::log debug "ModuleFlow_deleteNode _origFlowNodeRecord:${_origFlowNodeRecord} _flowNodeRecord:${_flowNodeRecord} _deleteBranch:${_deleteBranch}"

   set submitter [ModuleFlow_getSubmitter ${_flowNodeRecord}]
   set submittedNodeRecords [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set flowNodePosition [ModuleFlow_getSubmitPosition ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]
   set parentContainerRecord [ModuleFlow_getContainer ${_flowNodeRecord}]
   set parentModRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleLayoutNode [ModuleFlow_getLayoutNode ${parentModRecord}] 
   set origModuleNodeRecord [ModuleFlow_getModuleContainer ${_origFlowNodeRecord}]
   set origModuleNode [ModuleFlow_getLayoutNode ${origModuleNodeRecord}]
   set keepChildNodes true

   if { ${nodeType} == "SwitchNode" && ${_deleteBranch} != true && ${_deleteBranch} != false } {
      # we are deleting a switch branch from a switch node

       ::log::log debug "ModuleFlow_deleteNode() deleting switch item ${_deleteBranch}"
      # remove submitted nodes first
      foreach submitNodeRecord ${submittedNodeRecords} {
         ModuleFlow_deleteNode ${_expPath} ${_origFlowNodeRecord} ${submitNodeRecord} true
      }
       ::log::log debug "ModuleFlow_deleteNode() ModuleFlow_removeSwitchItem ${_flowNodeRecord} ${_deleteBranch}"
      # remove switch item
      ModuleFlow_removeSwitchItem ${_flowNodeRecord} ${_deleteBranch}

      return
   }
   set nodeRecordsToDelete {}

   if { ${_deleteBranch} == true } {
      # special case for SwitchNode
      if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
         foreach switchItem [${_flowNodeRecord} cget -switch_items] {
            set switchItemRecord ${_flowNodeRecord}/${switchItem}
            ModuleFlow_deleteNode ${_expPath} ${_origFlowNodeRecord} ${switchItemRecord} ${_deleteBranch}
         }
      } else {
         # remove submitted nodes first
         foreach submitNodeRecord ${submittedNodeRecords} {
            ModuleFlow_deleteNode ${_expPath} ${_origFlowNodeRecord} ${submitNodeRecord} ${_deleteBranch}
         }
      }
      set keepChildNodes false
   } else {

      # special case for switch node
      if { ${nodeType} == "SwitchNode" } {
         # the code iterates through all switch items but the GUI only allows deletion
         # of the node when there is only one item
         foreach switchItem [${_flowNodeRecord} cget -switch_items] {
            set switchItemRecord ${_flowNodeRecord}/${switchItem}
            set childPosition 0
            foreach itemSubmitRecord [ModuleFlow_getSubmitRecords ${switchItemRecord}] {
               # assign new submitter: node that was submitted by switch item to the submitter of the switch node
               ModuleFlow_addSubmitNode ${submitter} ${itemSubmitRecord} ${childPosition}
               # assign new container
               ModuleFlow_assignNewContainer ${_expPath} ${itemSubmitRecord} ${parentContainerRecord} ${childPosition} nodeRecordsToDelete
               incr childPosition
            }
         }
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
               ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${parentContainerRecord} ${childPosition} nodeRecordsToDelete
               incr childPosition
            }
         }

         # if the current node is submitting other nodes, assign those to the submitter of the current node
         set submittedNames [${_flowNodeRecord} cget -submits]
         # assign the new nodes at the same position as the current
         foreach submitName ${submittedNames} {
            set submitNode ${parentContainerRecord}/${submitName}
            ::log::log debug "ModuleFlow_deleteNode ModuleFlow_addSubmitNode ${submitter} ${submitNode} ${flowNodePosition}"
            ModuleFlow_addSubmitNode ${submitter} ${submitNode} ${flowNodePosition}
            incr flowNodePosition
         }
      }
   }

   # check if the layout node should be deleted
   set nodeRefCount [ModuleFlow_getNodeRefCount ${_flowNodeRecord}]

   # all submit nodes are removed, now delete current node
   # - remove node reference from submitter
   ModuleFlow_removeSubmitNode ${submitter} ${_flowNodeRecord}

   # - remove node reference from parent container
   ModuleFlow_removeChild ${parentContainerRecord} ${_flowNodeRecord}

   # get the layout node as seen within the module directory
   set layoutNode [ModuleFlow_getLayoutNode ${_flowNodeRecord}]

   foreach recordToDelete ${nodeRecordsToDelete} {
      record delete instance ${recordToDelete}
   }
   
   if { ${nodeType} == "SwitchNode" } {
      # need to delete switch items first
      foreach switchItem [${_flowNodeRecord} cget -switch_items] {
         set switchItemRecord ${_flowNodeRecord}/${switchItem}
         record delete instance ${switchItemRecord}
      }
   }

   # delete single node
   record delete instance ${_flowNodeRecord}

   # delete node from module container directory only if the current node belongs to the original module.
   # Nodes that belong to a reference module will be cleared at another level if the module reference count
   # is 0
   ::log::log debug "ModuleFlow_deleteNode nodeRefCount:${nodeRefCount}"
   if { ${nodeRefCount} == 0 } {
      # need to check if the node is ready to be deleted from the layout.
      # for nodes belonging to a switch branch, it gets deleted only if it is not used in other
      # branches
      if { ${origModuleNode} == ${moduleLayoutNode} } {
         # delete node and resource
         ::log::log debug "ModuleFlow_deleteNode ModuleLayout_deleteNode 1 ${_expPath} ${moduleLayoutNode} ${layoutNode} ${nodeType} false ${keepChildNodes}"
         ModuleLayout_deleteNode ${_expPath} ${moduleLayoutNode} ${layoutNode} ${nodeType} false ${keepChildNodes}
      } else {
         # delete resource only
         ::log::log debug "ModuleFlow_deleteNode ModuleLayout_deleteNode 2 ${_expPath} ${moduleLayoutNode} ${layoutNode} ${nodeType} false ${keepChildNodes}"
         ModuleLayout_deleteNode ${_expPath} ${moduleLayoutNode} ${layoutNode} ${nodeType} true ${keepChildNodes}
      }
   }
}

proc ModuleFlow_removeSwitchItem { _flowNodeRecord _switchItem } {
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set switchItemRecord [ModuleFlow_getCurrentSwitchItemRecord ${_flowNodeRecord}]
      set switchItems [${_flowNodeRecord} cget -switch_items]
      set index [lsearch ${switchItems} ${_switchItem}]
      if { ${index} != -1 } {
         set switchItems [lreplace ${switchItems} ${index} ${index}]
         ${_flowNodeRecord} configure -switch_items ${switchItems}
         if { [llength ${switchItems}] != 0 } {
            ${_flowNodeRecord} configure -curselection [lindex ${switchItems} 0]
         } else {
            ${_flowNodeRecord} configure -curselection ""
         }
      }
      record delete instance ${switchItemRecord}
   }
}

# returns the reference count of a node EXCLUDING itself.
# i.e. how many times the node is used... Normally should be zero...
# however, for switching node, the same nodes might be used in different switch items.
# if _out_match_record_var is passed, matching node records will be stored in that
# variable as a list
proc ModuleFlow_getNodeRefCount { _flowNodeRecord {_out_match_record_var ""} } {
   if { ${_out_match_record_var} != "" } {
      upvar ${_out_match_record_var} localMatchRecordVar
   }
   # the count reference is only useful for nodes that are submitted by the switch node not for the
   # node itself
   if { [${_flowNodeRecord} cget -type] == "SwitchItem" || [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      return 0
   }

   set layoutNode [ModuleFlow_getLayoutNode ${_flowNodeRecord}]
   set refCount 0
   set switchRecord ""
   set tokenNames [split ${_flowNodeRecord} /]
   set tokenLength [llength ${tokenNames}]
   if { ${tokenLength} > 2 } {
      set rootNode [lindex ${tokenNames} 0]/[lindex ${tokenNames} 1]
      set workedNode ${rootNode}
      set count 2
      while { ${count} < ${tokenLength} } {
         set token [lindex ${tokenNames} ${count}]
         set workedNode ${workedNode}/${token}
         if { [record exists instance ${workedNode}] == 1 && [${workedNode} cget -type] == "SwitchNode" } {
            puts "Got switch node: ${workedNode}"
            set switchRecord ${workedNode}
            break
         }
         incr count
      }
   }
   if { ${switchRecord} != "" } {
      global recordList_${_flowNodeRecord}
      set recordList_${_flowNodeRecord} {}
      ModuleFlow_getAllSwitchingRecords ${switchRecord} recordList_${_flowNodeRecord}
      # puts "set recordList_${_flowNodeRecord} [set recordList_${_flowNodeRecord}]" 
      set recordList [set recordList_${_flowNodeRecord}]
      if { ${recordList} != "" } {
         # compare the list of switch item nodes to see if the current node is used at multiple places
         set refCount 0
         foreach switchItemChildRecord ${recordList} {
            if { [record exists instance ${switchItemChildRecord}] && ${switchItemChildRecord} != ${_flowNodeRecord} } {
               set realNode [ModuleFlow_getLayoutNode ${switchItemChildRecord}]
               if { ${realNode} == ${layoutNode} } {
                  incr refCount
                  lappend localMatchRecordVar ${switchItemChildRecord}
                  puts "found matching record: ${switchItemChildRecord}"
               }
            }
         }
      }
      unset recordList_${_flowNodeRecord}
   }

   ::log::log debug "ModuleFlow_getNodeRefCount _flowNodeRecord:${_flowNodeRecord} returning: ${refCount}"
   return ${refCount}
}

# from a starting node that is a switching node, returns all records
# underneath that node for every switching items
proc ModuleFlow_getAllSwitchingRecords { _flowNodeRecord _outputVar } {
   upvar #0 ${_outputVar} myOutputVar
   # puts "ModuleFlow_getAllSwitchingRecords _flowNodeRecord:${_flowNodeRecord}"
   lappend myOutputVar ${_flowNodeRecord}
   if { [record exists instance ${_flowNodeRecord}] } {
      if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
         set submitRecords [ModuleFlow_getAllSwitchItemFlowNodeRecord ${_flowNodeRecord}] 
      } else {
         set submitRecords [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]
      }
      foreach submitRecord ${submitRecords} {
         ModuleFlow_getAllSwitchingRecords ${submitRecord} ${_outputVar}
      }
   }
}

proc ModuleFlow_renameNode { _expPath _flowNodeRecord _newName } {
   set flowNode [ModuleFlow_record2NodeName ${_flowNodeRecord}]
   set submitter [ModuleFlow_getSubmitter ${_flowNodeRecord}]
   set nodeType [${_flowNodeRecord} cget -type]
   set parentModRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleLayoutNode [ModuleFlow_getLayoutNode ${parentModRecord}] 
   set submittedNodeRecords [ModuleFlow_getSubmitRecords ${_flowNodeRecord}]

   set containerNodeRecord [ModuleFlow_getContainer ${_flowNodeRecord}]
   set newNodeRecord ${containerNodeRecord}/${_newName}
   set newNode [${containerNodeRecord} cget -flow_path]/${_newName}
   
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
      if { [ExpLayout_isModPathExists ${_expPath} ${newNode} ${linkTarget} ${isLink}] == true } {
         error ModulePathExists
      }
   }

   # create new node
   ::log::log debug "ModuleFlow_renameNode FlowNode ${newNodeRecord} -name ${_newName} -type ${nodeType}"
   FlowNode ${newNodeRecord} -name ${_newName} -flow_path ${newNode} -type ${nodeType} -submits [${_flowNodeRecord} cget -submits] -children [${_flowNodeRecord} cget -children] \
      -submitter [${_flowNodeRecord} cget -submitter] -status new -switch_mode [${_flowNodeRecord} cget -switch_mode] -switch_items [${_flowNodeRecord} cget -switch_items] \
      -curselection [${_flowNodeRecord} cget -curselection] -deps [${_flowNodeRecord} cget -deps]

   # the node reference count will help us know wheter we can rename node layout files (.tsk, .cfg) or if we need to make a copy of those
   set nodeRefCount [ModuleFlow_getNodeRefCount ${_flowNodeRecord}]

   # get the layout node as seen within the module directory
   set layoutNode [ModuleFlow_getLayoutNode ${_flowNodeRecord}]

   set nodeRecordsToDelete {}

   # if new node is a container, need to re-assign children at the container level
   # - all submitted nodes until the next container is a new child
   # - All nodes that are children (to the right) of the new container nodes needs to be renamed
   # because the record name is build using the experiment containment tree
   if { [ModuleFlow_isContainer ${newNodeRecord}] == true } {
      # I have to go down the submits path until the end or until bumping another container
      set childPosition 0
      if { ${nodeType} == "SwitchNode" } {
         set switchItems [${_flowNodeRecord} cget -switch_items]
         foreach switchItem ${switchItems} {
            # recreate the switching items
            set newSwitchItemRecord ${newNodeRecord}/${switchItem}
            set oldSwitchItemRecord ${_flowNodeRecord}/${switchItem}
            FlowNode ${newSwitchItemRecord} -name ${switchItem} -flow_path ${newNode}/${switchItem} -type [${oldSwitchItemRecord} cget -type] -submits [${oldSwitchItemRecord} cget -submits] \
               -children [${oldSwitchItemRecord} cget -children] -status new
            # handle the submit of each switching items
            set submitRecords [ModuleFlow_getSubmitRecords ${oldSwitchItemRecord}]
            set childPosition 0
            foreach submitRecord ${submitRecords} {
               ModuleFlow_assignNewContainer ${_expPath} ${submitRecord} ${newSwitchItemRecord} ${childPosition} nodeRecordsToDelete
               incr childPosition
            }
            # remove old switching item record
            record delete instance ${oldSwitchItemRecord}
         }
      } else {
         foreach submitNodeRecord ${submittedNodeRecords} {
            # ModuleFlow_assignNewContainerDir  ${_expPath} ${moduleNode} ${submitNodeRecord} ${newNodeRecord}
            ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${newNodeRecord} ${childPosition} nodeRecordsToDelete
            incr childPosition
         }
      }
   } else {
      # need to change the submitter value of the nodes being submitted by 
      # the current node because the submitter value is non-empty when is it not submitted by a container
      foreach submitRecord ${submittedNodeRecords} {
         ModuleFlow_setSubmitter ${submitRecord} ${newNodeRecord}
      }
   }

   foreach nodeRecordToDelete ${nodeRecordsToDelete} {
      record delete instance ${nodeRecordToDelete}
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
   if { ${nodeRefCount} > 0 } {
      ModuleLayout_renameNode ${_expPath} ${moduleLayoutNode} ${layoutNode} ${_newName} ${nodeType} copy
   } else {
      ModuleLayout_renameNode ${_expPath} ${moduleLayoutNode} ${layoutNode} ${_newName} ${nodeType} move
   }
}

# recursively assigns a new parent container starting from the starting node until
# it hits the end
# - newly given child nodes must be renamed
# - newly given child nodes must be removed from existing parent container
# It follows the submit tree of the starting node but does not change the submits relation
#
proc ModuleFlow_assignNewContainer { _expPath _flowNodeRecord _newContainerRecord _childPosition _out_delete_list_var } {
   upvar ${_out_delete_list_var} localDeleteListVar

   ::log::log debug "ModuleFlow_assignNewContainer _flowNodeRecord:${_flowNodeRecord} _newContainerRecord:${_newContainerRecord}"

   # first the node needs to be removed from its current container node
   ModuleFlow_removeChild [ModuleFlow_getContainer ${_flowNodeRecord}] ${_flowNodeRecord}

   # the node gets the new container parent node
   # since the name of the node is build within the experiment tree, it needs to be changed
   # to take into account the new container in the way
   set newNode [${_newContainerRecord} cget -flow_path]/[${_flowNodeRecord} cget -name]
   set recordName [ModuleFlow_getRecordName ${_expPath} ${_newContainerRecord}/[${_flowNodeRecord} cget -name]]
   FlowNode ${recordName} -name [${_flowNodeRecord} cget -name] -type [${_flowNodeRecord} cget -type] \
      -submits [${_flowNodeRecord} cget -submits] -children [${_flowNodeRecord} cget -children] \
      -submitter [${_flowNodeRecord} cget -submitter] -flow_path ${newNode} -switch_mode [${_flowNodeRecord} cget -switch_mode] \
      -switch_items [${_flowNodeRecord} cget -switch_items] -work_unit [${_flowNodeRecord} cget -work_unit] \
      -curselection [${_flowNodeRecord} cget -curselection] 

   # satisfy same relation on the new container parent node
   # the new child is added to the parent container node
   ModuleFlow_addChildNode ${_newContainerRecord} ${_flowNodeRecord} ${_childPosition}

   # special case for SwitchNode
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      foreach switchItem [${_flowNodeRecord} cget -switch_items] {
         set switchItemRecord ${_flowNodeRecord}/${switchItem}
         ModuleFlow_assignNewContainer ${_expPath} ${switchItemRecord} ${recordName} 0 localDeleteListVar       
      }
   } else {
      # continue down the submit path if not container
      set submits [${_flowNodeRecord} cget -submits]
      set childPosition 0
      foreach submitNode ${submits} {
         if { [ModuleFlow_isContainer ${_flowNodeRecord}] == true } {
            set submitNodeRecord ${_flowNodeRecord}/${submitNode}
            set parentContainerRecord ${recordName}
         } else {
            set parentContainerRecord ${_newContainerRecord}
            set submitNodeRecord [ModuleFlow_getContainer ${_flowNodeRecord}]/${submitNode}
         }
         ModuleFlow_assignNewContainer ${_expPath} ${submitNodeRecord} ${parentContainerRecord} ${childPosition} localDeleteListVar
         incr childPosition
      }
   }

   # delete previous record of the node
   ::log::log debug "ModuleFlow_assignNewContainer deleting record ${_flowNodeRecord}"
   # record delete instance ${_flowNodeRecord}
   lappend localDeleteListVar ${_flowNodeRecord}
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
   set flowNode [ModuleFlow_getLayoutNode ${_flowNodeRecord}]
   set containerNode [ModuleFlow_getLayoutNode ${_newContainerRecord}]
   set parentModRecord [ModuleFlow_getModuleContainer ${_flowNodeRecord}]
   set moduleLayoutNode [ModuleFlow_getLayoutNode ${parentModRecord}]
   set assignMode move
   if { [ModuleFlow_getNodeRefCount ${_flowNodeRecord}] > 0 } {
      set assignMode copy
   }
   ModuleLayout_assignNewContainer ${_expPath} ${moduleLayoutNode} ${containerNode} ${flowNode} [${_flowNodeRecord} cget -type] ${assignMode}
   if { ! [ModuleFlow_isContainer ${_flowNodeRecord}] } {
      set submits [${_flowNodeRecord} cget -submits]
      foreach submitNode ${submits} {
         set submitNodeName [ModuleFlow_getContainer ${_flowNodeRecord}]/${submitNode}
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
      ::log::log debug "ModuleFlow_removeChild ${_flowNodeRecord} configure -children ${newChilds}"
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

# get the node record of the current selection withing a switching node
# for instance, if the current node record is mnode_3187768564_/dummy_mod/f2/newmod/myswitch
# and the current selection is "00", the returned value is mnode_3187768564_/dummy_mod/f2/newmod/myswitch/00
proc ModuleFlow_getCurrentSwitchItemRecord { _flowNodeRecord } {
   set newNodeRecord ""
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set currentSwitchItem [${_flowNodeRecord} cget -curselection]
      if { ${currentSwitchItem} != "" } { 
         set newNodeRecord ${_flowNodeRecord}/${currentSwitchItem}
      }
   }
   return ${newNodeRecord}
}

proc ModuleFlow_getAllSwitchItemFlowNodeRecord { _flowNodeRecord } {
   set records {}
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set switchItems [${_flowNodeRecord} cget -switch_items]
      foreach switchItem ${switchItems} { 
         lappend records ${_flowNodeRecord}/${switchItem}
      }
   }
   return ${records}
}

# returns the node path of the new node to be created based on its parent,
# whether it is a container or not
# _flowNodeRecord is the record of the node submitting the new node
# _newNodeName is the name of the new node, not the full path
# returns node as in /enkf_mod/family_1/node1
proc ModuleFlow_getNewNode { _flowNodeRecord _newNodeName } {
   ::log::log debug "ModuleFlow_getNewNode _flowNodeRecord:${_flowNodeRecord} _newNodeName:${_newNodeName}"
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set currentSwitchItem [${_flowNodeRecord} cget -curselection]
      set newNode [${_flowNodeRecord} cget -flow_path]/${_newNodeName}
   } elseif { [ModuleFlow_isContainer ${_flowNodeRecord}] == true } {
      set newNode [${_flowNodeRecord} cget -flow_path]/${_newNodeName}
   } else {
      set parentContainerRecord [ModuleFlow_getContainer ${_flowNodeRecord}]
      set newNode [${parentContainerRecord} cget -flow_path]/${_newNodeName}
   }
   return ${newNode}
}

# search upwards the node to find the module contianer
proc ModuleFlow_getModuleContainer { _flowNodeRecord } {
   ::log::log debug "ModuleFlow_getModuleContainer _flowNodeRecord:${_flowNodeRecord}"
   set node ${_flowNodeRecord}
   set done false
   set foundNode ""
   while { ${done} == false && ${node} != "" } {
      set parentNode [ModuleFlow_getContainer ${node}]
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
      set parentContainerRecord [ModuleFlow_getContainer ${_flowNodeRecord}]
      if { [${_flowNodeRecord} cget -submitter] == "" && [${parentContainerRecord} cget -type] == "SwitchItem" } {
         set submitterNode ${parentContainerRecord}
      } else {
         set submitterNode [ModuleFlow_getSubmitter ${_flowNodeRecord}]
      }
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
# _all argument is currently used as determinant for switching nodes. If $_all is false,
#      then it returns the submit records of the current selection of the switching node.
#      If $_all is true, it returns the submit records of every switching items.
#
# this function will return the record for node /f1/t2
#
proc ModuleFlow_getSubmitRecords { _flowNodeRecord {_all false}} {
   set newSubmits {}
   set submits [${_flowNodeRecord} cget -submits]
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      if { ${_all} == true } {
         # get all switching items
         set submitterRecords [ModuleFlow_getAllSwitchItemFlowNodeRecord ${_flowNodeRecord}]
         foreach submitterRecord ${submitterRecords} {
            foreach submitNode [${submitterRecord} cget -submits] {
               lappend newSubmits ${_flowNodeRecord}/${submitNode}
            }
         }
         return ${newSubmits}
      } else {
         # get current item selection
         set submitterRecord [ModuleFlow_getCurrentSwitchItemRecord ${_flowNodeRecord}]
         # get submits of current selection
         if { ${submitterRecord} != "" } {
            set submits [${submitterRecord} cget -submits]
            set _flowNodeRecord ${submitterRecord}
         }
      }
   }
   if { [ModuleFlow_isContainer ${_flowNodeRecord}] } {
      set parentContainerRecord ${_flowNodeRecord}
   } else {
      set parentContainerRecord [ModuleFlow_getContainer ${_flowNodeRecord}]
   }
   foreach submitNode ${submits} {
      lappend newSubmits ${parentContainerRecord}/${submitNode}
   }

   ::log::log debug "ModuleFlow_getSubmitRecords _flowNodeRecord:${_flowNodeRecord} newSubmits:${newSubmits}"
   return ${newSubmits}
}

# add node _submitNodeRecord to the list of nodes submitted by _flowNodeRecord at position _position
# _flowNodeRecord & _submitNode are FlowNode records
proc ModuleFlow_addSubmitNode { _flowNodeRecord _submitNodeRecord { _position end } } {
   ::log::log debug "ModuleFlow_addSubmitNode _flowNodeRecord:${_flowNodeRecord} _submitNodeRecord:${_submitNodeRecord} _position:${_position}"
   # attach to submitter
   # submits are stored as relative path to the parent container
# SUA TO BE DONE, this switch logic should be done at the caller maybe... check it out
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set submitterRecord [ModuleFlow_getCurrentSwitchItemRecord ${_flowNodeRecord}]
   } else {
      set submitterRecord ${_flowNodeRecord}
   }
   set currentSubmits [${submitterRecord} cget -submits]
   set currentSubmits [linsert ${currentSubmits} ${_position} [${_submitNodeRecord} cget -name]]
   ${submitterRecord} configure -submits ${currentSubmits}
   ::log::log debug "ModuleFlow_addSubmitNode ${submitterRecord} configure -submits ${currentSubmits}"

   # set the _flowNodeRecord as submit parent of the _submitNode
   ModuleFlow_setSubmitter ${_submitNodeRecord} ${submitterRecord}
}

# remove node _submitNode from the list of nodes submitted by _flowNodeRecord
# _flowNodeRecord & _submitNode are FlowNode records
proc ModuleFlow_removeSubmitNode { _flowNodeRecord _submitNode } {
   ::log::log debug "ModuleFlow_removeSubmitNode _flowNodeRecord:${_flowNodeRecord} _submitNode:${_submitNode}"
   if { [${_flowNodeRecord} cget -type] == "SwitchNode" } {
      set submitterRecord [ModuleFlow_getCurrentSwitchItemRecord ${_flowNodeRecord}]
   } else {
      set submitterRecord ${_flowNodeRecord}
   }
   if { [record exists instance ${submitterRecord}] } {
      # detach from submitter
      set submits [${submitterRecord} cget -submits]
      set submitIndex [lsearch ${submits} [${_submitNode} cget -name]]
      if { ${submitIndex} != -1 } {
         set submits [lreplace ${submits} ${submitIndex} ${submitIndex}]
         ${submitterRecord} configure -submits ${submits}
      }
   }
}

proc ModuleFlow_setSubmitter { _flowNodeRecord _submitterNodeRecord } {
   # submits are stored as relative path to the parent container
   if { [ModuleFlow_isContainer ${_submitterNodeRecord}] == true } {
      ${_flowNodeRecord} configure -submitter ""
      ::log::log debug "ModuleFlow_setSubmitter ${_flowNodeRecord} configure -submitter \"\""
   } else {
      ${_flowNodeRecord} configure -submitter [file tail ${_submitterNodeRecord}]
      ::log::log debug "ModuleFlow_setSubmitter ${_flowNodeRecord} configure -submitter [file tail ${_submitterNodeRecord}]"
   }
}

# returns the node record submitting the given _flowNodeRecord
proc ModuleFlow_getSubmitter { _flowNodeRecord } {
   set parentContainerRecord [ModuleFlow_getContainer ${_flowNodeRecord}]
   if { ${parentContainerRecord} == "" } {
      return ""
   }
   set submitter [file dirname ${_flowNodeRecord}]
   if { [${_flowNodeRecord} cget -submitter] != "" } {
      # submitter is relative to parent container
      set submitter ${submitter}/[${_flowNodeRecord} cget -submitter]
   }
   # if the submitter is empty, it means that it is submitted by the container...
   # if the container is a switch_item, need to shift it to the SwitchNode
   if { [${_flowNodeRecord} cget -submitter] == "" && [[ModuleFlow_getContainer ${_flowNodeRecord}] cget -type] == "SwitchItem" } {
      set submitter [file dirname [file dirname ${_flowNodeRecord}]]
   }

   return ${submitter}
}

proc ModuleFlow_addChildNode { _flowNodeRecord _childNodeRecord { _position end } } {
   # child nodes are stored as relative path to the parent container
   set childrenNodes [${_flowNodeRecord} cget -children]
   if { [lsearch ${childrenNodes} [${_childNodeRecord} cget -name] ] == -1 } {
      set childrenNodes [linsert ${childrenNodes} ${_position} [${_childNodeRecord} cget -name]]
      ::log::log debug "ModuleFlow_addChildNode _flowNodeRecord:${_flowNodeRecord} _childNodeRecord:${_childNodeRecord} childrenNodes:${childrenNodes}"
      ${_flowNodeRecord} configure -children ${childrenNodes}
   }
}

proc ModuleFlow_getContainer { _flowNodeRecord } {
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
   set value [${_recordName} cget -flow_path]
   ::log::log debug "ModuleFlow_record2NodeName _recordName:$_recordName value:$value"
   return ${value}
}

proc ModuleFlow_record2RealNode { _recordName } {
   set _recordName [string trim ${_recordName} ::]
   set tokenNames [split ${_recordName} /]
   set realNode ${_recordName}
   set tokenLength [llength ${tokenNames}]
   if { ${tokenLength} > 2 } {
      set rootNode [lindex ${tokenNames} 0]/[lindex ${tokenNames} 1]
      set workedNode ${rootNode}
      set realNode ${rootNode}
      set count 2
      while { ${count} < ${tokenLength} } {
         set token [lindex ${tokenNames} ${count}]
         set workedNode ${workedNode}/${token}
         if { [${workedNode} cget -type] != "SwitchItem" } {
            set realNode ${realNode}/${token}
         }
         incr count
      }
   }

   set scannedItems [scan ${realNode} "mnode_%d_%s" moduleid nodeName]
   if { ${scannedItems} == 2 } {
      set value ${nodeName}
   } else {
      set value ${_recordName}
   }

   return ${value}
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
      set records [info commands ${flowNodeRecord}/*]
      foreach childRecord $records {
         if { [record exists instance ${childRecord}] == 1 } {
            record delete instance ${childRecord}
         }
      }

      proc out {} {
      foreach childName [${flowNodeRecord} cget -children] {
         set childNode ${_flowNode}/${childName}
         ModuleFlow_deleteRecord ${_expPath} ${childNode} ${_isRecursive}
      }
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

# returns true if module node is being created and has not been saved yet
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

# returns true if one of
# "./" "../" ".../" is found in the given _checkValue
#
# returns false otherwise

proc ModuleFlow_hasRelativeSyntax { _checkNode } {
   ::log::log debug "ModuleFlow_hasRelativeSyntax _checkNode:$_checkNode"
   set splittedNode [split ${_checkNode} /]
   set hasRelativeSyntax false
   set count 0
   while { ${count} < [llength ${splittedNode}] && ${hasRelativeSyntax} == false } {
      set splitPart [lindex ${splittedNode} ${count}]
      foreach checkToken { . .. ... } {
         if { ${splitPart} == ${checkToken} } {
	    set hasRelativeSyntax true
	    break
         }
      }
      incr count
   }
   return ${hasRelativeSyntax}
}

# checks a node that potentially has relative syntaxing
# and computes the resulting node relative
# to the _flowNodeRecord
#
# relative path syntax:
# .    : Used to signify the current container.
# ..   : Used to target the parent container (container of your container).
# ...  : Used to target the module start. If the current node is a module, ... refers to the
#        container module and not the current node.
#
# returns -1 if syntax validation fails
proc ModuleFlow_getFromRelativePath { _expPath _flowNodeRecord _checkNode _outErrMsg } {
   ::log::log debug "ModuleFlow_getFromRelativePath $_expPath $_flowNodeRecord $_checkNode"
   upvar ${_outErrMsg} myOutputErrMsg
   set myOutputErrMsg "Relative syntax can only appear at start of node definition!"

   set splittedNode [split ${_checkNode} /]
   set relativeSyntaxEndReached false

   set hasRelativeSyntax false
   set baseNodeRecord ${_flowNodeRecord}
   set errorFlag false
   set count 0
   foreach checkToken { . .. ... } {
      if { [llength [lsearch -exact -all ${splittedNode} ${checkToken}]] > 1 } {
         set myOutputErrMsg "Relative syntax \"${checkToken}\" can only appear once!"
	 return -1
      }
   }

   while { ${errorFlag} == false && ${count} < [llength ${splittedNode}] } {
      set splitPart [lindex ${splittedNode} ${count}]
      puts "splitPart:${splitPart}"
      switch ${splitPart} {
         "." {
            set hasRelativeSyntax true
	    # get immediate container
	    if { ${relativeSyntaxEndReached} == true } {
	       set errorFlag true
	    } else {
	       set baseNodeRecord [ModuleFlow_getContainer ${baseNodeRecord}]
            }
	 }
         ".." {
            set hasRelativeSyntax true
	    # get container of container
	    if { ${relativeSyntaxEndReached} == true } {
	       set errorFlag true
	    } else {
	       set baseNodeRecord [ModuleFlow_getContainer ${baseNodeRecord}]
	       set baseNodeRecord [ModuleFlow_getContainer ${baseNodeRecord}]
            }
	 }
         "..." {
            set hasRelativeSyntax true
	    if { ${relativeSyntaxEndReached} == true } {
	       set errorFlag true
	    } else {
	       # get the module container
               set baseNodeRecord [ModuleFlow_getModuleContainer ${baseNodeRecord}]
            }
	 }
         "" -
         "/" {
	    # let this one through
	 }
	 default {
	    puts "got ${splitPart}"
	    # relative syntaxing is only supported at the beginning of the node definition so 
	    # once we detect anything that is not relative, we don't allow relative anymore
	    # i.e. syntext ./dummy_node/../whatever is not allowed
	    set relativeSyntaxEndReached true
	    set baseNodeRecord ${baseNodeRecord}/${splitPart}
	 }
      }

      incr count
   }

   puts "ModuleFlow_getFromRelativePath errorFlag:${errorFlag} hasRelativeSyntax:${hasRelativeSyntax} baseNodeRecord:${baseNodeRecord}"
   if { ${errorFlag} == true } {
      return -1
   }

   if { ${hasRelativeSyntax} == true } {
      return ${baseNodeRecord}
   }

   # no relative syntax... return original node
   set recordName [ModuleFlow_getRecordName ${_expPath} ${_checkNode}]
   return ${recordName}
}

# does node info on the node to make sure that it exists
# returns true if node exists, false otherwise
proc ModuleFlow_checkNodeExists { _expPath _node } {
   global env
   set nodeinfoExec nodeinfo
   set isExists false
   # get nodeinfo from SEQ_BIN if exists
   if { [info exists env(SEQ_BIN)] } {
      set nodeinfoExec $env(SEQ_BIN)/nodeinfo
   }
   if { [ catch { 
      set execArgs "export SEQ_EXP_HOME=${_expPath} ; ${nodeinfoExec} -n ${_node} -f type > /dev/null 2>&1"
      puts "ModuleFlow_checkNodeExists ksh -c ${execArgs}"
      MaestroConsole_addMsg "${nodeinfoExec} ksh -c ${execArgs}"
      exec -ignorestderr ksh -c ${execArgs}
      set isExists true
   } errMsg options ] } {
   }
   return ${isExists}
}

proc ModuleFlow_getAllInstances { _expPath } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   set prefix ::mnode_${expChecksum}_
   set nodeList {}
   set rawList [record show instance FlowNode]
   set myListIndex [lsearch -all ${rawList} ${prefix}*]
   foreach nodeIndex ${myListIndex} {
      set node [lindex ${rawList} ${nodeIndex}]
      lappend nodeList [${node} cget -flow_path]
   }
   return ${nodeList}
}

