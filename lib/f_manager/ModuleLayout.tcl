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

# the module work dir is needed as a temporary storage
# for changes done on a module container
# i.e. creating/removing .tsk .cfg files, container directories
# It is cleared when the user saves the work dir or when
# the user is done editing a module
# 
# _expPath is path to experiement i.e. SEQ_EXP_HOME
# _moduleNode is experiment tree node i.e /enkf_mod/anal_mod/Analysis/gem_mod
proc ModuleLayout_getWorkDir { _expPath _moduleNode } {
   global env ${_moduleNode}_workdir
   ::log::log debug "ModuleLayout_getWorkDir _expPath:${_expPath} _moduleNode:${_moduleNode}"
   if { ! [info exists ${_moduleNode}_workdir] } {
      set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
      set ${_moduleNode}_workdir [ModuleLayout_createWorkingDir ${_expPath} ${_moduleNode}]
   }

   return [set ${_moduleNode}_workdir]
}

# The resource files are stored using an experiment tree and are located outside
# the module directory, thus requiring its own work dir
#
# _expPath is path to experiement i.e. SEQ_EXP_HOME
# _moduleNode is experiment tree node i.e /enkf_mod/anal_mod/Analysis/gem_mod
proc ModuleLayout_getWorkResourceDir { _expPath _moduleNode } {
   set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
   set modChecksum [::crc::cksum ${_moduleNode}]
   set resourceWorkDir ${expWorkDir}/resources/${modChecksum}_[file tail ${_moduleNode}]
   return ${resourceWorkDir}
}

#
# _expPath is path to experiement i.e. SEQ_EXP_HOME
# _moduleNode is experiment tree node i.e /enkf_mod/anal_mod/Analysis/gem_mod
proc ModuleLayout_clearWorkingDir { _expPath _moduleNode } {
   global ${_moduleNode}_workdir

   #::log::log debug "ModuleLayout_clearWorkingDir _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set workingDir [ModuleLayout_getWorkDirName ${_expPath} ${_moduleNode}]
   if { [ catch {
      # clear module work dir
      if { [file exists ${workingDir}] } {
         ::log::log debug "ModuleLayout_clearWorkingDir deleting ${workingDir}"
         MaestroConsole_addMsg "Cleaning temp module directory: ${workingDir}."
         file delete -force ${workingDir}
      }
   } errMsg] } {
      MaestroConsole_addErrorMsg ${errMsg}
   }

   if { [ catch {
      # clear resources work dir
      set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]
      ::log::log debug "ModuleLayout_clearWorkingDir deleting ${resourceWorkDir}"
      MaestroConsole_addMsg "Cleaning temp resource directory: ${resourceWorkDir}."

      file delete -force ${resourceWorkDir}
   } errMsg] } {
      MaestroConsole_addErrorMsg ${errMsg}
   }
   catch { unset ${_moduleNode}_workdir }
}

#
# _expPath is path to experiement i.e. SEQ_EXP_HOME
# _moduleNode is experiment tree node i.e /enkf_mod/anal_mod/Analysis/gem_mod
proc ModuleLayout_createWorkingDir { _expPath _moduleNode } {
   global env
   ::log::log debug "ModuleLayout_createWorkingDir _expPath:${_expPath} _moduleNode:${_moduleNode}"

   set moduleName [file tail ${_moduleNode}]
   set sourceModule ${_expPath}/modules/${moduleName}

   if { ! [file isdirectory ${sourceModule}] } { 
      error "Source module ${sourceModule} does not exists!  ( ModuleLayout_createWorkingDir() )"
      return
   }
   set workingDir [ModuleLayout_getWorkDirName ${_expPath} ${_moduleNode}]

   # delete working target if exists
   file delete -force ${workingDir}

   # recreate target dir
   MaestroConsole_addMsg "Creating temp module directory: ${workingDir}."
   file mkdir ${workingDir}

   # get the modules container files
   if { [file exist ${sourceModule}] } {
      ::log::log debug "ModuleLayout_createWorkingDir rsync -r -t ${sourceModule}/ ${workingDir}"
      MaestroConsole_addMsg "synchronize module: rsync -r -t ${sourceModule}/ ${workingDir}"
      exec rsync -r -t ${sourceModule}/ ${workingDir}
   }

   # get the module resource files in the exp resource work dir
   set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
   set sourceResources ${_expPath}/resources/${_moduleNode}
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]

   # delete resource working target if exists
   file delete -force ${resourceWorkDir}

   # recreate resource dir and containers
   MaestroConsole_addMsg "create temp resource directory: ${workingDir}."
   file mkdir ${resourceWorkDir}

   # get the resource files
   if { [file exist ${sourceResources}] } {
      ::log::log debug "ModuleLayout_createWorkingDir rsync -r -t ${sourceResources}/ ${resourceWorkDir}"
      MaestroConsole_addMsg "synchronize resources: rsync -r -t ${sourceResources}/ ${resourceWorkDir}/"
      exec rsync -r -t ${sourceResources}/ ${resourceWorkDir}/
   }

   MaestroConsole_addMsg "Creating temp module directory done."
   return ${workingDir}
}

# the module working dir is located at exp_work_dir/modules/(checksum of module_node)_name
# something like exp_work_dir/modules/715733325_gem_mod
# using checksum of module node (/enkf_mod/anal_mod), ready if module goes from flat to exp tree
#
# _expPath is path to experiement i.e. SEQ_EXP_HOME
# _moduleNode is experiment tree node i.e /enkf_mod/anal_mod/Analysis/gem_mod
proc ModuleLayout_getWorkDirName { _expPath _moduleNode } {
   global env
   set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
   set modChecksum [::crc::cksum ${_moduleNode}]
   set moduleName [file tail ${_moduleNode}]

   set modWorkDir ${expWorkDir}/modules/${modChecksum}_${moduleName}
   return ${modWorkDir}
}

proc ModuleLayout_saveWorkingDir { _expPath _moduleNode } {
   ::log::log debug "ModuleLayout_saveWorkingDir: _expPath:${_expPath} _moduleNode:${_moduleNode}"
   set moduleName [file tail ${_moduleNode}]
   set sourceModule [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
   set targetModule ${_expPath}/modules/${moduleName}
   set targetResource ${_expPath}/resources${_moduleNode}
   MaestroConsole_addMsg "Saving module ${_moduleNode}..."

   # sync the module changes in the work dir with the module within the experiment
   if { [file exists ${sourceModule}] } {
      ::log::log debug "ModuleLayout_saveWorkingDir: rsync --delete --update -r -t ${sourceModule}/ ${targetModule}/"
      MaestroConsole_addMsg "synchronize module: rsync --delete --update -r -t ${sourceModule}/ ${targetModule}/"
      exec rsync --delete --update -r -t ${sourceModule}/ ${targetModule}/
   }

   # sync the module resource files in the exp resource work dir with the experiment
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]
   ::log::log debug "ModuleLayout_saveWorkingDir: rsync --delete -r -t ${resourceWorkDir}/ ${targetResource}/"
   MaestroConsole_addMsg "synchronize resources: rsync --delete -r -t ${resourceWorkDir}/ ${targetResource}/"
   exec rsync --delete --update -r -t ${resourceWorkDir}/ ${targetResource}/
   MaestroConsole_addMsg "Saving module ${_moduleNode} done."
}

#
# _expPath is path to experiement i.e. SEQ_EXP_HOME
# _moduleNode is experiment tree node i.e /enkf_mod/anal_mod/Analysis/gem_mod
# _newNode is experiment tree node to be created i.e /enkf_mod/anal_mod/Analysis/gem_mod/runmod
# _nodeType is type of node to be created
# _refModPath is module reference path for _nodeType module... empty string if new local module
# _useModLink is true if a link is to be created to the reference module
# extraArgList _refModPath _useModLink
proc ModuleLayout_createNode { _expPath _moduleNode _newNode _nodeType {_extraArgList ""} } {
   global env
    ::log::log debug "ModuleLayout_createNode _expPath:${_expPath} _moduleNode:${_moduleNode} _newNode:${_newNode} _nodeType:${_nodeType}"
   # get module working dir
   set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
   set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]

   array set extraArgs ${_extraArgList}

   ::log::log debug "ModuleLayout_createNode modWorkDir:${modWorkDir}"

   # get relative path vs module node
   # /enkf_mod/postproc_mod & /enkf_mod/postproc_mod/task will result in "/task"
   # It is used to locate files within the module container
   set relativePath [::textutil::trim::trimPrefix ${_newNode} ${_moduleNode}]
   set nodeFullPath ${modWorkDir}/${relativePath}

   MaestroConsole_addMsg "Creating node ${_newNode}..."
   switch ${_nodeType} {
      TaskNode -
      NpassTaskNode {
         MaestroConsole_addMsg "create ${nodeFullPath}.tsk."
         exec touch ${nodeFullPath}.tsk;
         MaestroConsole_addMsg "create ${nodeFullPath}.cfg."
         exec touch ${nodeFullPath}.cfg
         set resourceFile ${resourceWorkDir}${relativePath}.xml
         MaestroConsole_addMsg "create [file dirname ${resourceFile}]."
         file mkdir [file dirname "${resourceFile}"]
	 set sampleResFile $env(SEQ_MANAGER_BIN)/../etc/samples/task_res_sample.xml
         MaestroConsole_addMsg "cp ${sampleResFile} ${resourceFile}"
	 exec cp ${sampleResFile} ${resourceFile}
      }
      FamilyNode {
         # create container dir
         MaestroConsole_addMsg "create ${nodeFullPath}."
         file mkdir ${nodeFullPath}
         set resourceFile ${resourceWorkDir}${relativePath}/container.xml
         MaestroConsole_addMsg "create [file dirname ${resourceFile}]."
         file mkdir [file dirname "${resourceFile}"]
      }
      LoopNode {
         # create container dir
         file mkdir ${nodeFullPath}
         MaestroConsole_addMsg "create ${nodeFullPath}."
         set resourceFile ${resourceWorkDir}${relativePath}/container.xml
         MaestroConsole_addMsg "create [file dirname ${resourceFile}]."
         file mkdir [file dirname "${resourceFile}"]
         ModuleLayout_createDummyResource ${_expPath} ${_moduleNode} ${_newNode}
      }
      SwitchNode {
         # create container dir
         file mkdir ${nodeFullPath}
         MaestroConsole_addMsg "create ${nodeFullPath}."
         set resourceFile ${resourceWorkDir}${relativePath}/container.xml
         MaestroConsole_addMsg "create [file dirname ${resourceFile}]."
         file mkdir [file dirname "${resourceFile}"]
      }
      ModuleNode {
         set resourceFile ${resourceWorkDir}${relativePath}/container.xml
         set useModLink $extraArgs(use_mod_link)
         set refModPath $extraArgs(mod_path)
         if { ${refModPath} != "" } {
            if { ${useModLink} == true } {
               # user wants to link to a module
               # create a link to the reference module from $SEQ_EXP_HOME/modules/ if not exists
               ExpLayout_createModuleLink ${_expPath} ${_newNode} ${refModPath}
            } else {
               # copy the reference module locally
               ExpLayout_importModule ${_expPath} ${_newNode} ${refModPath}
            }
         } else {
            # create new module locally if not exists
            if { [ExpLayout_isModPathExists ${_expPath} ${_newNode} "" false] == false } {
               ExpLayout_newModule ${_expPath} ${_newNode}
               # create initial module flow.xml
               set flowXmlFile [ModuleLayout_getFlowXml ${_expPath} ${_newNode}]
               ModuleFlow_initXml ${flowXmlFile} ${_newNode}
            }
         }
         # create resource dir
         MaestroConsole_addMsg "create [file dirname ${resourceFile}]."
         file mkdir [file dirname "${resourceFile}"]
      }
   }
   MaestroConsole_addMsg "Creating node ${_newNode} done."
}

# _expPath is path to experiement i.e. SEQ_EXP_HOME
# _moduleNode is experiment tree node i.e /enkf_mod/anal_mod/Analysis/gem_mod
# _renameNode is experiment tree node to be renamed i.e /enkf_mod/anal_mod/Analysis/gem_mod/runmod
# _newName is name of modified node  i.e my_new_runmod
# _nodeType is type of node to be created
proc ModuleLayout_renameNode { _expPath _moduleNode _renameNode _newName _nodeType {_rename_mode "copy"} } {
    ::log::log debug "ModuleLayout_renameNode() _expPath:${_expPath} _moduleNode:${_moduleNode} _renameNode:${_renameNode} _newName:${_newName} _nodeType:${_nodeType} _rename_mode:${_rename_mode}"
   # get module working dir
   set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
   set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]
   set newNode [file dirname ${_renameNode}]/${_newName}

   ::log::log debug "ModuleLayout_renameNode() modWorkDir:${modWorkDir}"

   # get relative path vs module node
   # /enkf_mod/postproc_mod & /enkf_mod/postproc_mod/task will result in "/task"
   # It is used to locate files within the module container
   set relativePath [::textutil::trim::trimPrefix ${_renameNode} ${_moduleNode}]
   set nodeFullPath ${modWorkDir}/${relativePath}
   set containerFullPath [file dirname ${nodeFullPath}]
   set resourceContainerFullPath [file dirname ${resourceWorkDir}/${relativePath}]

   MaestroConsole_addMsg "Renaming node ${_renameNode} to ${newNode}..."
   switch ${_nodeType} {
      TaskNode -
      NpassTaskNode {
         if { [file exists ${nodeFullPath}.tsk] } {
            # MaestroConsole_addMsg "rename ${nodeFullPath}.tsk to ${containerFullPath}/${_newName}.tsk"
            # file rename ${nodeFullPath}.tsk ${containerFullPath}/${_newName}.tsk
            ::log::log debug "ModuleLayout_renameNode() ModuleLayout_moveOrCopy ${nodeFullPath}.tsk ${containerFullPath}/${_newName}.tsk ${_rename_mode}"
            ModuleLayout_moveOrCopy ${nodeFullPath}.tsk ${containerFullPath}/${_newName}.tsk ${_rename_mode}
         }

         if { [file exists ${nodeFullPath}.cfg] } {
            # MaestroConsole_addMsg "rename ${nodeFullPath}.cfg to ${containerFullPath}/${_newName}.cfg"
            # file rename ${nodeFullPath}.cfg ${containerFullPath}/${_newName}.cfg
            ::log::log debug "ModuleLayout_renameNode() ModuleLayout_moveOrCopy ${nodeFullPath}.cfg ${containerFullPath}/${_newName}.cfg ${_rename_mode}"
            ModuleLayout_moveOrCopy ${nodeFullPath}.cfg ${containerFullPath}/${_newName}.cfg ${_rename_mode}
         }

         if { [file exists ${resourceWorkDir}${relativePath}.xml] } {
            set resourceFile ${resourceWorkDir}${relativePath}.xml
            # MaestroConsole_addMsg "rename ${resourceFile} ${resourceContainerFullPath}/${_newName}.xml."
            # file rename ${resourceFile} ${resourceContainerFullPath}/${_newName}.xml
            ::log::log debug "ModuleLayout_renameNode() ModuleLayout_moveOrCopy ${resourceFile} ${resourceContainerFullPath}/${_newName}.xml ${_rename_mode}"
            ModuleLayout_moveOrCopy ${resourceFile} ${resourceContainerFullPath}/${_newName}.xml ${_rename_mode}
         }
      }
      FamilyNode -
      SwitchNode -
      LoopNode {
         set resourceDir ${resourceWorkDir}${relativePath}
         if { [file exists ${nodeFullPath}] } {
            # rename the current container dir
            # MaestroConsole_addMsg "rename ${nodeFullPath} to ${containerFullPath}/${_newName}"
            # file rename ${nodeFullPath} ${containerFullPath}/${_newName}
            ModuleLayout_moveOrCopy ${nodeFullPath} ${containerFullPath}/${_newName} ${_rename_mode}
         }

         if { [file exists ${resourceWorkDir}/${relativePath}] } {
            # rename the current resource container dir
            # MaestroConsole_addMsg "rename ${resourceWorkDir}/${relativePath} to ${containerFullPath}/${_newName}"
            # file rename ${resourceWorkDir}/${relativePath} ${resourceContainerFullPath}/${_newName}
            ModuleLayout_moveOrCopy ${resourceWorkDir}/${relativePath} ${resourceContainerFullPath}/${_newName} ${_rename_mode}
         }
      }
      ModuleNode {
         if { [file exists ${resourceWorkDir}/${relativePath}] } {
            # rename the current resource container dir
            # MaestroConsole_addMsg "rename ${resourceWorkDir}/${relativePath} to ${containerFullPath}/${_newName}"
            # file rename ${resourceWorkDir}/${relativePath} ${resourceContainerFullPath}/${_newName}
            ModuleLayout_moveOrCopy ${resourceWorkDir}/${relativePath} ${resourceContainerFullPath}/${_newName} ${_rename_mode}
         }
      }
   }
   MaestroConsole_addMsg "Renaming node ${_renameNode} to ${newNode} done."
}

# rename the module under $SEQ_EXP_HOME
# this module is taken out of ModuleLayout_renameNode because the
# renaming of modules are postponed until the user saves the module flow
proc ModuleLayout_renameModule { _expPath _moduleNode _newName {_useCopy false} } {
   ::log::log debug "ModuleLayout_renameModule _expPath:${_expPath} _moduleNode:${_moduleNode} _newName:${_newName} _useCopy:${_useCopy}"
   set currentModPath [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]
   set newNode [file dirname ${_moduleNode}]/${_newName}
   set newModPath [ExpLayout_getModulePath ${_expPath} ${newNode}]
   if { ${_useCopy} == true } {
      MaestroConsole_addMsg "copy ${currentModPath} to ${newModPath}"
      file copy ${currentModPath} ${newModPath}
   } else {
      MaestroConsole_addMsg "rename ${currentModPath} to ${newModPath}"
      file rename ${currentModPath} ${newModPath}
   }
}

# moves files (.tsk, .cfg, .xml) in the module directory belonging to a node to a new container directory.
# _expPath is path to the experiment
# _moduleNode is experiment tree of node i.e. /enkf_mod/anal_mod
# _newContainerNode is experiment tree of new container node i.e. /enkf_mod/anal_mod/my_new_family
# _affectedNode is experiment tree of node that will be moved i.e. /enkf_mod/anal_mod/Analysis/gem_mod/Upload
# _nodeType is node type
proc ModuleLayout_assignNewContainer { _expPath _moduleNode _newContainerNode _affectedNode _nodeType {_assign_mode "copy"} } {
   ::log::log debug "ModuleLayout_assignNewContainer _expPath:${_expPath} _moduleNode:${_moduleNode} _newContainerNode:${_newContainerNode} _affectedNode:${_affectedNode} _nodeType:${_nodeType} _assign_mode:${_assign_mode}"
   set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
   set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]

   # get relative path vs module node
   # /enkf_mod/postproc_mod & /enkf_mod/postproc_mod/task will result in "/task"
   # It is used to locate files within the module container
   set relativeNewContNode [::textutil::trim::trimPrefix ${_newContainerNode} ${_moduleNode}]
   set relativeAffectedNode [::textutil::trim::trimPrefix ${_affectedNode} ${_moduleNode}]
   set newContNodeFullPath ${modWorkDir}${relativeNewContNode}
   set affectedNodeFullPath ${modWorkDir}${relativeAffectedNode}
   MaestroConsole_addMsg "mkdir ${newContNodeFullPath}/"
   file mkdir ${newContNodeFullPath}/
   MaestroConsole_addMsg "mkdir ${resourceWorkDir}${relativeNewContNode}/"
   file mkdir ${resourceWorkDir}${relativeNewContNode}/

   switch ${_nodeType} {
      TaskNode -
      NpassTaskNode {
         if { [file exists ${affectedNodeFullPath}.tsk] } {
            ::log::log debug "ModuleLayout_assignNewContainer move ${affectedNodeFullPath}.tsk to ${newContNodeFullPath}/"
            ModuleLayout_moveOrCopy ${affectedNodeFullPath}.tsk ${newContNodeFullPath}/ ${_assign_mode}
         }

         if { [file exists ${affectedNodeFullPath}.cfg] } {
            ::log::log debug "ModuleLayout_assignNewContainer move ${affectedNodeFullPath}.cfg to ${newContNodeFullPath}/"
            ModuleLayout_moveOrCopy ${affectedNodeFullPath}.cfg ${newContNodeFullPath}/ ${_assign_mode}
         }

         if { [file exists ${resourceWorkDir}${relativeAffectedNode}.xml] } {
            ::log::log debug "ModuleLayout_assignNewContainer move ${resourceWorkDir}${relativeAffectedNode}.xml to ${resourceWorkDir}${relativeNewContNode}/"
            ModuleLayout_moveOrCopy ${resourceWorkDir}${relativeAffectedNode}.xml ${resourceWorkDir}${relativeNewContNode}/ ${_assign_mode}
         }
      }
      SwitchNode -
      FamilyNode -
      LoopNode {
         # move whole container directory to new container parent
         ::log::log debug "ModuleLayout_assignNewContainer move ${affectedNodeFullPath} to ${newContNodeFullPath}/"
         MaestroConsole_addMsg "move ${affectedNodeFullPath} to ${newContNodeFullPath}/"
         file rename ${affectedNodeFullPath} ${newContNodeFullPath}/
         if { [file exists ${resourceWorkDir}${relativeAffectedNode}] } {
            ::log::log debug "ModuleLayout_assignNewContainer move ${resourceWorkDir}${relativeAffectedNode} to ${resourceWorkDir}${relativeNewContNode}/"
            ModuleLayout_moveOrCopy ${resourceWorkDir}${relativeAffectedNode} ${resourceWorkDir}${relativeNewContNode}/ ${_assign_mode}
         }
      }
      ModuleNode {
         # we only move resource directory since ModuleNode are references
         if { [file exists ${resourceWorkDir}${relativeAffectedNode}] } {
            ::log::log debug "ModuleLayout_assignNewContainer move ${resourceWorkDir}${relativeAffectedNode} to ${resourceWorkDir}${relativeNewContNode}/"
            MaestroConsole_addMsg "Move ${resourceWorkDir}${relativeAffectedNode} to ${resourceWorkDir}${relativeNewContNode}/"
            # file rename ${resourceWorkDir}${relativeAffectedNode} ${resourceWorkDir}${relativeNewContNode}/ ${_assign_mode}
            ModuleLayout_moveOrCopy ${resourceWorkDir}${relativeAffectedNode} ${resourceWorkDir}${relativeNewContNode}/ ${_assign_mode}
         }
      }
      default {
      }
   }
}

proc ModuleLayout_deleteNode { _expPath _moduleNode _deleteNode _nodeType _resOnly {_keepChildren false}} {
    ::log::log debug "ModuleLayout_deleteNode _expPath:${_expPath} _moduleNode:${_moduleNode} _deleteNode:${_deleteNode} _nodeType:${_nodeType} _resOnly:${_resOnly}"
   # get module working dir
   set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
   set expWorkDir [ExpLayout_getWorkDir ${_expPath}]
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]

   set relativePath [::textutil::trim::trimPrefix ${_deleteNode} ${_moduleNode}]
   set nodeFullPath ${modWorkDir}/${relativePath}

   ::log::log debug "ModuleLayout_deleteNode nodeFullPath:${nodeFullPath}"

   MaestroConsole_addMsg "Deleting node ${_deleteNode}..."
   switch ${_nodeType} {
      TaskNode -
      NpassTaskNode {
         if { ${_resOnly} == false } {
            MaestroConsole_addMsg "delete file ${nodeFullPath}.tsk"
            file delete ${nodeFullPath}.tsk;
            MaestroConsole_addMsg "delete file ${nodeFullPath}.cfg"
            file delete ${nodeFullPath}.cfg
         }
         set resourceFile ${resourceWorkDir}${relativePath}.xml
         MaestroConsole_addMsg "delete file ${resourceFile}"
         file delete ${resourceFile}
      }
      FamilyNode -
      SwitchNode -
      LoopNode {
         set configFile ${nodeFullPath}/container.cfg;
         set resourceDir ${resourceWorkDir}${relativePath}
         set resourceFile ${resourceWorkDir}${relativePath}/container.xml
            if { ${_keepChildren} == true } {
               # delete only container directory... move children files to
               # parent dir
               # we move everything to the parent directory... except container.cfg
               # ::log::log debug "ModuleLayout_deleteNode rsync --exclude '/container.cfg' -r ${nodeFullPath}/ [file dirname ${nodeFullPath}]"
               if { ${_resOnly} == false } {
                  MaestroConsole_addMsg "delete file ${configFile}"
                  file delete ${configFile}
                  #MaestroConsole_addMsg "synchonize module...rsync --exclude '/container.cfg' -r ${nodeFullPath}/ [file dirname ${nodeFullPath}]"
                  #exec rsync --exclude '/container.cfg' -r ${nodeFullPath}/ [file dirname ${nodeFullPath}]
                  MaestroConsole_addMsg "synchonize module...rsync -r ${nodeFullPath}/ [file dirname ${nodeFullPath}]"
                  exec rsync -r ${nodeFullPath}/ [file dirname ${nodeFullPath}]
               }

               # do the same with the resources files
               # ::log::log debug "ModuleLayout_deleteNode rsync --exclude '/container.xml' -r ${resourceDir}/ [file dirname ${resourceDir}]"
               MaestroConsole_addMsg "delete file ${resourceFile}"
               file delete ${resourceFile}
               # MaestroConsole_addMsg "synchonize resources rsync --exclude '/container.xml' -r ${resourceDir}/ [file dirname ${resourceDir}]"
               # exec rsync --exclude '/container.xml' -r ${resourceDir}/ [file dirname ${resourceDir}]
               MaestroConsole_addMsg "synchonize resources rsync -r ${resourceDir}/ [file dirname ${resourceDir}]"
               exec rsync -r ${resourceDir}/ [file dirname ${resourceDir}]
            }

            if { ${_resOnly} == false } {
               # delete everything
               MaestroConsole_addMsg "synchonize delete -force ${nodeFullPath}"
               file delete -force ${nodeFullPath}
            }

         ::log::log debug "ModuleLayout_deleteNode deleting ${resourceDir}"
         MaestroConsole_addMsg "delete ${resourceDir}."
         file delete -force ${resourceDir}
      }
      ModuleNode {
         set resourceDir ${resourceWorkDir}${relativePath}
         ::log::log debug "ModuleLayout_deleteNode deleting ${resourceDir}"
         MaestroConsole_addMsg "delete ${resourceDir}."
         file delete -force ${resourceDir}
      }
   }
   MaestroConsole_addMsg "Deleting node ${_deleteNode} done"
}

proc ModuleLayout_deleteModule { _expPath _moduleNode _deleteNode } {
   ::log::log debug "ModuleLayout_deleteModule _expPath:${_expPath} _moduleNode:${_moduleNode} _deleteNode:${_deleteNode}"

   if { [ catch {

      set modulePath [ExpLayout_getModulePath ${_expPath} ${_deleteNode}]
      ::log::log debug "ModuleLayout_deleteModule modulePath:${modulePath}"
      set refCount [ExpModTree_getModInstances ${_expPath} ${_deleteNode}]
      ::log::log debug "ModuleLayout_deleteModule refCount:${refCount}"
      ::log::log debug "ModuleLayout_deleteModule ExpModTree_getModInstances ${_expPath} ${_deleteNode} ? [ExpModTree_getModInstances ${_expPath} ${_deleteNode}]"
      if { [ExpModTree_getModInstances ${_expPath} ${_deleteNode}] == 0 } {
         set linkTarget ""
         catch { set linkTarget [file readlink ${modulePath}] }
         if { [file exists ${modulePath}] && ${linkTarget} != "" } {
            # module is a link remove the link
            MaestroConsole_addMsg "delete module link ${modulePath}."
            ::log::log debug "ModuleLayout_deleteModule delete module link ${modulePath}"
            file delete ${modulePath}
         } else {
            MaestroConsole_addMsg "delete module directory ${modulePath}."
            file delete -force ${modulePath}
            ::log::log debug "ModuleLayout_deleteModule delete module directory ${modulePath}."
         }
      } else {
         MaestroConsole_addMsg "Not deleting module ${modulePath}... reference count:${refCount} != 0."
         ::log::log debug "ModuleLayout_deleteModule Not deleting module ${modulePath}... reference count:${refCount} != 0"
      }

   } errMsg] } {
      MaestroConsole_addErrorMsg ${errMsg}
      ::log::log debug "ModuleLayout_deleteModule ERROR: ${errMsg}"
   }

}

# creates dummy resource files
proc ModuleLayout_createDummyResource { _expPath _moduleNode _node } {
   ::log::log debug "ModuleLayout_createDummyResource _expPath:${_expPath} _moduleNode:${_moduleNode} _node:${_node}"
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]
   set relativePath [::textutil::trim::trimPrefix ${_node} ${_moduleNode}]

   set xmlDoc [dom createDocument NODE_RESOURCES]
   set xmlRootNode [${xmlDoc} documentElement]
   set xmlLoopNode [${xmlDoc} createElement LOOP]

   ${xmlLoopNode} setAttribute start 0
   ${xmlLoopNode} setAttribute set 1
   ${xmlLoopNode} setAttribute end 1
   ${xmlLoopNode} setAttribute step 1
   ${xmlRootNode} appendChild ${xmlLoopNode}

   set xmlData [${xmlDoc} asXML]

   set resourceFile ${resourceWorkDir}${relativePath}/container.xml
   ::log::log debug "ModuleLayout_createDummyResource writing xml file: ${resourceFile}"
   MaestroConsole_addMsg "create resource file ${resourceFile}."
   set fileId [open ${resourceFile} w 0664]
   puts ${fileId} ${xmlData}
   close ${fileId}
   
   ${xmlDoc} delete
}

proc ModuleLayout_getFlowXml { _expPath _moduleNode } {
   set flowXmlFile [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]/flow.xml
   return ${flowXmlFile}
}

# retrieve the path to the config file of a node
#
# _expPath is path to the experiment
# _moduleNode is experiment tree of node i.e. /enkf_mod/anal_mod
# _node is the target node for the source file  i.e. /enkf_mod/anal_mod/Analysis/enkf_pre
# _nodeType is node type
# _isNew true or false, 
#        true means the node is being created and the config file will be retrieved from the module working dir
#        false means the node is already created and saved and the config file will be retrieved from regular module dir
proc ModuleLayout_getNodeConfigPath { _expPath _moduleNode _node _nodeType {_isNew false}} {
   # build the module path in the flat modules tree
   set modulePath [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]
   # get relative path vs module node
   set relativePath [::textutil::trim::trimPrefix ${_node} ${_moduleNode}]
   if { ${_isNew} == true } {
      # get module working dir
      set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
      # node is being created, retrieve from work dir
      set nodeFullPath ${modWorkDir}/${relativePath}
   } else {
      # retrieve from regular module container
      set nodeFullPath ${modulePath}${relativePath}
   }

   switch ${_nodeType} {
      TaskNode -
      NpassTaskNode {
         set configFile ${nodeFullPath}.cfg
      }
      SwitchNode -
      FamilyNode -
      LoopNode -
      ModuleNode {
         set configFile ${nodeFullPath}/container.cfg
      }
      default {
         error "Application error: invalid node type ${_nodeType} in proc ModuleLayout_getNodeConfigPath"
      }
   }
}

# retrieve the path to the source file of a node
#
# _expPath is path to the experiment
# _moduleNode is experiment tree of node i.e. /enkf_mod/anal_mod
# _node is the target node for the source file  i.e. /enkf_mod/anal_mod/Analysis/enkf_pre
# _nodeType is node type
# _isNew true or false, 
#        true means the node is being created and the source file will be retrieved from the module working dir
#        false means the node is already created and saved and the source file will be retrieved from regular module dir
proc ModuleLayout_getNodeSourcePath { _expPath _moduleNode _node _nodeType {_isNew false} } {
   # build the module path in the flat modules tree
   set modulePath [ExpLayout_getModulePath ${_expPath} ${_moduleNode}]
   set relativePath [::textutil::trim::trimPrefix ${_node} ${_moduleNode}]
   if { ${_isNew} == true } {
      # get module working dir
      set modWorkDir [ModuleLayout_getWorkDir ${_expPath} ${_moduleNode}]
      # node is being created, retrieve from work dir
      set nodeFullPath ${modWorkDir}/${relativePath}
   } else {
      # retrieve from regular module container
      set nodeFullPath ${modulePath}${relativePath}
   }

   switch ${_nodeType} {
      TaskNode -
      NpassTaskNode {
         set sourceFilePath ${nodeFullPath}.tsk
      }
      default {
         error "Application error: invalid node type ${_nodeType} in proc ModuleLayout_getNodeSourcePath"
      }
   }
   return ${sourceFilePath}
}

# retrieve the path to the resource file of a node
#
# _expPath is path to the experiment
# _moduleNode is experiment tree of node i.e. /enkf_mod/anal_mod
# _node is the target node for the source file  i.e. /enkf_mod/anal_mod/Analysis/enkf_pre
# _nodeType is node type
# _isNew true or false, 
#        true means the node is being created and the resource file will be retrieved from the resource working dir
#        false means the node is already created and saved and the resource file will be retrieved from regular resource dir
proc ModuleLayout_getNodeResourcePath { _expPath _moduleNode _node _nodeType {_isNew false} } {
   # get resource working dir
   set resourceWorkDir [ModuleLayout_getWorkResourceDir ${_expPath} ${_moduleNode}]
   set relativePath [::textutil::trim::trimPrefix ${_node} ${_moduleNode}]
   if { ${_isNew} == true } {
      # node is being created, retrieve from work dir
      set nodeFullPath ${resourceWorkDir}/${relativePath}
   } else {
      # retrieve from regular module container
      set nodeFullPath ${_expPath}/resources${_node}
   }

   switch ${_nodeType} {
      TaskNode -
      NpassTaskNode {
         set resourceFile ${nodeFullPath}.xml
      }
      SwitchNode -
      FamilyNode -
      LoopNode -
      ModuleNode {
         set resourceFile ${nodeFullPath}/container.xml
      }
      default {
         error "Application error: invalid node type ${_nodeType} in proc ModuleLayout_getNodeResourcePath"
      }
   }
   return ${resourceFile}
}

proc ModuleLayout_moveOrCopy { _source _target _mode } {
   if { ${_mode} == "move" } {
     MaestroConsole_addMsg "move ${_source} to ${_target}"
     file rename -force ${_source} ${_target}
   } else {
     MaestroConsole_addMsg "copy ${_source} to ${_target}"
      file copy -force ${_source} ${_target}
   }
}
