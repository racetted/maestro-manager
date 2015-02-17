package require tdom

proc ResourceXml_parseFile { _resourceFile } {
   ::log::log debug "ResourceXml_parseFile _resourceFile: ${_resourceFile}"
   # MaestroConsole_addMsg "read xml file: ${_resourceFile}"
   if { ! [file readable ${_resourceFile}] } {
      # MaestroConsole_addErrorMsg "xml file not readable: ${_resourceFile}"
      error "Cannot read ${_resourceFile}!"
      return
   }

   if [ catch { set xmlSrc [exec cat ${_resourceFile}] } ] {
      # let caller handle the exception
      MaestroConsole_addErrorMsg "while reading: ${_resourceFile}"
      error "ResourceXml_parseFile error reading XML Document : ${_resourceFile}"
      return
   }
   set xmlSrc [string trim ${xmlSrc}]

   set doc [dom parse ${xmlSrc} ]

   # free the dom tree
   # ${doc} delete
   return ${doc}
}

proc ResourceXml_getAbortActionValue { _xmlDoc } {
   set xmlRootNode [${_xmlDoc} documentElement]
   set actionXmlNode [${xmlRootNode} selectNodes /NODE_RESOURCES/ABORT_ACTION]
   set attributeValue stop
   if { ${actionXmlNode} != "" } {
      set attributeValue [${actionXmlNode} getAttribute name stop]
   }
   return ${attributeValue}
}

proc ResourceXml_setAbortActionValue { _xmlDoc _attrValue } {
   set xmlRootNode [${_xmlDoc} documentElement]
   set actionXmlNode [${xmlRootNode} selectNodes /NODE_RESOURCES/ABORT_ACTION]
   switch ${_attrValue} {
      stop {
         # remove the node
         if { ${actionXmlNode} != "" } {
            ${xmlRootNode} removeChild ${actionXmlNode}
            ${actionXmlNode} delete
         }
      }
      rerun {
         if { ${actionXmlNode} == "" } {
            set actionXmlNode [${_xmlDoc} createElement ABORT_ACTION]
            ${xmlRootNode} appendChild ${actionXmlNode}
         }
         ${actionXmlNode} setAttribute name ${_attrValue}
      }
   }
}

proc ResourceXml_getBatchAttribute { _xmlDoc _attrName {_default_value ""} } {
   set xmlRootNode [${_xmlDoc} documentElement]
   set batchXmlNode [${xmlRootNode} selectNodes /NODE_RESOURCES/BATCH]
   set attributeValue ${_default_value}
   if { ${batchXmlNode} != "" } {
      set attributeValue [${batchXmlNode} getAttribute ${_attrName} ${_default_value}]
   }
   return ${attributeValue}
}

proc ResourceXml_getLoopAttribute { _xmlDoc _attrName {_default_value ""} } {
   set xmlRootNode [${_xmlDoc} documentElement]
   set loopXmlNode [${xmlRootNode} selectNodes /NODE_RESOURCES/LOOP]
   set attributeValue ${_default_value}
   if { ${loopXmlNode} != "" } {
      set attributeValue [${loopXmlNode} getAttribute ${_attrName} ${_default_value}]
   }
   return ${attributeValue}
}

proc ResourceXml_saveLoopAttribute { _xmlDoc _attrName _attrValue } {
   set xmlRootNode [${_xmlDoc} documentElement]
   set loopXmlNode [${xmlRootNode} selectNodes /NODE_RESOURCES/LOOP]
   if { ${loopXmlNode} == "" } {
      set loopXmlNode [${_xmlDoc} createElement LOOP]
      ${xmlRootNode} appendChild ${loopXmlNode}
   }
   if { ${_attrValue} == "" && [${loopXmlNode} hasAttribute ${_attrName}] } {
      ${loopXmlNode} removeAttribute ${_attrName}
   } elseif { ${_attrValue} != "" } {
      ${loopXmlNode} setAttribute ${_attrName} ${_attrValue}
   }
}

proc ResourceXml_saveBatchAttribute { _xmlDoc _attrName _attrValue } {
   set xmlRootNode [${_xmlDoc} documentElement]
   set batchXmlNode [${xmlRootNode} selectNodes /NODE_RESOURCES/BATCH]
   if { ${batchXmlNode} == "" && ${_attrValue} != "" } {
      set batchXmlNode [${_xmlDoc} createElement BATCH]
      ${xmlRootNode} appendChild ${batchXmlNode}
   }
   if { ${_attrValue} == "" && ${batchXmlNode} != "" && [${batchXmlNode} hasAttribute ${_attrName}] } {
      ${batchXmlNode} removeAttribute ${_attrName}
   } elseif { ${_attrValue} != "" } {
      ${batchXmlNode} setAttribute ${_attrName} ${_attrValue}
   }
}

# returns the list of node dependencies
# the list contain entries with the following values in order:
# dependsNode status index local_index hour valid_dow valid_hour exp 
#
#
# example from shop exp:
# resource file dependency content:
#    <DEPENDS_ON dep_name="/SHOP/GeneratePngWIS84" type="node" status="end"/>
#    <DEPENDS_ON dep_name="/SHOP/GeneratePngWIS85a" type="node" status="end"/>
#    <DEPENDS_ON dep_name="/SHOP/GeneratePngWIS85b" type="node" status="end"/>
#    <DEPENDS_ON dep_name="/SHOP/GeneratePngWIS86" type="node" status="end"/>
#
# returned value from ResourceXml_getDependencyList:
#  { $node $index $local_index $hour $valid_dow $valid_hour $exp
#
# { /SHOP/GeneratePngWIS84 "" "" "" "" "" ""}
# { /SHOP/GeneratePngWIS85a "" "" "" "" "" ""}
# { /SHOP/GeneratePngWIS85b "" "" "" "" "" ""}
# { /SHOP/GeneratePngWIS86 "" "" "" "" "" ""}
#
proc ResourceXml_getDependencyList { _xmlDoc } {
   set rootNode [${_xmlDoc} documentElement]
   set depXmlNodes [${rootNode} selectNodes /NODE_RESOURCES/DEPENDS_ON]
   set depsList {}
   # list of attributes supported for dependency
   # set attributeNames [list dep_name status type index local_index hour exp]
   foreach depXmlNode ${depXmlNodes} {
      set depList {}
      # set attributeNames [${depXmlNode} attributes]
      # foreach attributeName ${attributeNames} {
      #   set attributeValue [${depXmlNode} getAttribute ${attributeName}]
      #   lappend depList ${attributeName} ${attributeValue}
      # }
      # set typeValue [${depXmlNode} getAttribute type ""]
      set depNameValue [${depXmlNode} getAttribute dep_name ""]
      # set statusValue [${depXmlNode} getAttribute status ""]
      set indexValue [${depXmlNode} getAttribute index ""]
      set localIndexValue [${depXmlNode} getAttribute local_index ""]
      set hourValue [${depXmlNode} getAttribute hour ""]
      set validDowValue [${depXmlNode} getAttribute valid_dow ""]
      set validHourValue [${depXmlNode} getAttribute valid_hour ""]
      set expValue [${depXmlNode} getAttribute exp ""]

      lappend depsList [list ${depNameValue} ${indexValue} ${localIndexValue} ${hourValue} ${validDowValue} ${validHourValue} ${expValue}]
   }
   # puts "depsList :${depsList}"
   return ${depsList}
}

# adds one dependency entry in the resource.xml file
# 
# _nameValueList is a name-value list
# possible values of the keys in the name-value list are dep_name, status, type, index, local_index, exp, hour
# example:
# "dep_name /SHOP/GeneratePngWIS86 status end type node"
#
proc ResourceXml_addDependency { _xmlDoc _nameValueList } {
   set rootNode [${_xmlDoc} documentElement]
   set resourcesXmlNode [${rootNode} selectNodes /NODE_RESOURCES]
   if { ${resourcesXmlNode} != "" } {
      set xmlDependsNode [${_xmlDoc} createElement DEPENDS_ON]
      foreach {attrName attrValue} ${_nameValueList} {
         if { ${attrValue} != "" } {
            ${xmlDependsNode} setAttribute ${attrName} ${attrValue}
         }
      }
      ${resourcesXmlNode} appendChild ${xmlDependsNode}
   }
}

# creates /NODE_RESOURCES in the xml doc
proc ResourceXml_createDocument {} {

   set xmlDoc [dom createDocument NODE_RESOURCES]
   set xmlRootNode [${xmlDoc} documentElement]
   return ${xmlDoc}
}

proc ResourceXml_saveDocument { _resourceFile _xmlDoc {_deleteDoc true} } {
   set fileId [open ${_resourceFile} w 0664]
   set result [${_xmlDoc} asXML]
   puts ${fileId} ${result}
   close ${fileId}

   if { ${_deleteDoc} == true } { 
      ${_xmlDoc} delete
   }
}
