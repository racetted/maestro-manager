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


package require cksum 

proc ExpLayout_getEntryModule { _expPath } {

   # get exp first module
   set entryModule [file tail [file readlink ${_expPath}/EntryModule]]
}

proc ExpLayout_getEntryModulePath { _expPath } {
   set modulePath ${_expPath}/EntryModule
   return ${modulePath}
}

proc ExpLayout_getExpChecksum { _expPath } {
   set expChecksum [::crc::cksum ${_expPath}]
   return ${expChecksum}
}

proc ExpLayout_getModuleChecksum { _expPath _moduleNode } {
   set expChecksum [::crc::cksum ${_expPath}]
   set modChecksum [::crc::cksum ${_moduleNode}]
   return ${expChecksum}_${modChecksum}
}

# returns the path where the module root directory is located
# _expPath is path to the experiment
# _moduleNode is experiment tree of node i.e. /enkf_mod/anal_mod
proc ExpLayout_getModulePath { _expPath _moduleNode } {
   # for now uses modules flat directory
   set modulePath ${_expPath}/modules/[file tail ${_moduleNode}]
   return ${modulePath}
}

proc ExpLayout_getModuleTruepath { _expPath _moduleNode } {
   set modulePath ${_expPath}/modules/[file tail ${_moduleNode}]
   set modTruePath [exec true_path ${modulePath}]
   return ${modTruePath}
}

# the exp working dir is located at $TMPDIR/maestro_center/(checksum exp_path)_expname
# something like TMPDIR/maestro_center/715733325_e206
# It is a place holder for module container changes (deleting adding nodes) and 
# experiment resources
# 
# I'm using a checksum of the expPath so that it doesn't conflict if
# editing two experiments with the same name but different path
#
# The work dir is created whenever a user modifies a module flow
# It is deleted when the user exists the application
#
# _expPath is path to the experiment
proc ExpLayout_getWorkDir { _expPath } {

   set expWorkDirName [ExpLayout_getWorkDirName ${_expPath}]
   # recreate target dir 
   if { ! [file exists ${expWorkDirName}/modules] } {
      MaestroConsole_addMsg "Creating experiment temp modules directory ${expWorkDirName}."
      ::log::log debug "ExpLayout_getWorkDir creating working dir ${expWorkDirName}/modules"
      file mkdir ${expWorkDirName}/modules
      ::log::log debug "ExpLayout_getWorkDir creating working dir ${expWorkDirName}/resources"
      file mkdir ${expWorkDirName}/resources
   }

   ::log::log debug "ExpLayout_getWorkDir working dir ${expWorkDirName}"
   
   return ${expWorkDirName}
}

# _expPath is path to the experiment
proc ExpLayout_getWorkDirName { _expPath } {
   global env
   set expChecksum [::crc::cksum ${_expPath}]
   if { [info exists env(TMPDIR)] && [file writable $env(TMPDIR)] } {
      set tmpBase $env(TMPDIR)
   } else {
      set tmpBase /tmp/$env(USER)
   }
   set workDir ${tmpBase}/maestro_center/${expChecksum}_[file tail ${_expPath}]
}

proc ExpLayout_clearWorkDir { _expPath } {
   set expWorkDirName [ExpLayout_getWorkDirName ${_expPath}]
   if { [file isdirectory ${expWorkDirName}] } {
      ::log::log debug "ExpLayout_clearWorkDir deleting ${expWorkDirName}..."
      file delete -force ${expWorkDirName}
   }
}

# checks in the $SEQ_EXP_HOME/modules/ directory if the module
# already exists and returns true if exists
# returns false otherwise
#  
# _expPath is path to the experiment (SEQ_EXP_HOME)
# _moduleNode is experiment tree of node i.e. /enkf_mod/anal_mod
proc ExpLayout_isModPathExists { _expPath _moduleNode _refModulePath _useModuleLink } {
   ::log::log debug "ExpLayout_isModPathExists _expPath:${_expPath} _moduleNode:${_moduleNode} _refModulePath:${_refModulePath} _useModuleLink:${_useModuleLink}"
   # for now we still use flat modules
   set modulePath ${_expPath}/modules/[file tail ${_moduleNode}]
   set linkTarget ""
   set isExists false
   catch { set linkTarget [file readlink ${modulePath}] }
   if { ${_useModuleLink} == true } {
      # user wants a link, verifying if it is a link and if it is the same target
      if { [file exists ${modulePath}] && (${linkTarget} == "" || ${linkTarget} != ${_refModulePath}) } {
         if { [exec true_path ${modulePath}] != [exec true_path ${_refModulePath}] } {
            ::log::log error "ExpLayout_isModPathExists linkTarget:${linkTarget}"
            MaestroConsole_addMsg "The path ${modulePath} already exists. Link target: [exec true_path ${modulePath}]"
            # error ModulePathExists
            set isExists true
         }
      }
   } else {
      # not a link, if the reference path and the module path points to the same, then allow.
      # user is using a module within the experiment allow it...multiple instance of the same module
      if { [file exists ${modulePath}] } {
         if { [file exists ${_refModulePath}] &&  ([exec true_path ${modulePath}] != [exec true_path ${_refModulePath}]) } {
            # not a link, validate that directory does not exists
            ::log::log error "ExpLayout_isModPathExists ${modulePath} exists"
            MaestroConsole_addMsg "The path ${modulePath} already exists (symbolic link)."
            # error ModulePathExists
            set isExists true
         } elseif { ${linkTarget} != "" } {
            MaestroConsole_addMsg "The path ${modulePath} already exists (symbolic link)."
            # error ModulePathExists
            set isExists true
         } elseif { ${_refModulePath} == "" } {
            # module path exists and reference is null i.e. local module
            # but the module already exists
            MaestroConsole_addMsg "The path ${modulePath} already exists as local module."
            # error ModulePathExists
            set isExists true
         }
      }
   }
   return ${isExists}
}

# creates a link from $SEQ_EXP_HOME/modules/module_name --> _refModulePath
# _expPath is path to the experiment
# _moduleNode is experiment tree of node i.e. /enkf_mod/anal_mod
proc ExpLayout_createModuleLink { _expPath _moduleNode _refModulePath } {
   set modulePath ${_expPath}/modules/[file tail ${_moduleNode}]
   ::log::log debug "ExpLayout_createModuleLink link name: ${modulePath} target:${_refModulePath}"
   if { ! [file exists ${modulePath}] } {
      MaestroConsole_addMsg "create link ${modulePath} -> ${_refModulePath}."
      file link ${modulePath} ${_refModulePath} 
   } else {
      MaestroConsole_addMsg "no create: link ${modulePath} already exists."
   }
}

# imports an existing module and create it locally under $SEQ_EXP_HOME/modules/module_name
# only if $SEQ_EXP_HOME/modules/module_name does not already exists
proc ExpLayout_importModule { _expPath _moduleNode _refModulePath } {
   set target ${_expPath}/modules/[file tail ${_moduleNode}]
   if { ! [file exists ${target}] } {
      ::log::log debug "ExpLayout_importModule rsync -r ${_refModulePath}/ ${target}"
      MaestroConsole_addMsg "import module: rsync -r ${_refModulePath}/ ${target}."
      exec rsync -r ${_refModulePath}/ ${target}
   } else {
      MaestroConsole_addMsg "NOT importing module: ${target} already exists."
   }
}

# create a new module directory under $SEQ_EXP_HOME/modules/module_name
proc ExpLayout_newModule { _expPath _moduleNode } {
   set modulePath ${_expPath}/modules/[file tail ${_moduleNode}]
   ::log::log debug "ExpLayout_newModule mkdir ${modulePath}"
   MaestroConsole_addMsg "create module directory ${modulePath}"
   file mkdir ${modulePath}
}

proc ExpLayout_isModuleLink { _expPath _moduleNode } {
   set isLink false
   set modulePath [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]
   set linkTarget ""
   catch { set linkTarget [file readlink ${modulePath}] }
   if { [file isdirectory ${modulePath}] && ${linkTarget} != "" } {
      set isLink true
   }
   return ${isLink}
}

proc ExpLayout_getModLinkTarget { _expPath _moduleNode } {
   set modulePath [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]
   set linkTarget ""
   catch { set linkTarget [file readlink ${modulePath}] }
   return ${linkTarget}
}

proc ExpLayout_isModuleOutsideLink { _expPath _moduleNode } {
   set isOutsideLink false
   if { [ExpLayout_isModuleLink ${_expPath} ${_moduleNode}] == true } {
      set modulePath [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]
      set moduleTruePath [exec true_path ${modulePath}]
      set expTruePath [exec true_path ${_expPath}]

      # the module is an outside link if the expTruePath is not contained within the moduleTruePath
      # or the module is a local link only if the path of experiment is contained within the path of the module
      if { [string first ${expTruePath} ${moduleTruePath}] != 0 } {
         set isOutsideLink true
      }
   }
   return ${isOutsideLink}
}

# copies a reference module locally in $SEQ_EXP_HOME/modules
# - first deletes the link locally
# - then copies the module using rsync
# - doesn't care about resources under $SEQ_EXP_HOME/resources
# since this proc is meant to be used for an existing module
# where the it is referenced but the resources dir already exists
# _moduleNode is the module node path i.e. /enkf_mod/anal_mod/Analysis/gem_mod
# from the experiment tree
proc ExpLayout_copyModule { _expPath _moduleNode } {
   ::log::log debug "ExpLayout_copyModule _expPath:${_expPath} _moduleNode:${_moduleNode}"
   if { [ExpLayout_isModuleLink ${_expPath} ${_moduleNode}] == true } {
      set referenceModule [ExpLayout_getModLinkTarget ${_expPath} ${_moduleNode}]
      set modulePath [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]
      set moduleTruePath [exec true_path ${modulePath}]

      # first delete link
      ::log::log debug "ExpLayout_copyModule deleting link ${modulePath}"
      MaestroConsole_addMsg "delete module link: ${modulePath}."
      file delete ${modulePath}

      # then copy the module locally
      # ::log::log debug "ExpLayout_copyModule rsync -r ${referenceModule}/ ${modulePath}"
      ::log::log debug "ExpLayout_copyModule rsync -r ${moduleTruePath}/ ${modulePath}"
      #MaestroConsole_addMsg "copy module locally: rsync -r ${referenceModule}/ ${modulePath}"
      MaestroConsole_addMsg "copy module locally: rsync -r ${moduleTruePath}/ ${modulePath}"
      exec rsync -r ${moduleTruePath}/ ${modulePath}
      
      # if the resource dir does not exists create it, else do nothing
   }
}

proc ExpLayout_flowBuilder { _expPath } {
   global env
   set flowBuilderExec ""
   set expFlowXml ${_expPath}/flow.xml
   if { [file exists ${expFlowXml}] && ! [file writable ${expFlowXml}] } {
      # MaestroConsole_addErrorMsg "Cannot write ${expFlowXml}."
      error "Cannot write ${expFlowXml}."
   }
   catch { set flowBuilderExec [exec which flowbuilder.py] }
   if { ${flowBuilderExec} == "" } {
      # MaestroConsole_addErrorMsg "Cannot locate flowbuilder.py."
      error "Cannot locate flowbuilder.py."
   }
   set cmd "${flowBuilderExec} -e ${_expPath} -o ${expFlowXml}"
   MaestroConsole_addMsg ${cmd}
   eval exec ${cmd}
}

# renames the last listing of a node
# It deals only with listings available in SEQ_EXP_HOME/listings/latest/
# Whether if it is a container or a task, it will replace all instances
# of the node to the new name
proc ExpLayout_renameListing { _expPath _flowNode _newName } {
   ::log::log debug "ExpLayout_renameListing _expPath:${_expPath} _flowNode:${_flowNode} _newName:${_newName}"
   set containerDir [file dirname ${_flowNode}]
   set nodeLeaf [file tail ${_flowNode}]
   set listingDir ${_expPath}/listings/latest${containerDir}
   if { [file exists ${listingDir}]} {
      if { [file exists ${listingDir}/${nodeLeaf}] } {
         # rename all instances of ${nodeLeaf}.* to ${_newName}.* and
         # rename ${nodeLeaf} to ${_newName}
         set cmd "ksh -c \"cd ${listingDir};rename 's/${nodeLeaf}\./${_newName}./' ${nodeLeaf}.*;rename 's/${nodeLeaf}/${_newName}/' ${nodeLeaf}\""
      } else {
         # rename all instances of ${nodeLeaf}.* to ${_newName}.* and
         set cmd "ksh -c \"cd ${listingDir};rename 's/${nodeLeaf}\./${_newName}./' ${nodeLeaf}.*\""
      }
      MaestroConsole_addMsg "rename listings: ${cmd}"
      eval exec ${cmd}
   }
}
