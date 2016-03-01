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


array set DirFullName {
           bin    "bin"
           hub    "hub"
           mod    "modules"
           seq    "sequencing"
           log    "logs"
           lis    "listings"
           res    "resources"
}

namespace eval NewExp {
      variable XPname
      variable win_new_xp
      variable NextNew
      variable initdir
      variable ExpName
      variable ExpPath
      variable XpPath
      variable ResFilePath
}

proc NewExp::New_xp { exp nbk } {

      variable XPname
      variable win_new_xp 
      variable initdir
      variable ExpName 
      variable EntryModName 
      variable ExpPath
      variable XpPath
      variable ResFilePath

      if {[winfo exists .newxp]} {
             destroy .newxp
      }

      set ResFilePath ""

      set win_new_xp [toplevel .newxp] 
      wm title $win_new_xp $Dialogs::New_ExpTitle 
      wm minsize $win_new_xp 500 300

      # -- if depot is set up use it. This will happen if first Time User
      set NewExp::initdir ""

      # -- get depot for notebook
      set NewExp::initdir [Preferences::GetTabListDepots $nbk "w"]
      if {[string compare $NewExp::initdir "" ] == 0 } {
              set NewExp::initdir $::env(HOME)/
      } 
      
      set controlframe [frame $win_new_xp.ctrf -border 2 -relief groove]

      label $controlframe.lab -text  $Dialogs::New_ExpTitle -font "ansi 12 "

      set titn [TitleFrame $controlframe.titn -text $Dialogs::New_ExpName]
      set tith [TitleFrame $controlframe.tith -text $Dialogs::New_ExpSubD]
      set titp [TitleFrame $controlframe.titp -text $Dialogs::New_ExpDest]
      set tite [TitleFrame $controlframe.tite -text $Dialogs::New_ExpEnMo]
      set titr [TitleFrame $controlframe.titr -text $Dialogs::New_ExpResFile]

      set subf1 [$titn getframe]
      set subf2 [$tith getframe]
      set subf3 [$titp getframe]
      set subf4 [$tite getframe]
      set subf5 [$titr getframe]
      
      set ExpName  [Entry $subf1.entryn \
                         -textvariable  NewExp::XPname \
			 -width 45\
			 -bg  #FFFFFF \
                         -command  "NewExp::ValueName $subf1.entryn" \
                         -helptext "Experiment Name "]

      set ButExpSubDir  [button  $subf2.butsubdir -image $XPManager::img_Notify -command {puts "Notify"}]

      set ExpPath [ComboBox $subf3.list -textvariable NewExp::XpPath \
                         -width 45 \
			 -editable true \
			 -autocomplete false \
			 -entrybg  #FFFFFF \
			 -values $NewExp::initdir \
			 -bwlistbox false \
			 -selectbackground #FFFFFF \
			 -selectforeground black \
			 -helptext "List of Available Paths"\
			 -modifycmd "NewExp::ValuePath $subf3.list"]
       	                 
      set ExpEntryMod  [Entry $subf4.entrymod \
                         -textvariable  NewExp::EntryModName \
			 -width 45\
			 -bg  #FFFFFF \
                         -command  "" \
                         -helptext "Entry Module Name"]

      set ButModNotif  [button  $subf4.butnotif -image $XPManager::img_Notify -command {puts "Notify"}]

      Button $subf3.butb -text "Browse Directories" \
                    -image $XPManager::img_FoldXp \
                    -command {
		               set dir [tk_chooseDirectory -initialdir $env(HOME)/ -title "Choose a directory" -parent .newxp]
			               if {[string compare x$dir "x"] != 0} {
					     set retv [NewExp::CheckPath $dir]
					     if { $retv == 0 } {
						      set NewExp::XpPath $dir
						      if {[string compare $dir [file normalize $::env(HOME)]] == 0} {
						           Dialogs::show_msgdlg $Dialogs::Dlg_AddPath  ok warning "" .newxp
						      } 
                                             } else {
						      Dialogs::show_msgdlg $Dialogs::Dlg_PathNotOwned  ok warning "" .newxp
					     }
				        }
		             }

      Entry $subf5.entryrespath -textvariable NewExp::ResFilePath -width 45 -bg #FFFFFF -helptext "Resource file path"   

      Button $subf5.browseb -text "Browse" -command {
                                   set dir [tk_getOpenFile -initialdir $env(HOME)/.suites -title "Choose a resource file" -parent .newxp]
			               if {[string compare x$dir "x"] != 0} {
				          set NewExp::ResFilePath $dir
				       }
		                   }

      Button $subf5.checkres -text "Use default" -command { set NewExp::ResFilePath "$env(HOME)/.suites/default_resources.def" }
      if { ![file exists $::env(HOME)/.suites/default_resources.def] } {
         $subf5.checkres configure -state disabled
      }
      Button $subf5.createdefb -text "Create/edit default file" -command "
                                   if { ! [file exists $::env(HOME)/.suites] } {
                                      [ file mkdir $::env(HOME)/.suites ]
                                   }
                                   if { ![file exists $::env(HOME)/.suites/default_resources.def] && [file writable $::env(HOME)/.suites/] } {
                                      close [open $::env(HOME)/.suites/default_resources.def a]
                                   }
                                   ::ModuleFlowView_goEditor $::env(HOME)/.suites/default_resources.def
                                   
                                   $subf5.checkres configure -state active
                          "
                                   
      frame $controlframe.sep -height 2 -borderwidth 1 -relief sunken
      frame $controlframe.buttons -border 2 -relief groove

      set ButCancel [Button $controlframe.buttons.cancel  -image $XPManager::img_Cancel -command {destroy $NewExp::win_new_xp}]
      set NextB     [Button $controlframe.buttons.next    -image $XPManager::img_Next -command {\
                        if {[string compare $NewExp::XPname ""] == 0 } {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_ExpNameMiss  ok warning "" $NewExp::win_new_xp
				  return
                        }

                        if { ! [regexp {^[A-Za-z0-9_\-\.]+$} $NewExp::XPname ]} {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_ExpInvalidName  ok warning "" $NewExp::win_new_xp
				  return
                        }

                        if {[string compare $NewExp::EntryModName ""] == 0 } {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_NameEntryMod  ok warning "" $NewExp::win_new_xp
				  return
                        }

                        if { ! [regexp {[A-Za-z0-9_\-\.]+$} $NewExp::EntryModName]} {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_ModInvalidName  ok warning "" $NewExp::win_new_xp
				  return
                        }

                        if {[string compare $NewExp::XpPath ""] == 0} {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_NewExpPath  ok warning "" $NewExp::win_new_xp
				  return
		        }

                        if { ! [regexp {^\/[A-Za-z0-9_\-\.\/]+$} $NewExp::XpPath]} {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_ExpPathInvalid  ok warning "" $NewExp::win_new_xp
				  return
		        }
                        
			# -- I have to examine if directory existe & belong to user
			if {[file exist $NewExp::XpPath] == 0 } {
			       Dialogs::show_msgdlg "$Dialogs::Dlg_CreatePath : $NewExp::XpPath" ok warning "" $NewExp::win_new_xp
                        } else {
			       if {[file writable $NewExp::XpPath] == 0 } {
	                                 Dialogs::show_msgdlg $Dialogs::Dlg_PathNotOwned  ok warning "" $NewExp::win_new_xp
				         return
			       }
			}

                        # -- Check if Exp. already there!
			if {[file exist $NewExp::XpPath/$NewExp::XPname] != 0 } {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_ExpExiste  ok warning "" $NewExp::win_new_xp
				  return
			}

                        NewExp::ExpDirectoriesConfig $NewExp::win_new_xp $NewExp::XpPath $NewExp::XPname $NewExp::EntryModName true}]
      
      pack $controlframe.lab -fill x

      pack $titn         -anchor w -pady 2 -padx 2 
      pack $ExpName      -side left -padx 4 

      pack $titp         -anchor w -pady 2 -padx 2 
      pack $ExpPath      -side left -padx 4 
      pack $subf3.butb   -side left -padx 4

      pack $tite         -anchor w -pady 2 -padx 2 
      pack $ExpEntryMod  -side left -padx 4 
      pack $ButModNotif  -side left -padx 4

      pack $titr -anchor w -pady 2 -padx 2
      pack $subf5.entryrespath -side top -pady 2
      pack $subf5.browseb -side left -padx 4 -pady 2
      pack $subf5.checkres -side left -padx 4 -pady 2
      pack $subf5.createdefb -side left -padx 4 -pady 2       

      pack $controlframe.sep -fill x -pady 4
      
      pack $ButCancel   -side left -padx  4 
      pack $NextB       -side left -padx  4 

      pack $controlframe.buttons -pady 4 -side bottom
      pack $controlframe -padx 8 -pady 8

      # - set the Experiments values
      set NewExp::XpPath $exp
      set NewExp::XPname ""


}

proc NewExp::Next_resume {parent path name entrymod arrloc arrentry} {

     variable NextResume

     if {[winfo exists  .next_resume]} {
             destroy  .next_resume
     }

     set NextResume [toplevel .next_resume]
     wm title $NextResume "$Dialogs::New_ExpTitle "
     wm minsize $NextResume 300 200

     if {[winfo exists $parent]} {
           destroy $parent
     }

     upvar $arrloc arlc
     upvar $arrentry arent


     set frm   [frame $NextResume.frm]
     set titre [TitleFrame $frm.t -text $Dialogs::New_Parametres]
     set sfrm  [$titre getframe]

     
     set Nlist [ListBox::create $sfrm.nl \
	       -relief sunken -borderwidth 1 \
      	       -dragevent 1 \
	       -width 40 -highlightthickness 0 -selectmode single -selectforeground white\
	       -height 20 \
	       -redraw 1 -dragenabled 1 \
	       -bg #FFFFFF \
	       -padx 0]

     set NElist [text  $sfrm.txt -width 80 -height 13 -bg #FFFFFF -font 10 -wrap none]

     set BFrame [frame $frm.bfrm]
     set Cancel [button $BFrame.cancel -image $XPManager::img_Cancel -command {destroy $NewExp::NextResume}]
     set Back   [button $BFrame.back -text "Back" -command {\
                   NewExp::ExpDirectoriesConfig $NewExp::win_new_xp $NewExp::XpPath $NewExp::XPname $NewExp::EntryModName false ;\
                   destroy $NewExp::NextResume}]
     set Ok     [button $BFrame.next   -text "Proceed" -command [list NewExp::CreateNew $NextResume $path $name $entrymod $arrloc $arrentry]]

     # -- Show other Parametres of New experiment:
     $NElist insert end "$Dialogs::New_ExpName:$name\n"     
     $NElist insert end "$Dialogs::New_ExpDest:$path\n"      
     $NElist insert end "$Dialogs::New_ExpEnMo:$entrymod\n"
     $NElist insert end "_______________________________________\n"
     $NElist insert end "\n"

     set remote_warning 0

     foreach loc {bin hub mod seq res lis log} {
              if {[string compare $arlc($loc) "local"] == 0} {
                      $NElist insert end  "Directory: $::DirFullName($loc) will be created locally\n"
	      } else {
                      if {$loc != "log"} {set remote_warning 1}
                      $NElist insert end  "Directory: $::DirFullName($loc) will be a link to  $arent($loc)\n"
	      }
     }

     pack $Cancel -side right
     pack $Back -side right  -padx 4
     pack $Ok -side right  -padx 4

     pack $BFrame -side bottom
     pack $NElist -fill x

     if {$remote_warning == 1} {
        set NEwarning [text  $sfrm.warning -width 80 -height 5 -bg #FFFFFF -font 10 -wrap none -fg red]
        $NEwarning insert end "$Dialogs::New_ExpRemoteWarning\n"
        pack $NEwarning -fill x
     }

     pack $titre -anchor w
     pack $frm
}

# ExpDirectoriesConfig: Creates a dialog for deciding whether to create a
# directory or create a link to another existing directory.
# In the case of importing, the choices will be the same, but if the experiment
# has a link, the link target will be shown in the text entry box by default.
#
# parent: Parent window calling this function
# path: target path of the experiment
# name : name of the new experiment
# first_time : boolean used to decide to clear the text entry boxes
# new : boolean value used to distinguish between importation and creation of a
#       new experiment.
proc NewExp::ExpDirectoriesConfig {parent path name entrymod {first_time true} {new true} {srcPath ""}} {

      variable PrefWinDirs
      variable Entrybin
      variable Entrylist
      variable Entryseq
      variable Entrymod
      variable Entryhub
      variable Entryres
      variable Entrylog

      variable ArrayDirLocations
      variable ArrayEntryValues

      if {[winfo exists .prefwindirs]} {
              destroy .prefwindirs
      }

      set PrefWinDirs  [toplevel .prefwindirs]

      wm title $PrefWinDirs $Dialogs::New_Dirs 
      wm minsize  $PrefWinDirs 600 300


      if {[winfo exists $parent]} {
           destroy $parent
      }

      set frm [frame $PrefWinDirs.frame -border 2 -relief flat]
      label $frm.lab -text  $Dialogs::New_Dirs -font "ansi 12 "
      set tdirs  [TitleFrame $frm.dirs  -text $Dialogs::New_Dirs]
      set subfdirs  [$tdirs getframe]
      
      
      array set ArrayDirLocations {
               bin   "local"
	       res   "local"
	       hub   "local"
	       lis   "local"
	       mod   "local"
	       seq   "local"
	       log   "local"
      }

      # array unset ArrayEntryValues
      # if { $first_time == true } {
         array set ArrayEntryValues {
             bin   ""
	          res   ""
	          hub   ""
	          lis   ""
	          mod   ""
	          seq   ""
	          log   ""
         }
      # }

      # In case of importation, set default values for text boxes.
      if { $new == false && $first_time == true} {
         # If one of the directories is a link, put the target of the link in
         # the corresponding text box as the default value.
         foreach loc {bin res mod} {
            set theFile $Import::_selected/$::DirFullName($loc)
            if { [file exists $theFile]} {
               if { [file type $theFile] == "link" } {
                  set ArrayEntryValues($loc) [file join $srcPath [file readlink $theFile ]]
               } else {
                  set ArrayEntryValues($loc) $theFile
               }
            }
         }
      }

      set CtrlButton     [frame  $frm.ctrlbuttons -border 2 -relief flat]
      set CancelB        [button $CtrlButton.ok     -image $XPManager::img_Cancel -command {destroy $NewExp::PrefWinDirs}]
      set HelpB          [button $CtrlButton.bhelp  -image $XPManager::img_Help   -command {}]
      set NextB          [button $CtrlButton.next   -image $XPManager::img_Next   -command [\
                                                                                       list NewExp::FinalCheck $NewExp::PrefWinDirs $path $name $entrymod \
                                                                                       NewExp::ArrayDirLocations NewExp::ArrayEntryValues $new
                                                                                    ]]

      set dir_bin        [label $subfdirs.bin     -text "bin "            -font "10"]
      set dir_resources  [label $subfdirs.res     -text "resources "      -font "10"]
      set dir_hub        [label $subfdirs.hub     -text "hub "            -font "10"]
      set dir_listings   [label $subfdirs.list    -text "listings "       -font "10"]
      set dir_modules    [label $subfdirs.modl    -text "modules "        -font "10"]
      set dir_sequencing [label $subfdirs.seq     -text "sequencing "     -font "10"]
      set dir_logs       [label $subfdirs.log     -text "logs "           -font "10"]
      
      set dir_name       [label $subfdirs.name    -text $Dialogs::New_DirName    -font "10"]
      set dir_local      [label $subfdirs.local   -text "Local"                  -font "10"]
      set dir_remote     [label $subfdirs.remote  -text "Remote"                 -font "10"]
      set dir_pointer    [label $subfdirs.pointer -text $Dialogs::New_Pointto    -font "10"]

      # -- Editors
      set radbin_local   [radiobutton $subfdirs.radbinl -text "" -variable bin -value local  -command  {\
			  $NewExp::Entrybin configure -text "" ;\
			  set NewExp::ArrayDirLocations(bin) "local" ;\
                          $NewExp::Entrybin configure -state disabled -text $ArrayEntryValues(bin)}]
      set radbin_remote  [radiobutton $subfdirs.radbinr -text "" -variable bin -value remote -command  {\
			  set NewExp::ArrayDirLocations(bin) "remote" ;\
                          $NewExp::Entrybin configure -state normal}]

      set radres_local   [radiobutton $subfdirs.radresl -text "" -variable res -value local  -command  {\
			   $NewExp::Entryres configure -text "" ;\
			   set NewExp::ArrayDirLocations(res) "local" ;\
                           $NewExp::Entryres configure -state disabled}]
      set radres_remote  [radiobutton $subfdirs.radresr -text "" -variable res -value remote -command  {\
			  set NewExp::ArrayDirLocations(res) "remote" ;\
                          $NewExp::Entryres configure -state normal}]

      set radhub_local   [radiobutton $subfdirs.radhubl -text "" -variable hub -value local  -command  {\
			   $NewExp::Entryhub configure -text "" ;\
			  set NewExp::ArrayDirLocations(hub) "local" ;\
                           $NewExp::Entryhub configure -state disabled}]
      set radhub_remote  [radiobutton $subfdirs.radhubr -text "" -variable hub -value remote -command  {\
			  set NewExp::ArrayDirLocations(hub) "remote" ;\
                           $NewExp::Entryhub configure -state normal}]

      set radlis_local   [radiobutton $subfdirs.radlisl -text "" -variable lis -value local  -command  {\
			   $NewExp::Entrylist configure -text "" ;\
			  set NewExp::ArrayDirLocations(lis) "local" ;\
                           $NewExp::Entrylist configure -state disabled}]
      set radlis_remote  [radiobutton $subfdirs.radlisr -text "" -variable lis -value remote -command  {\
			  set NewExp::ArrayDirLocations(lis) "remote" ;\
                           $NewExp::Entrylist configure -state normal}]

      set radmod_local   [radiobutton $subfdirs.radmodl -text "" -variable mod -value local  -command  {\
                           $NewExp::Entrymod configure -state disabled}]
      set radmod_remote  [radiobutton $subfdirs.radmodr -text "" -variable mod -value remote -command  {\
                           $NewExp::Entrymod configure -state normal}]

      set radseq_local   [radiobutton $subfdirs.radseql -text "" -variable seq -value local  -command  {\
                           $NewExp::Entryseq configure -text "" ;\
			  set NewExp::ArrayDirLocations(seq) "local" ;\
                           $NewExp::Entryseq configure -state disabled}]
      set radseq_remote  [radiobutton $subfdirs.radseqr -text "" -variable seq -value remote -command  {\
                           set NewExp::ArrayDirLocations(seq) "remote" ;\
                           $NewExp::Entryseq configure -state normal}]

      set radlog_local   [radiobutton $subfdirs.radlogl -text "" -variable log -value local  -command  {\
                           $NewExp::Entrylog configure -text "" ;\
			  set NewExp::ArrayDirLocations(seq) "local" ;\
                           $NewExp::Entrylog configure -state disabled}]
      set radlog_remote  [radiobutton $subfdirs.radlogr -text "" -variable log -value remote -command  {\
                           set NewExp::ArrayDirLocations(log) "remote" ;\
                           $NewExp::Entrylog configure -state normal}]


      # -- Put default values for entries

      set Entrybin        [Entry $subfdirs.ebin -text $ArrayEntryValues(bin)  -textvariable ArrayEntryValues(bin) -width 25  -bg #FFFFFF -font 12 -helptext "remote bin" \
                           -validate key\
			   -validatecommand {NewExp::ValidKey "bin" NewExp::ArrayEntryValues %d %V %P}\
		           -command  {}]

      set Entryhub        [Entry $subfdirs.ehub -textvariable ehub -width 25  -bg #FFFFFF -font 12 -helptext "remote hub" \
                           -validate key\
			   -validatecommand {NewExp::ValidKey "hub" NewExp::ArrayEntryValues %d %V %P}\
		           -command  {}]
      
      set Entryres        [Entry $subfdirs.eres -text $ArrayEntryValues(res) -textvariable eres -width 25  -bg #FFFFFF -font 12 -helptext "remote resources" \
                           -validate key\
			   -validatecommand {NewExp::ValidKey "res" NewExp::ArrayEntryValues %d %V %P}\
		           -command  {}]

      set Entrylist       [Entry $subfdirs.elist -textvariable elist -width 25 -bg #FFFFFF -font 12 -helptext "remote listings" \
                           -validate key\
			   -validatecommand {NewExp::ValidKey "lis" NewExp::ArrayEntryValues %d %V %P}\
		           -command  {}]
      
      set Entrymod        [Entry $subfdirs.emod -text $ArrayEntryValues(mod) -textvariable mod -width 25  -bg #FFFFFF -font 12 -helptext "" \
		           -command  {}]

      set Entryseq        [Entry $subfdirs.eseq -textvariable eseq -width 25  -bg #FFFFFF -font 12 -helptext "remote sequencing" \
		           -validate key\
			   -validatecommand {NewExp::ValidKey "seq" NewExp::ArrayEntryValues %d %V %P}\
		           -command  {}]

      
      set Entrylog        [Entry $subfdirs.elog -textvariable elog -width 25  -bg #FFFFFF -font 12 -helptext "remote log" \
		           -validate key\
			   -validatecommand {NewExp::ValidKey "log" NewExp::ArrayEntryValues %d %V %P}\
		           -command  {}]

      # -- pack Ok/Cancel butt.
      pack $CtrlButton -side bottom
      pack $NextB -side right -padx 4
      pack $HelpB -side left -padx 4
      pack $CancelB -side left -padx 4

      # -- pack editors wid.
      pack $tdirs -fill x -pady 2 -padx 2

      grid $dir_name          -row 0 -column 0 -stick e -padx 8
      grid $dir_local         -row 0 -column 1 -stick w -padx 8
      grid $dir_remote        -row 0 -column 2 -stick w -padx 8
      grid $dir_pointer       -row 0 -column 3 -stick w -padx 8

      grid $dir_bin           -row 1 -column 0 -stick e -padx 8
      grid $radbin_local      -row 1 -column 1 -stick w -padx 8
      grid $radbin_remote     -row 1 -column 2 -stick w -padx 8
      grid $Entrybin          -row 1 -column 3 -stick w -padx 8

      grid $dir_hub           -row 2 -column 0 -stick e -padx 8
      grid $radhub_local      -row 2 -column 1 -stick w -padx 8
      grid $radhub_remote     -row 2 -column 2 -stick w -padx 8
      grid $Entryhub          -row 2 -column 3 -stick w -padx 8

      grid $dir_resources     -row 3 -column 0 -stick e -padx 8
      grid $radres_local      -row 3 -column 1 -stick w -padx 8
      grid $radres_remote     -row 3 -column 2 -stick w -padx 8
      grid $Entryres          -row 3 -column 3 -stick w -padx 8

      grid $dir_listings      -row 4 -column 0 -stick e -padx 8
      grid $radlis_local      -row 4 -column 1 -stick w -padx 8
      grid $radlis_remote     -row 4 -column 2 -stick w -padx 8
      grid $Entrylist         -row 4 -column 3 -stick w -padx 8

      grid $dir_modules       -row 5 -column 0 -stick e -padx 8
      grid $radmod_local      -row 5 -column 1 -stick w -padx 8
      grid $radmod_remote     -row 5 -column 2 -stick w -padx 8
      grid $Entrymod          -row 5 -column 3 -stick w -padx 8

      grid $dir_sequencing    -row 6 -column 0 -stick e -padx 8
      grid $radseq_local      -row 6 -column 1 -stick w -padx 8
      grid $radseq_remote     -row 6 -column 2 -stick w -padx 8
      grid $Entryseq          -row 6 -column 3 -stick w -padx 8
      
      grid $dir_logs          -row 7 -column 0 -stick e -padx 8
      grid $radlog_local      -row 7 -column 1 -stick w -padx 8
      grid $radlog_remote     -row 7 -column 2 -stick w -padx 8
      grid $Entrylog          -row 7 -column 3 -stick w -padx 8

      pack $frm

      
      # -- by Default all directories Local
      $radbin_local  select
      $radhub_local  select
      $radres_local  select
      $radlis_local  select
      $radmod_local  select 
      $radseq_local  select
      $radlog_local  select

      $radmod_remote configure -state disabled
      #$radlog_remote configure -state disabled
      #$radseq_remote configure -state disabled 
      
      
      # -- At Entry Disable All Remote Entry 
      $NewExp::Entrybin   configure -state disabled
      $NewExp::Entryhub   configure -state disabled
      $NewExp::Entryres   configure -state disabled
      $NewExp::Entrylist  configure -state disabled
      $NewExp::Entrymod   configure -state disabled
      $NewExp::Entryseq   configure -state disabled
      $NewExp::Entrylog   configure -state disabled
      
     
}

proc NewExp::ValidKey { ArgVar arrayent action type str } {
          upvar $arrayent arrayentries

          switch $type {
               "key" {
                        if { $action == 1 } {
                                 eval set $ArgVar \"$str\"
                                 if {[string compare $str "" ] != 0 && ! [regexp {[!@#%^\*\(\)=~<>|]} $str]} {
                                            set  arrayentries($ArgVar) $str
                                 } 
                                 return 1
                        } elseif { $action == 0 } {
                                 set  arrayentries($ArgVar) $str
                                 return 1
                        }
                     }
          }
          return 1
}

proc NewExp::CheckPath {path} {
	  # -- Path must be readabl|writable by user
	  if {[file isdirectory $path] && [file executable $path] && [file writable $path]} {
	           return 0
	  } else {
	           return 1
	  }
}

proc NewExp::ValuePath {widg} {
          # -- if the path not in list path -> Check path ?
          # -- Set the Variable
          set NewExp::XpPath [string trimright [$widg get] "/"]
	  if { ! [regexp {[^\/][A-Za-z0-9_\-\.\/]+$} NewExp::XpPath]} {
	          Dialogs::show_msgdlg $Dialogs::Dlg_NoValExpPath  ok warning "" .newxp
		  return 0
	  }

	  # -- path must not be HOME/
	  if {[string compare $::env(HOME) $NewExp::XpPath] == 0 } {
	         Dialogs::show_msgdlg $Dialogs::Dlg_NotUnderHOME  ok warning "" .newxp
                 return 0
	  }
}

proc NewExp::ValueName {widg} {
          # -- Check variable 
          # -- Set the Variable
          set NewExp::XPname [$widg get] 
          
	  # -- validated by the Enter command
          if { ! [regexp {^[A-Za-z0-9_\-\.]+$} $NewExp::XPname ]} {
	                          Dialogs::show_msgdlg $Dialogs::Dlg_ExpInvalidName  ok warning "" $NewExp::win_new_xp
				  return
          }
}

#------------------------------------------------------
# NewExp::FinalCheck
#
# Check if remote dirs have values
# Note : check here if an exp with the same name exist!!!1
#------------------------------------------------------
proc NewExp::FinalCheck { win path name entrmod arlocation arvalues new} {
       
       upvar  $arlocation arloc
       upvar  $arvalues   arval


       set arerror {}
       foreach loc {bin hub res lis seq log} {
	       if {[string compare $arloc($loc) "remote"] == 0 && \
	           [string compare $arval($loc) ""] == 0 } {
	             lappend arerror "$loc"    
	           }
       }

  
      if {[llength $arerror] != 0 } {
             Dialogs::show_msgdlg $Dialogs::New_NoRemoteDirs:[join $arerror " "]  ok warning "" $win 
	     return
      } else {
         # OK, ready to create new or import 
         if { $new == true } {
            NewExp::Next_resume $win $path $name $entrmod $arlocation $arvalues
         } else {
            Import::ImportNext $NewExp::PrefWinDirs $Import::_importname \
               $Import::_selected $Import::Destination $Import::_ImportGit \
               $Import::_ImportCte NewExp::ArrayDirLocations NewExp::ArrayEntryValues
         }
      }
}

proc NewExp::CreateNew {parent path name entrymod arrloc arrentry} {

       global SEQ_MANAGER_BIN
       global ArrayTabsDepot


       upvar $arrloc arloc 
       upvar $arrentry arentry
    
       #clock format [clock seconds] -format {%Y%m%d%H0000} 2005 01 10 15 16 55

       # -- get today's date
       set date    [clock format [clock seconds] -format {%d %b %Y}] 
       set dateExp [clock format [clock seconds] -format {%Y%m%d%H0000}] 

       # -- rm trailing slash
       set path [string trimright $path "/"]

       if [catch { 
               catch {[exec mkdir -p $path/$name]}
       } message ] {
             Dialogs::show_msgdlg "Unable to create Experiment Directory"  ok warning "" $parent 
	     return
       }

       set header2 "<MODULE name=\"$entrymod\" version_number=\"1.0\" date=\"$date\">"
       set footer  "</MODULE>" 

       if [catch {
               catch {[exec mkdir -p $path/$name/modules]}
               catch {[exec mkdir -p $path/$name/modules/$entrymod]}
               catch {[exec ln -s modules/$entrymod $path/$name/EntryModule]}
       } message ] {
             Dialogs::show_msgdlg "Unable to create sub-Experiment Directories: $message"  ok warning "" $parent 
	     return
       }
       
       set fo [open "$path/$name/modules/$entrymod/flow.xml" "w"] 
       puts  $fo "$header2"  
       puts  $fo "$footer"  
       close $fo

       # -- for local and remote directory Creation
       set l_error 0
       set r_error 0
       foreach loc {bin hub res lis seq log} {
	       if {[string compare $arloc($loc) "local"] == 0 } {
                           if [catch { exec mkdir -p $path/$name/$::DirFullName($loc) }] {
                                   set l_error 1
			   }
               } else {
	                   if [catch { exec ln -s $arentry($loc) $path/$name/$::DirFullName($loc) }] {
                                   set r_error 1
			   } else {
		                   exec mkdir -p $arentry($loc)/$::DirFullName($loc)
                           }
	       }
       }

       # -- see if errors  Note no rollback at this point
       if { $l_error == 1 } {
             Dialogs::show_msgdlg "Unable to create sub-Experiment Directories (bin|hub|resources|listing|sequencing|logs)"  ok warning "" $parent 
       }

       if { $r_error == 1 } {
             Dialogs::show_msgdlg "Unable to create sub-Experiment links (bin|hub|resources|listing|sequencing|logs)"  ok warning "" $parent 
       }

       # -- under resources create entry mod.
       if [  catch { exec mkdir -p $path/$name/resources/$entrymod } ] {
             Dialogs::show_msgdlg "Unable to create Entry Module:$entrymod under resources"  ok warning "" $parent 
       }
       if { $NewExp::ResFilePath != "" } {
          exec cp $NewExp::ResFilePath $path/$name/resources/resources.def
       }

       # -- if every things is ok update. 
       # Note 1 :First time user do not have a repository yet
       # Note 2 :a user could create a new Exp which is not under the current repository ie another root
       #         should merge the new root into old Repository

       # -- get the first and only tab for now
       if {[llength $Preferences::ListUsrTabs] != 1 } {
               Dialogs::show_msgdlg "Please examine your \$HOME/.maestrorc file, navtabs preference is missing puting default:My_experiments"  ok warning "" $parent 
       }

       set ftab [string trim [lindex $Preferences::ListUsrTabs 0] " "]
       if {[info exists ArrayTabsDepot($ftab) ] != 0 } {
                    
                     set home "$::env(HOME)"
		     regsub -all {/} $home  {\/} home
                     regsub -all "$home" $path {} npath
		     set npth [string trim  $npath "/"]

                     # -- See if path is in Usr Repository
		     set ltmp [split $ArrayTabsDepot($ftab) ":"]
		     set ltmph [join $ltmp " "]

		     if {[lsearch -regexp $ltmp "\/$npth"] < 0 } {
		               # -- Not in the Repository.
			       lappend ltmp [string trimright $path "/"]
			       set lpath [join $ltmp ":"]

			       # -- update array var
			       set ArrayTabsDepot($ftab) $lpath
			       
			       # -- update config file
			       regsub -all {/} $lpath {\/} lpath
			       catch {file delete $::env(TMPDIR)/.maestrorc}
			       catch {[exec cat $::env(HOME)/.maestrorc  | sed "s/^$ftab\.*=\.\*/$ftab=$lpath/g" >  $::env(TMPDIR)/.maestrorc]}
			       catch {[exec cp  $::env(TMPDIR)/.maestrorc $::env(HOME)/.maestrorc]}
                               
			       # -- we should update the liste of ALL Exp's :  XPManager::ListExperiments
			       XPManager::ListExperiments
		     } 
		     
		     # -- Update Tree
                     XTree::reinit $::TreesWidgets($ftab)  {*}$ltmp
       } else {
                     XTree::reinit $::TreesWidgets($ftab) $path
		     # -- Have to update Pref. variable
		     catch {[exec echo "$ftab=$path" >> $::env(HOME)/.maestrorc]}
		     # -- redo parsing of pref. file
		     Preferences::ParseUserMaestrorc
       }

       # -- Inform User
       Dialogs::show_msgdlg $Dialogs::Dlg_BrowserUpdated  ok info "" $parent

       # -- Re-generate listof exp
       XPManager::ListExperiments 

       # -- Ok , destroy window
       if {[winfo exists $parent]} {
                destroy $parent
       }
}
