# remove all defined dependencies for a node within the module's flow.xml file
#
proc ModuleFlowXml_removeDependencies {_xmlDoc _moduleNodeRecord _flowNodeRecord } {
   # get the query to access the node within the flow.xml
   set xmlQuery [ ModuleFlowXml_getNodeQuery ${_moduleNodeRecord} ${_flowNodeRecord} ]
   set xmlRootNode [${_xmlDoc} documentElement]
  

   if { ${xmlQuery} != "" } {
      ::log::log debug "ModuleFlowXml_removeDependencies xmlQuery:$xmlQuery"
      set xmlNode [${xmlRootNode} selectNodes ${xmlQuery}]
      ::log::log debug "ModuleFlowXml_removeDependencies xmlNode:$xmlNode"
      set depXmlNodes [${xmlNode} selectNodes DEPENDS_ON]
      ::log::log debug "ModuleFlowXml_removeDependencies depXmlNodes:$depXmlNodes"
      foreach depXmlNode ${depXmlNodes} {
         # for some reason, I can't delete the object itself...
	 # when I do so, any "selectNodes" on the same node causes the whole application to crash
	 # So I only remove the reference from the xml node, the rest is cleaned when the doc is deleted
         # ${depXmlNode} delete
         ${xmlNode} removeChild ${depXmlNode}
      }
   }
   ::log::log debug "ModuleFlowXml_removeDependencies DONE"
}

# adds one dependency entry in the flow.xml file for the specified node
# 
# _nameValueList is a name-value list
# possible values of the keys in the name-value list are dep_name, status, type, index, local_index, exp, hour
# example:
# "dep_name /SHOP/GeneratePngWIS86 status end type node"
#
proc ModuleFlowXml_addDependency { _xmlDoc _moduleNodeRecord _flowNodeRecord _nameValueList } {
   ::log::log debug "ModuleFlowXml_addDependency _xmlDoc:$_xmlDoc _nameValueList:$_nameValueList"
   # get the query to access the node within the flow.xml
   set xmlQuery [ ModuleFlowXml_getNodeQuery ${_moduleNodeRecord} ${_flowNodeRecord} ]
   set xmlRootNode [${_xmlDoc} documentElement]

   # puts "ModuleFlowXml_addDependency XML doc: [${_xmlDoc} asXML]"

   if { ${xmlQuery} != "" } {
      ::log::log debug "ModuleFlowXml_addDependency xmlQuery:$xmlQuery"
      set xmlNode [${xmlRootNode} selectNodes ${xmlQuery}]
      ::log::log debug "ModuleFlowXml_addDependency xmlNode:$xmlNode"
      set depXmlNode [${_xmlDoc} createElement DEPENDS_ON]
      ::log::log debug "ModuleFlowXml_addDependency depXmlNode:$depXmlNode"
      foreach {attrName attrValue} ${_nameValueList} {
         if { ${attrValue} != "" } {
            ${depXmlNode} setAttribute ${attrName} ${attrValue}
         }
      }
      ${xmlNode} appendChild ${depXmlNode}
   }
   ::log::log debug "ModuleFlowXml_addDependency _xmlDoc:$_xmlDoc _nameValueList:$_nameValueList DONE"
}

proc ModuleFlowXml_getDependencies { _xmlDoc _moduleNodeRecord _flowNodeRecord } {

   # get the query to access the node within the flow.xml
   set xmlQuery [ ModuleFlowXml_getNodeQuery ${_moduleNodeRecord} ${_flowNodeRecord} ]
   set xmlRootNode [${_xmlDoc} documentElement]

   set depsList {}
   if { ${xmlQuery} != "" } {
      ::log::log debug "ModuleFlowXml_getDependencies xmlQuery:$xmlQuery"
      set xmlNode [${xmlRootNode} selectNodes ${xmlQuery}]
      ::log::log debug "ModuleFlowXml_getDependencies xmlNode:$xmlNode"
      set depXmlNodes [${xmlNode} selectNodes DEPENDS_ON]
      ::log::log debug "ModuleFlowXml_getDependencies depXmlNodes:$depXmlNodes"
      # list of attributes supported for dependency
      # set attributeNames [list dep_name status type index local_index hour exp]
      foreach depXmlNode ${depXmlNodes} {
         set typeValue [${depXmlNode} getAttribute type ""]
         set depNameValue [${depXmlNode} getAttribute dep_name ""]
         set statusValue [${depXmlNode} getAttribute status ""]
         set indexValue [${depXmlNode} getAttribute index ""]
         set localIndexValue [${depXmlNode} getAttribute local_index ""]
         set expValue [${depXmlNode} getAttribute exp ""]
         set hourValue [${depXmlNode} getAttribute hour ""]

         lappend depsList [list ${typeValue} ${depNameValue} ${statusValue} ${indexValue} ${localIndexValue} ${hourValue} ${expValue}]
      }
   }
   return ${depsList}
}

# build the xml query to be used to access the node within
# the module flow.xml file
#
# for a task node named "dummy_task" that sits right under the module,
# the return value should be something like:
# /MODULE/TASK\[@name='dummy_task'\]
#
proc ModuleFlowXml_getNodeQuery { _moduleNodeRecord _flowNodeRecord } {
   # the query always starts with the MODULE tag
   set query /MODULE

   if { ${_moduleNodeRecord} != ${_flowNodeRecord} } {
      # get the relative path of the flownode versus its module node
      set relativePath [::textutil::trim::trimPrefix ${_flowNodeRecord} ${_moduleNodeRecord}/]
      set relativePath [string trim ${relativePath} /]

      ::log::log debug "ModuleFlowXml_getNodeQuery relativePath:$relativePath"
      # get the list of nodes
      set splitList [split ${relativePath} /]
      ::log::log debug "ModuleFlowXml_getNodeQuery splitList:$splitList"
      set queryNodeRecord ${_moduleNodeRecord}

      foreach nodeName ${splitList} {
         # build the record
         set queryNodeRecord ${queryNodeRecord}/${nodeName}
         ::log::log debug "ModuleFlowXml_getNodeQuery queryNodeRecord:$queryNodeRecord"
         set nodeType [${queryNodeRecord} cget -type]
         # get the xml tag
         set xmlNodeName [ModuleFlow_getXmlTypeFromNode ${nodeType}]

         append query /${xmlNodeName}\[@name='${nodeName}'\]
      }
   }

   return ${query}
}