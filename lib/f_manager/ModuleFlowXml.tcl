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
   puts "ModuleFlowXml_addDependency _xmlDoc:$_xmlDoc _nameValueList:$_nameValueList"
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
      # the type=node and status=end are the only ones supported for now
      # so we hardcode it
      ${depXmlNode} setAttribute type node
      ${depXmlNode} setAttribute status end
 
      ${xmlNode} appendChild ${depXmlNode}
   }
   ::log::log debug "ModuleFlowXml_addDependency _xmlDoc:$_xmlDoc _nameValueList:$_nameValueList DONE"
}

proc ModuleFlowXml_getDependencies { _xmlNode _xmlDoc _moduleNodeRecord _flowNodeRecord } {

   set xmlQuery ""
   if { ${_xmlNode} == "" } {
      # query the xml doc
      # get the query to access the node within the flow.xml
      set xmlQuery [ ModuleFlowXml_getNodeQuery ${_moduleNodeRecord} ${_flowNodeRecord} ]
      set xmlRootNode [${_xmlDoc} documentElement]
      if { ${xmlQuery} != "" } {
         ::log::log debug "ModuleFlowXml_getDependencies xmlQuery:$xmlQuery"
         set xmlNode [${xmlRootNode} selectNodes ${xmlQuery}]
      }
   } else {
      set xmlNode ${_xmlNode}
   }

   set depsList {}
   ::log::log debug "ModuleFlowXml_getDependencies xmlQuery:$xmlQuery"
   ::log::log debug "ModuleFlowXml_getDependencies xmlNode:$xmlNode"
   set depXmlNodes [${xmlNode} selectNodes DEPENDS_ON]
   ::log::log debug "ModuleFlowXml_getDependencies depXmlNodes:$depXmlNodes"
   # list of attributes supported for dependency
   foreach depXmlNode ${depXmlNodes} {
      set depNameValue [${depXmlNode} getAttribute dep_name ""]
      set indexValue [${depXmlNode} getAttribute index ""]
      set localIndexValue [${depXmlNode} getAttribute local_index ""]
      set validDowValue [${depXmlNode} getAttribute valid_dow ""]
      set validHourValue [${depXmlNode} getAttribute valid_hour ""]
      set hourValue [${depXmlNode} getAttribute hour ""]
      set expValue [${depXmlNode} getAttribute exp ""]
      lappend depsList [list ${depNameValue} ${indexValue} ${localIndexValue} ${hourValue} ${validDowValue} ${validHourValue} ${expValue}]
   }
   ::log::log debug "ModuleFlowXml_getDependencies _flowNodeRecord:${_flowNodeRecord}"
   ::log::log debug "ModuleFlowXml_getDependencies depsList: ${depsList}"
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
