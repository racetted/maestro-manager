package require struct::record
package require tdom
package require cksum

namespace import ::struct::record::*

#######################################################################
#######################################################################
# The code in this file contains logic to 
# parse an experiment modules tree xml file.
# It creates a module tree using the ExpModTreeNode structure.
#
#
#######################################################################
#######################################################################

# this structure is used to build the
# modules tree only, not used for
# build module or experiment flow.
#
record define ExpModTreeNode {
   name
   version
   date
   parent
   children
   exp_path
   ref_name
}

proc ExpModTree_getReferenceName { _expPath _moduleNode } {
   set _modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   return [${_modTreeNodeRecord} cget -ref_name]
}

# returns the number of reference instances to a module node record
#
# _expPath
# _moduleNode is full module node name i.e. /enkf_mod/anal_mod/Analysis/gem_mod
#
proc ExpModTree_getModInstances { _expPath _moduleNode } {
   ::log::log debug "ExpModTree_getModInstances: _expPath=${_expPath} _moduleNode=${_moduleNode}"
   set count 0
   if { [ catch {
      set modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
      set moduleName [${modTreeNodeRecord} cget -name]

      foreach modTreeNode [record show instances ExpModTreeNode] {
         if { ${moduleName} == [${modTreeNode} cget -name] } {
            incr count
         }
      }
   } errMsg] } {
      ::log::log debug "ExpModTree_getModInstances WARNING: ${errMsg}"
   }

   return ${count}
}

# returns the number of reference instances to a module
# Using flat modules, this is useful for instance to know before
# deleting a module from $SEQ_EXP_HOME/modules/ since the
# experiment tree can have multiple module nodes referencing the same module
# For example, gem_mod can be referenced at from /enkf_mod/anal_mod/Analysis/gem_mod
# and /enkf_mod/Trials/gem_loop/gem_mod
#
# _expPath
# _moduleNode is full module node name i.e. /enkf_mod/anal_mod/Analysis/gem_mod
proc ExpModTree_getAbsModInstances { _expPath _moduleNode } {
   set count 0
   set modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   set moduleName [${modTreeNodeRecord} cget -name]
   set modulePath ${_expPath}/modules/${moduleName}
   set modTruePath [exec true_path ${modulePath}]
   foreach modTreeNode [record show instances ExpModTreeNode] {
      set checkModulePath [${modTreeNode} cget -exp_path]/modules/[${modTreeNode} cget -name]
      set checkModTruePath ""
      catch { set checkModTruePath [exec true_path ${checkModulePath}] }
      if { ${modTruePath} == ${checkModTruePath} } {
         incr count
      }
   }
   return ${count}
}

# _moduleNode is new node to be created in the form /enkf_mod/gem_mod
# _parentTreeNodeRecord is a ExpModTreeNode record of the parent
# _refName would be used if the module is a link and not local... It is the
# name of the reference module (might be different than the actual one used (link name vs target)
proc ExpModTree_addModule { _expPath _moduleNode _parentTreeNodeRecord {_refName ""} } {
   ::log::log debug "ExpModTree_addModule _moduleNode:${_moduleNode} _parentNode:${_parentTreeNodeRecord} _refName:${_refName}"
   set moduleName [file tail ${_moduleNode}]

   set modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   #ExpModTreeNode ${flowNodeRecord} -name ${moduleName} -version \
   #   ${moduleVersion} -date ${moduleDate} -parent ${_parentNode}

   if { [record exists instance ${modTreeNodeRecord}] == 0 } {
      ExpModTreeNode ${modTreeNodeRecord}
   }
   ${modTreeNodeRecord} configure -name ${moduleName} -parent ${_parentTreeNodeRecord} -exp_path ${_expPath} -ref_name ${_refName}

   # I only add if it's not there already
   if { ${_parentTreeNodeRecord} != "" } {
      set childRecordName [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
      set currentChilds [${_parentTreeNodeRecord} cget -children]
      if { [lsearch ${currentChilds} ${childRecordName}] == -1 } {
         set currentChilds [linsert ${currentChilds} end ${childRecordName}]
         ${_parentTreeNodeRecord} configure -children ${currentChilds}
      }
   }
   return ${modTreeNodeRecord}
}

proc ExpModTree_deleteModule { _expPath _moduleNode } {

   set modTreeNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   # remove child nodes first
   foreach childModule [${modTreeNodeRecord} cget -children] {
      ExpModTree_deleteModule ${_expPath} ${childModule}
   }

   # remove module from parent module
   set parentModule [${modTreeNodeRecord} cget -parent]
   if { ${parentModule} != "" } {
      set parentChilds [${parentModule} cget -children]
      set childNodeIndex [lsearch ${parentChilds} ${modTreeNodeRecord}]
      if { ${childNodeIndex} != -1 } {
         set newChilds [lreplace ${parentChilds} ${childNodeIndex} ${childNodeIndex}]
         ${parentModule} configure -children ${newChilds}
      } 
   }

   # delete current node
   ::log::log debug "ExpModTree_deleteModule delete instance ${modTreeNodeRecord}"
   record delete instance ${modTreeNodeRecord}
}

# recursively deletes all records of an exp tree module down
proc ExpModTree_deleteRecord { _expPath _moduleNode {_isRecursive true}} {
   set modNodeRecord [ExpModTree_getRecordName ${_expPath} ${_moduleNode}]
   if { ${_isRecursive} == true } {
      # remove child nodes first
      foreach childNode [${modNodeRecord} cget -children] {
         ExpModTree_deleteRecord ${_expPath} ${childNode} ${_isRecursive}
      }
   }
   ::log::log debug "ExpModTree_deleteRecord delete instance ${modNodeRecord}"
   record delete instance ${modNodeRecord}
}

proc ExpModTree_getEntryModRecord { _expPath } {

   # get exp first module
   set entryModule [ExpLayout_getEntryModule ${_expPath}]
   set entryModTreeNode [ExpModTree_getRecordName ${_expPath} /${entryModule}]
   return ${entryModTreeNode}
}

# add specific prefix to avoid name class with other records since
# a record name automatically becomes a tcl command
proc ExpModTree_getRecordName { _expPath _moduleNode } {
   ::log::log debug "ExpModTree_getRecordName _moduleNode:${_moduleNode}"
   set prefix [ExpModTree_getRecordPrefix ${_expPath}]
   if { [string first ${prefix} ${_moduleNode}] == -1 } {
      return ${prefix}${_moduleNode}
   }
   return ${_moduleNode}
}

# returns the prefix that will be used to build a module tree record
proc ExpModTree_getRecordPrefix { _expPath } {
   set expChecksum [ExpLayout_getExpChecksum ${_expPath}]
   set prefix mtree_${expChecksum}_
   return ${prefix}
}

# returns true if there is a module in the tree that have changed
# mainly used to ask user to confirm before quiting the application
proc ExpModTree_isTreeChanged { _expPath } {
   foreach modTreeNode [record show instances ExpModTreeNode] {
      set moduleNode [ExpModTree_record2NodeName ${modTreeNode}]
      ::log::log debug "ModuleFlow_isModuleChanged ${_expPath} ${modTreeNode} ${moduleNode}"
         if { [ModuleFlow_isModuleChanged ${_expPath} ${moduleNode}] == true } {
            return true
         }
   }
   return false
}

# gets the node name from a record_name
# record format is mtree_${exp_checksum}_${module_node}
# i.e. mtree_123456_/enkf_mod/assim/gem_mod
# would return /enkf_mod/assim/gem_mod
proc ExpModTree_record2NodeName { _modTreeNodeRecord } {
   ::log::log debug "ExpModTree_record2NodeName _modTreeNodeRecord:${_modTreeNodeRecord}"
   if { [string index ${_modTreeNodeRecord} 0] == ":" } {
      set scannedItems [scan ${_modTreeNodeRecord} "::mtree_%d_%s" moduleid nodeName]
   } else {
      set scannedItems [scan ${_modTreeNodeRecord} "mtree_%d_%s" moduleid nodeName]
   }
   if { ${scannedItems} == 2 } {
      return ${nodeName}
   } else {
      return ${_modTreeNodeRecord}
   }
}


proc ExpModTree_printNode { _domNode } {
   puts "ExpModTree_printNode"
   puts "nodeName: [${_domNode} nodeName]"
   puts "nodeType: [${_domNode} nodeType]"
   puts "nodeValue: [${_domNode} nodeValue]"
   puts "name attribute: [${_domNode} getAttribute name]"
   puts "version_number attribute: [${_domNode} getAttribute version_number "" ]"
   puts "date attribute: [${_domNode} getAttribute date]"
   #puts "nodeType: [${_domNode} nodeType]"
   #puts "nodeType: [${_domNode} nodeType]"
}
