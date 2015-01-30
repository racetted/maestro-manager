global array TreesWidgets
global array ArrayTabsDepot

namespace eval Preferences {

           variable  PreferenceWindow

	   variable ERROR_NOT_RECOGNIZED_PREF  0
           variable ERROR_PARSING_USER_CONFIG 0
	   variable ERROR_DEPOT_DO_NOT_EXIST 0
           
	   # -- Preferences lists of user tabs
	   variable ListUsrTabs

	   # -- Preference variables
	   variable auto_msg_display
	   variable auto_launch
	   variable show_abort_type
	   variable show_event_type
	   variable show_info_type
	   variable node_display_pref
	   variable default_console
           variable default_console_args
	   variable text_viewer
	   variable text_viewer_args
	   variable browser
	   variable browser_args
	   variable flow_geometry
	   variable background_image
	   variable exp_icon
	   variable exp_icon_img
	   variable xflow_scale
	   variable use_bell
	   variable user_tmp_dir
	   variable ChosenIcon
	   variable ListWallPapers

	   variable EntryBcgkColor "#FFFFFF"


}

#---------------------------------------------------------------------------------
#
#
#---------------------------------------------------------------------------------
proc Preferences::PrefShow {} {
      
      variable  PreferenceWindow

      if {[winfo exists .prefwin]} {
               destroy .prefwin
      }

      set PreferenceWindow [toplevel .prefwin] 
      wm title   $PreferenceWindow $Dialogs::Pref_title 
      wm minsize $PreferenceWindow 700 340

      set frm [ frame $PreferenceWindow.frame -border 2 -relief flat]
      label $frm.lab -text $Dialogs::Pref_title -font "ansi 12 "

      # -- Create a NoteBook
      set nbook [NoteBook ${frm}.nb]

      $nbook  insert 0 TextEditor      -text $Dialogs::NotB_TextEdit 
      $nbook  insert 1 W3Browsers      -text $Dialogs::NotB_Browsers 
      $nbook  insert 2 Konsoles        -text $Dialogs::NotB_Konsole
      $nbook  insert 3 MaestroEvents   -text $Dialogs::NotB_Events
      $nbook  insert 4 WallPaperIcons  -text $Dialogs::NotB_WallIco

      foreach panel {TextEditor W3Browsers Konsoles MaestroEvents WallPaperIcons} {
              set pane [$nbook getframe $panel]
              ${panel}CreateWidget $pane 
	      #$nbook itemconfigure $panel -createcmd  "Preferences::${panel}Create $pane $PrefWin" 
              $nbook raise $panel 
      }


      $nbook compute_size
      $nbook raise TextEditor 

      pack $frm     -fill x
      pack $frm.lab -fill x
      pack $nbook   -fill both -expand yes -padx 4 -pady 4
}

#---------------------------------------------------------------------------------
#
#
#---------------------------------------------------------------------------------
proc Preferences::Lselect { W } {
    variable ExpPathsRemove
    variable CancelBU
    variable OkBU
    variable SelectionToRemove

    set chosen [$W curselection]
    #$W delete $chosen 
    #$W itemconfigure $chosen -foreground red

    # -- Set selection to remove
    set SelectionToRemove $chosen

    $ExpPathsRemove configure -state normal
    $CancelBU       configure -state normal
    $OkBU           configure -state disabled

}

#---------------------------------------------------------------------------------
#
#
#---------------------------------------------------------------------------------
proc Preferences::ConfigDepot { } {

      variable listPath
      variable SaveBU
      variable CancelBU
      variable OkBU
      variable ExpPathsRemove
      variable SelectionToRemove

      variable  ConfigDepotWin

      if {[winfo exists .confdepotwin]} {
               destroy .confdepotwin
      }

      set ConfigDepotWin [toplevel .confdepotwin] 
      wm title   $ConfigDepotWin $Dialogs::Pref_depot_title 
      wm minsize $ConfigDepotWin 600 300

      set frm [ frame $ConfigDepotWin.frame -border 2 -relief flat]
      label $frm.lab -text "Experiments Depot Setting" -font "ansi 12 "
     
      # -- Get the first tab for now
      set Tname  [string trim [lindex $Preferences::ListUsrTabs 0] " "]

      # -- Create a NoteBook
      set tbook [NoteBook ${frm}.nb]
      $tbook  insert 0 $Tname  -text "$Tname" 

      set tpane [$tbook getframe $Tname]

      set t2 [TitleFrame $tpane.titf2 -text $Dialogs::NotB_ExpDepot]
      set subfP [$t2 getframe]

      # -- Where to put add/remove butt.
      set AddRemButton [frame  $tpane.addrembuttons -border 2 -relief flat]
      set ExpPathsBadd [Button $AddRemButton.butadd  -image $XPManager::img_Add -command "Preferences::AddExpToDepot $Tname"]
      set listPath     [ListBox::create $subfP.lb \
                        -relief sunken -borderwidth 1 \
		        -dragevent 1 \
		        -width 50 -highlightthickness 0 -selectmode single -selectforeground blue\
		        -redraw 1 -dragenabled 1 \
		        -bg #FFFFFF \
		        -padx 0\
		        -droptypes {LISTBOX_ITEM {copy {} move {} link {}}}]

      bind $listPath <<ListboxSelect>> [list Preferences::Lselect %W]
      
      set ExpPathsRemove [Button $AddRemButton.butrem   \
                        -image $XPManager::img_Remove \
                        -command {\
			           $Preferences::listPath delete $Preferences::SelectionToRemove
				   $Preferences::SaveBU configure -state normal
				  }]

      # -- Populate list with user Exp's paths 
      # -- get depot for notebook
      set listexp [Preferences::GetTabListDepots [string trim $Tname " "] "r"]
     
      if {[string compare $listexp "" ] != 0 } {
           foreach upath $listexp { 
               if { [string compare $upath "no-selection"] != 0 } {
                        $listPath insert end "$upath" -text "$upath" 
               }
           }
      }

      set CtrlButton [frame $tpane.ctrlbuttons -border 2 -relief flat]
      set OkBU       [button $CtrlButton.ok     -image $XPManager::img_Ok     -command {destroy $Preferences::ConfigDepotWin}]
      set CancelBU   [button $CtrlButton.cancel -image $XPManager::img_Cancel -command {destroy $Preferences::ConfigDepotWin}]
      set SaveBU     [button $CtrlButton.save   -image $XPManager::img_Save   -command "Preferences::SaveDepotToConfig $Tname"]
     
      # -- pack Ok/Cancel butt.
      pack $CtrlButton -side bottom
      pack $SaveBU     -side right -padx 4
      pack $OkBU       -side left -padx 4
      pack $CancelBU   -side left -padx 4

      pack $ExpPathsBadd -anchor w -padx 4
      pack $ExpPathsRemove -anchor w -padx 4

      pack $t2 -side left -padx 4
      pack $AddRemButton -side left -padx 4
      pack $listPath -anchor  w -padx 4

      pack $frm     -fill x
      pack $tbook   -fill both -expand yes -padx 4 -pady 4

      # -- first disable until changes in User Xp. list 
      $SaveBU         configure -state disabled
      $CancelBU       configure -state disabled
      $ExpPathsRemove configure -state disabled

      $tbook compute_size
      $tbook raise $Tname 
}


#---------------------------------------------------------------------------------
#
#
#---------------------------------------------------------------------------------
proc Preferences::AddExpToDepot { nbk } {

    set ExpDir [tk_chooseDirectory -initialdir $::env(HOME)/ -title "Choose Experiment directory" -parent $Preferences::ConfigDepotWin]

    if {[string equal $ExpDir ""]} {
           return
    }
    if {[file isdirectory $ExpDir]} {
                 set numslash [regsub -all {\/} $ExpDir "" kiki]
                 if {[string compare $ExpDir [file normalize $::env(HOME)]] == 0 || [string compare $ExpDir "/" ] == 0 } {
                             Dialogs::show_msgdlg $Dialogs::Dlg_PathDeep  ok error "" $Preferences::ConfigDepotWin
	                     return
	            }

                    XPManager::show_progdlg $Preferences::ConfigDepotWin "Finding Experiments in progress "
                    set ret [Preferences::FindAndValidateExpDir $ExpDir $nbk]
                    destroy $Preferences::ConfigDepotWin.progress 

	            switch $ret {
	                          0 {
                                         # -- Ok add it to list ,but before check if altready there
                                         set itms [$Preferences::listPath items]
	                                 set litems [split $itms " "]
                                         # -- need grep maybe 
	                                 set _error 0
                                         foreach it $litems {
	                                        if { $it == $ExpDir } {
                                                       Dialogs::show_msgdlg $Dialogs::Dlg_ExpPathInList  ok error "" $Preferences::ConfigDepotWin
			                               set _error 1
                                                   } 
                                         }

	                                 if { $_error == 0 } {
                                                   regsub -all {[ \t]*} $ExpDir {} ExpDir 
                                                   $Preferences::listPath insert end "$ExpDir" -text "$ExpDir" 
					 }
				    }
                                  1 {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_NoExpPath      ok error "" $Preferences::ConfigDepotWin
					 return
		                    }
                                  2 {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_ExpPathInList  ok error "" $Preferences::ConfigDepotWin
					 return
		                    }
                                  3 {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_NoValExpPath   ok error "" $Preferences::ConfigDepotWin
					 return
		                    }
				  }
	            # -- Empty Entry
		    set ExpDir ""
  
                    $Preferences::SaveBU         configure -state normal
                    $Preferences::CancelBU       configure -state normal
                    $Preferences::OkBU           configure -state disabled
   } else {
		    Dialogs::show_msgdlg $Dialogs::Dlg_NoValExpPath  ok error "" $Preferences::ConfigDepotWin
		    return
   }
}

#---------------------------------------------------------------------------------
#
#
#---------------------------------------------------------------------------------
proc Preferences::SaveDepotToConfig { nbk } {

  global ArrayTabsDepot

  set itms   [$Preferences::listPath items]
  set litems [split $itms " "]
  set lPath  [lindex $litems 0]

  # -- remove from list
  set litems [lreplace $litems 0 0]

  foreach pth $litems {
        set lPath  $lPath:$pth
  }

  # Note : A user can add path to his allready defined Exp. paths  
  # -- Check if user has the token in the file

  # -- Get depot for notebook
  set listxp [Preferences::GetTabListDepots $nbk "r"]

  if {[string compare $listxp ""] != 0} {
         # -- Slash is special char. protect it  
         regsub -all {/} $lPath {\/} lPath
	 catch {file delete $::env(TMPDIR)/.maestrorc}

	 if {[string compare $lPath ""] != 0} {
                  catch {[exec cat $::env(HOME)/.maestrorc  | sed "s/^$nbk\.*=\.\*/$nbk=$lPath/g" >  $::env(TMPDIR)/.maestrorc]}  
         } else {
                  catch {[exec cat $::env(HOME)/.maestrorc  | grep -v "^$nbk" >  $::env(TMPDIR)/.maestrorc]}  
	 }

         if {[file exist  $::env(TMPDIR)/.maestrorc]} {
                   # -- ok cp to HOME
                   catch {set retv [exec cp $::env(TMPDIR)/.maestrorc $::env(HOME)/.maestrorc]} 
         } else {
                   Dialogs::show_msgdlg "Error copying config file"  ok warning "" $Preferences::ConfigDepotWin
		   return
	 }
	 set retv 0
  } else {
         if [catch {exec echo "$nbk=$lPath" >> $::env(HOME)/.maestrorc}] {
                   Dialogs::show_msgdlg "Error copying config file"  ok warning "" $Preferences::ConfigDepotWin
		   return
         }
  }

  # -- Update depot
  set ArrayTabsDepot($nbk) [join [$Preferences::listPath items] ":"]

  # -- we should update the liste of ALL Exp's :  XPManager::ListExperiments
  XPManager::ListExperiments

  # -- Update XpBrowser
  set ret [Dialogs::show_msgdlg $Dialogs::Dlg_UpdateExpBrowser  yesno question "" $Preferences::ConfigDepotWin]
  if { $ret == 0 } {
	       # -- Ok Update XpBrowser NOTE: For Now Always User Tree
	       set crap_tcl [$Preferences::listPath items] 
	       XTree::reinit $::TreesWidgets($nbk) {*}$crap_tcl
  }

  # should disable remove ,save,cancel button here
  $Preferences::ExpPathsRemove configure -state disabled
  $Preferences::SaveBU         configure -state disabled
  $Preferences::CancelBU       configure -state disabled
  $Preferences::OkBU           configure -state normal

  # -- if no Exp at all Undef depot 
  # -- How many tem
  set nitem [$Preferences::listPath items]
  if {[string compare $nitem ""] == 0} {
           unset ArrayTabsDepot($nbk)
  }
   
}

proc Preferences::TextEditorCreateWidget { frm } {

      variable SaveBT
      variable CancelBT
      variable OkBT
      variable ChosenEditor
      variable ChosenEditorArgs
      variable subfeditor

      set Preferences::ChosenEditor     ""
      set Preferences::ChosenEditorArgs ""

      label $frm.lab -text "Editor Setting" -font "ansi 12 "

      set teditor  [TitleFrame $frm.editor  -text $Dialogs::NotB_TextEdit]

      set subfeditor  [$teditor getframe]
      
      set CtrlButton  [frame $frm.ctrlbuttons -border 2 -relief flat]
      set CancelBT    [button $CtrlButton.cancel  -image $XPManager::img_Cancel -command {destroy $Preferences::PreferenceWindow}]
      set OkBT        [button $CtrlButton.ok      -image $XPManager::img_Ok     -command {destroy $Preferences::PreferenceWindow }]
      set SaveBT      [button $CtrlButton.save    -image $XPManager::img_Save   -command {\
                       Preferences::SavePref "text_viewer" $Preferences::SaveBT $Preferences::CancelBT \
		       $Preferences::OkBT $Preferences::ChosenEditor $Preferences::ChosenEditorArgs}]
 

      set args        [label $subfeditor.args -text "Arguments " -font 10]


      # -- Editors
      set txtvi       [label $subfeditor.vitxt -text "gvim (default) " -font 10]
      set radEvi      [radiobutton $subfeditor.radE1  -variable t -value "gvim" -command  {\
                        Preferences::UpdateButtons "text_viewer" "gvim" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor vi emacs xemacs kate oth
			}]

      
      set txtemacs    [label $subfeditor.emacstxt -text "emacs " -font 10]
      set radEmacs    [radiobutton $subfeditor.radE2  -variable t -value "emacs" -command  {\
                        Preferences::UpdateButtons "text_viewer" "emacs" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
		        # -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor emacs xemacs kate vi oth
			}]

      
      set txtxemacs   [label $subfeditor.xemacstxt -text "xemacs " -font 10]
      set radXEmacs   [radiobutton $subfeditor.xradE3 -variable t -value "xemacs" -command  {\
                        Preferences::UpdateButtons "text_viewer" "xemacs" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor xemacs emacs kate vi oth
			}]

      
      set txtkate     [label $subfeditor.katetxt -text "kate " -font 10]
      set radEkate    [radiobutton $subfeditor.radE4  -variable t -value "kate" -command  {\
                        Preferences::UpdateButtons "text_viewer" "kate" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor kate emacs xemacs  vi oth

			}]

      set txtother    [label $subfeditor.other -text "Other " -font 10]
      set radOther    [radiobutton $subfeditor.roth    -variable t -value "oth" -command  {\
                        Preferences::UpdateButtons "text_viewer" "other" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT;\
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor oth vi emacs xemacs kate;\
			}]


      set EntryEvi    [Entry $subfeditor.vi      -textvariable ke1 -width 50 -bg $Preferences::EntryBcgkColor \
                          -helptext "Give the arguments" -command  {\
		           $Preferences::SaveBT configure -state normal
			   set Preferences::ChosenEditorArgs "$ke1" 
		        }\
                        -validate key\
                        -validatecommand {Preferences::ValidKey $Preferences::SaveBT Preferences::ChosenEditorArgs %d %V %P}\
                        ]

      set EntryEmacs  [Entry $subfeditor.emacs   -textvariable ke2 -width 50 -bg $Preferences::EntryBcgkColor \
                           -helptext "Give the arguments" -command  {\
		           $Preferences::SaveBT configure -state normal
			   set Preferences::ChosenEditorArgs "$ke2" 
		        }\
                        -validate key\
                        -validatecommand {Preferences::ValidKey $Preferences::SaveBT Preferences::ChosenEditorArgs %d %V %P}\
			]
      
      set EntryXEmacs [Entry $subfeditor.xemacs -textvariable ke3 -width 50 -bg $Preferences::EntryBcgkColor \
                           -helptext "Give the arguments" -command  {\
		           $Preferences::SaveBT configure -state normal
			   set Preferences::ChosenEditorArgs "$ke3" 
		        }\
                        -validate key\
                        -validatecommand {Preferences::ValidKey $Preferences::SaveBT Preferences::ChosenEditorArgs %d %V %P}\
			]
      
      set EntryEkate  [Entry $subfeditor.kate   -textvariable ke4 -width 50 -bg $Preferences::EntryBcgkColor \
                           -helptext "Give the arguments" -command  {\
		           $Preferences::SaveBT configure -state normal
			   set Preferences::ChosenEditorArgs "$ke4"
		        }\
                        -validate key\
                        -validatecommand {Preferences::ValidKey $Preferences::SaveBT Preferences::ChosenEditorArgs %d %V %P}\
			]

      set EntryOth    [Entry $subfeditor.oth     -textvariable ke5 -width 50 -bg $Preferences::EntryBcgkColor \
                          -helptext "Give the command and the arguments" -command  {\
		           $Preferences::SaveBT configure -state normal
			   set Preferences::ChosenEditorArgs "$ke5" 
		        }\
                        -validate key\
                        -validatecommand {Preferences::ValidKey $Preferences::SaveBT Preferences::ChosenEditorArgs %d %V %P}]

  
      # -- pack Ok/Cancel butt.
      pack $CtrlButton  -side bottom
      pack $SaveBT      -side right -padx 4
      pack $OkBT        -side left  -padx 4
      pack $CancelBT    -side left  -padx 4

      # -- pack editors wid.
      pack $teditor -fill x -pady 2 -padx 2

      grid $args        -row 0 -column 3 -stick w

      grid $radEvi      -row 1 -column 1 -stick e
      grid $txtvi       -row 1 -column 2 -stick w
      grid $EntryEvi    -row 1 -column 3 -stick e

      grid $radEmacs    -row 2 -column 1 -stick e
      grid $txtemacs    -row 2 -column 2 -stick w
      grid $EntryEmacs  -row 2 -column 3 -stick e
      
      grid $radXEmacs   -row 3 -column 1 -stick e
      grid $txtxemacs   -row 3 -column 2 -stick w
      grid $EntryXEmacs -row 3 -column 3 -stick e

      grid $radEkate    -row 4 -column 1 -stick e
      grid $txtkate     -row 4 -column 2 -stick w
      grid $EntryEkate  -row 4 -column 3 -stick e

      grid $radOther    -row 5 -column 1 -stick e
      grid $txtother    -row 5 -column 2 -stick w
      grid $EntryOth    -row 5 -column 3 -stick e

      
      pack $frm



      # -- Deselect ALL entries
      $EntryEvi    configure -state disabled
      $EntryEkate  configure -state disabled
      $EntryEmacs  configure -state disabled
      $EntryXEmacs configure -state disabled
      $EntryEvi    configure -state disabled
      $EntryOth    configure -state disabled

      switch -regexp $Preferences::text_viewer {
           ^gvim {
	            $radEvi select 
                    set Preferences::ChosenEditor     "gvim"
		    if {[info exists Preferences::text_viewer_args] != 0} {
                          $EntryEvi    configure -state normal
	  	          $EntryEvi delete 0 end
	  	          $EntryEvi insert end $Preferences::text_viewer_args
		    }
	          }
	   ^kate {
                    set Preferences::ChosenEditor     "kate"
                    $radEkate select
		    if {[info exists Preferences::text_viewer_args] != 0} {
                          $EntryEkate  configure -state normal
	  	          $EntryEkate delete 0 end
	  	          $EntryEkate insert end $Preferences::text_viewer_args
		    }
	          }
	  ^emacs {
                    set Preferences::ChosenEditor     "emacs"
	            $radEmacs select 
		    if {[info exists Preferences::text_viewer_args] != 0} {
                          $EntryEmacs  configure -state normal
	    	          $EntryEmacs delete 0 end 
	  	          $EntryEmacs insert end $Preferences::text_viewer_args
		    }
	          }
	  ^xemacs {
                    set Preferences::ChosenEditor     "xemacs"
	            $radXEmacs select 
		    if {[info exists Preferences::text_viewer_args] != 0} {
                          $EntryXEmacs configure -state normal
	  	          $EntryXEmacs delete 0 end 
	  	          $EntryXEmacs insert end $Preferences::text_viewer_args
                    }
	           }
         default {
                    set Preferences::ChosenEditor     "other"
	            $radOther select 
		    if {[info exists Preferences::text_viewer_args] != 0} {
                          $EntryOth configure -state normal
	  	          $EntryOth delete 0 end 
			  if {[string compare $Preferences::text_viewer ""] != 0 } {
	  	                  $EntryOth insert end $Preferences::text_viewer
                          }
			  if {[string compare $Preferences::text_viewer_args " "] != 0 } {
	  	                  $EntryOth insert end " " 
	  	                  $EntryOth insert end $Preferences::text_viewer_args
                          }

                    }
	           }
        }
      
      # -- Args of Editor & chosen Editor
      set Preferences::ChosenEditorArgs "$Preferences::text_viewer_args"

      # -- Disable save
      $SaveBT   configure -state disable
      $CancelBT configure -state disabled
}

proc Preferences::ValidKey { SaveW ArgVar action type str } {

          switch $type {
	       "key" {
	                if { $action == 1 } {
				 if {[string compare $str "" ] != 0 &&  [regexp {^[A-Za-z0-9_\- ]+$} $str]} {
			                      $SaveW configure -state normal
	                                      eval set $ArgVar \"$str\"
				 } else {
			                      $SaveW configure -state disabled
					      return 0
				 }
	                         return 1
                        } elseif { $action == 0 } {
	                         eval set $ArgVar \"$str\"
			         $SaveW configure -state normal
	                         return 1
			}
                     }
	  }


	  return 1
}

# -- Note entry need to be modified so not to have args error
proc Preferences::SavePref {compname sbuton cancelb okb utility args} {


              set word [join $args " "]

	      if {[string compare $utility "other"] == 0 } {
	            if {[string compare $word "" ] != 0 } {
                              regsub -all {[ \r\n\t]+} "$word" { } word
                              set kiko  [string trimleft "$word" " "]
                              set lkiko [split $kiko " "]
                              set Preferences::ChosenEditor   [lindex $lkiko 0]
                              set word [join [lrange $lkiko 1 end] " "]
		              set utility $Preferences::ChosenEditor
	                } else {
		              Dialogs::show_msgdlg "You must give the name of an Editor  " ok warning "" $Preferences::PreferenceWindow
		              return 
			}
	      }

	      catch {file delete $::env(TMPDIR)/.maestrorc}

	      # -- Need this for paths
	      #regsub -all {/} $utility {\/} utility

              # -- What if the pref. doe not exist e in config file? existe but empty ie pref= ?
	      # -- Have to add code

	      Preferences::OpenConfigAndSetPrefs $compname $utility $word

	      # -- Update Gui
              Preferences::ParseUserMaestrorc
              

	      # -- disable save button
              $sbuton  configure -state disabled
              $cancelb configure -state disabled
              $okb     configure -state normal
}


proc Preferences::W3BrowsersCreateWidget { frm } {

      variable SaveBW
      variable CancelBW
      variable OkBW
      variable ChosenBrowser
      variable ChosenBrowserArgs
      variable subfw3Browser

      #label $frm.lab -text "Browser Setting" -font "ansi 12 "

      set tw3Browser  [TitleFrame $frm.w3Browser  -text $Dialogs::NotB_Browsers]

      set subfw3Browser  [$tw3Browser getframe]
      
      set CtrlButton [frame $frm.ctrlbuttons -border 2 -relief flat]
      set CancelBW   [button $CtrlButton.cancel  -image $XPManager::img_Cancel -command {destroy $Preferences::PreferenceWindow}]
      set OkBW       [button $CtrlButton.ok      -image $XPManager::img_Ok     -command {destroy $Preferences::PreferenceWindow }]
      set SaveBW     [button $CtrlButton.save    -image $XPManager::img_Save   -command {\
		        Preferences::SavePref "browser" $Preferences::SaveBW $Preferences::CancelBW $Preferences::OkBW \
			$Preferences::ChosenBrowser $Preferences::ChosenBrowserArgs
                        }]

      set args      [label $subfw3Browser.args -text "Arguments" -font 10]

      # -- Browser
      set radffox   [radiobutton $subfw3Browser.radB1 -text "firefox  " -font 12 -variable tata -value firefox \
		     -command {\
                     Preferences::UpdateButtons "browser" "firefox" $Preferences::SaveBW $Preferences::OkBW $Preferences::CancelBW
		     # -- Need to disable all the others
		     Preferences::DisableEditorsEntries $Preferences::subfw3Browser firefox chrome konqueror 
		     }]

      set Entryfox  [Entry $subfw3Browser.firefox  -textvariable kb1 -width 50 -bg $Preferences::EntryBcgkColor -helptext "arguments" \
		     -command {\
		     $Preferences::SaveBW configure -state normal
		     set Preferences::ChosenBrowserArgs "$kb1"
		     }\
                     -validate key\
                     -validatecommand {Preferences::ValidKey $Preferences::SaveBW Preferences::ChosenBrowserArgs %d %V %P}\
		     ]

      set radchrome [radiobutton $subfw3Browser.radB2 -text "chrome   " -font 12 -variable tata -value chrome \
		     -command {\
                     Preferences::UpdateButtons "browser" "chromium-browser" $Preferences::SaveBW $Preferences::OkBW $Preferences::CancelBW
		     # -- Need to disable all the others
		     Preferences::DisableEditorsEntries $Preferences::subfw3Browser chrome firefox konqueror
		     }]

      set Entrychr  [Entry $subfw3Browser.chrome  -textvariable kb2 -width 50 -bg $Preferences::EntryBcgkColor -helptext "arguments" \
		     -command {\
		     $Preferences::SaveBW configure -state normal
		     set Preferences::ChosenBrowserArgs "$kb2"
		     }\
                     -validate key\
                     -validatecommand {Preferences::ValidKey $Preferences::SaveBW Preferences::ChosenBrowserArgs %d %V %P}\
		     ]

      set radKonq   [radiobutton $subfw3Browser.radB3 -text "konqueror" -font 12 -variable tata -value konqueror \
		     -command {\
                     Preferences::UpdateButtons "browser" "konqueror" $Preferences::SaveBW $Preferences::OkBW $Preferences::CancelBW
		     # -- Need to disable all the others
		     Preferences::DisableEditorsEntries $Preferences::subfw3Browser konqueror firefox chrome  
		     }]

      set Entrykon  [Entry $subfw3Browser.konqueror  -textvariable kb3 -width 50 -bg $Preferences::EntryBcgkColor -helptext "arguments" \
		     -command {\
		     $Preferences::SaveBW configure -state normal
		     set Preferences::ChosenBrowserArgs "$kb3"
		     }\
                     -validate key\
                     -validatecommand {Preferences::ValidKey $Preferences::SaveBW Preferences::ChosenBrowserArgs %d %V %P}\
		     ]


      # -- pack Ok/Cancel butt.
      pack $CtrlButton -side bottom
      pack $SaveBW     -side right -padx 4
      pack $OkBW        -side left -padx 4
      pack $CancelBW    -side left -padx 4

      # -- pack browser wid.
      pack $tw3Browser -fill x -pady 2 -padx 2

      grid $args      -row 0 -column 1 -sticky w
      grid $radffox   -row 1 -column 0 -sticky w
      grid $Entryfox  -row 1 -column 1 -sticky e
      grid $radchrome -row 2 -column 0 -sticky w
      grid $Entrychr  -row 2 -column 1 -sticky e
      grid $radKonq   -row 3 -column 0 -sticky w
      grid $Entrykon  -row 3 -column 1 -sticky e

      pack $frm

      # -- Disable save
      $SaveBW  configure -state disable
      $CancelBW configure -state disabled

      # -- First disable all
      $Entryfox configure -state disabled
      $Entrychr configure -state disabled
      $Entrykon configure -state disabled

      if { 1 == 2 } {
      if {[info exists Preferences::browser] != 0 } {
              set www $Preferences::browser
      } else {
	      set ret [Dialogs::show_msgdlg $Dialogs::Dlg_DefaultBrowser  yesno question "" $Preferences::PreferenceWindow]
	      if { $ret == 0 } {
	              # -- Update
		      catch [exec echo "browser = firefox" >> $::env(HOME)/.maestrorc]
		      set Preferences::browser "firefox"
                      set www "firefox"
	      } else {
                      set www "xxx"
	      }
      }
      }


      switch $Preferences::browser  {
         "firefox" {
                    set Preferences::ChosenBrowser "firefox"
	            $radffox select 
		    if {[info exists Preferences::browser_args] != 0} {
		           $Entryfox delete 0 end 
		           $Entryfox insert end $Preferences::browser_args
		    }
                    $Entryfox configure -state normal
	        }
	 "chromium-browser" {
                   set Preferences::ChosenBrowser "chromium-browser"
                   $radchrome select
		   if {[info exists Preferences::browser_args] != 0} {
		        $Entrychr delete 0 end 
		        $Entrychr insert end $Preferences::browser_args
		   }
                   $Entrychr configure -state normal
	        }
         "konqueror" {
                   set Preferences::ChosenBrowser "konqueror"
	           $radKonq select 
		   if {[info exists Preferences::browser_args] != 0} {
		        $Entrykon delete 0 end 
		        $Entrykon insert end $Preferences::browser_args
		   }
                   $Entrykon configure -state normal
	        }
      }
      
      # -- Args of chosen WWW Browser
      set Preferences::ChosenBrowserArgs "$Preferences::browser_args"
}

proc Preferences::KonsolesCreateWidget { frm } {

      variable SaveBK
      variable OkBK
      variable CancelBK
      variable ChosenKonsol
      variable ChosenKonsolArgs
      variable subfconsole

      #label $frm.lab -text "Console Setting" -font "ansi 12 "
      set tconsole [TitleFrame $frm.console -text $Dialogs::NotB_Konsole]

      set subfconsole [$tconsole getframe]
      
      set CtrlButton [frame $frm.ctrlbuttons -border 2 -relief flat]
      set CancelBK   [button $CtrlButton.cancel  -image $XPManager::img_Cancel -command {destroy $Preferences::PreferenceWindow}]
      set OkBK       [button $CtrlButton.ok      -image $XPManager::img_Ok     -command {destroy $Preferences::PreferenceWindow}]
      set SaveBK     [button $CtrlButton.save    -image $XPManager::img_Save   -command {\
		         Preferences::SavePref "default_console" $Preferences::SaveBK $Preferences::CancelBK \
			 $Preferences::OkBK $Preferences::ChosenKonsol $Preferences::ChosenKonsolArgs}]

      set args       [label $subfconsole.args -text "Arguments" -font 10]
      
      # -- Consoles
      set radCkonsol [radiobutton $subfconsole.radC1 -text "Konsole" -font 12 -variable t1 -value konsole \
		     -command  {\
                     Preferences::UpdateButtons "default_console" "konsole" $Preferences::SaveBK $Preferences::OkBK $Preferences::CancelBK
		     # -- Need to disable all the others
		     Preferences::DisableEditorsEntries $Preferences::subfconsole konsole xterm ksystraycmd  
		     }]

      set Entrycon   [Entry $subfconsole.konsole  -textvariable kc1 -width 50 -bg $Preferences::EntryBcgkColor -helptext "argument to konsole" \
		     -command  {\
		     $Preferences::SaveBK configure -state normal
		     set Preferences::ChosenKonsolArgs "$kc1"
		     }\
                     -validate key\
                     -validatecommand {Preferences::ValidKey $Preferences::SaveBK Preferences::ChosenKonsolArgs %d %V %P}\
		     ]

      set radCxterm  [radiobutton $subfconsole.radC2 -text "xterm  " -font 12 -variable t1 -value xterm \
		     -command  {\
                     Preferences::UpdateButtons "default_console" "xterm" $Preferences::SaveBK $Preferences::OkBK $Preferences::CancelBK
		     # -- Need to disable all the others
		     Preferences::DisableEditorsEntries $Preferences::subfconsole xterm konsole ksystraycmd  
		     }]

      set Entryxtr   [Entry $subfconsole.xterm  -textvariable kc2 -width 50 -bg $Preferences::EntryBcgkColor -helptext "arguments to xterm" \
		     -command  {\
		     $Preferences::SaveBK configure -state normal
		     set Preferences::ChosenKonsolArgs "$kc2"
		     }\
                     -validate key\
                     -validatecommand {Preferences::ValidKey $Preferences::SaveBK Preferences::ChosenKonsolArgs %d %V %P}\
		     ]
      
      set radksys    [radiobutton $subfconsole.ksys -text "ksystraycmd" -font 12 -variable t1 -value ksystraycmd \
		     -command  {\
                     Preferences::UpdateButtons "default_console" "ksystraycmd" $Preferences::SaveBK $Preferences::OkBK $Preferences::CancelBK
		     # -- Need to disable all the others
		     Preferences::DisableEditorsEntries $Preferences::subfconsole ksystraycmd xterm konsole  
		      }]

      set Entryksys  [Entry $subfconsole.ksystraycmd -textvariable kc3 -width 50 -bg $Preferences::EntryBcgkColor -helptext "arguments to ksystraycmd" \
		     -command  {\
		     $Preferences::SaveBK configure -state normal
		     set Preferences::ChosenKonsolArgs "$kc3"
		     }\
                     -validate key\
                     -validatecommand {Preferences::ValidKey $Preferences::SaveBK Preferences::ChosenKonsolArgs %d %V %P}\
		     ]

      # -- pack Ok/Cancel butt.
      pack $CtrlButton -side bottom
      pack $SaveBK     -side right -padx 4
      pack $OkBK        -side left -padx 4
      pack $CancelBK    -side left -padx 4

      # -- pack console
      pack $tconsole -fill x -pady 2 -padx 2

      grid $args        -row 0 -column 1 -sticky w

      grid $radCkonsol  -row 1 -column 0 -sticky w
      grid $Entrycon    -row 1 -column 1 -sticky e
      
      grid $radCxterm   -row 2 -column 0 -sticky w
      grid $Entryxtr    -row 2 -column 1 -sticky e
      
      grid $radksys     -row 3 -column 0 -sticky w
      grid $Entryksys   -row 3 -column 1 -sticky e

      pack $frm

      # -- Disable save
      $SaveBK  configure -state disable
      $CancelBK configure -state disabled

      if { 1 == 2 } {
      if {[info exists Preferences::default_console] != 0 } {
              set Kon $Preferences::default_console
      } else {
	      set ret [Dialogs::show_msgdlg $Dialogs::Dlg_DefaultKonsole  yesno question "" $Preferences::PreferenceWindow]
	      if { $ret == 0 } {
	              # -- Update
		      catch [exec echo "default_console = xterm" >> $::env(HOME)/.maestrorc]
		      set Preferences::default_console "xterm"
                      set Kon "xterm"
	      } else {
                      set Kon "fdfdfd"
	      }
      }
      }

      # -- disable all
      $Entrycon  configure -state disabled
      $Entryxtr  configure -state disabled
      $Entryksys configure -state disabled


      switch $Preferences::default_console {
         "konsole" {
                   set Preferences::ChosenKonsol "konsole"
	           $radCkonsol select 
		   if {[info exists Preferences::default_console_args] != 0} {
		        $Entrycon delete 0 end 
		        $Entrycon insert end $Preferences::default_console_args
		   }
		   $Entrycon  configure -state normal
	        }
	 "xterm" {
                   set Preferences::ChosenKonsol "xterm"
                   $radCxterm select
		   if {[info exists Preferences::default_console_args] != 0} {
		       $Entryxtr delete 0 end 
		       $Entryxtr insert end $Preferences::default_console_args
		   }
		   $Entryxtr  configure -state normal
	        }
         "ksystraycmd" {
                   set Preferences::ChosenKonsol "ksystraycmd"
                   $radksys select
		   if {[info exists Preferences::default_console_args] != 0} {
		       $Entryksys delete 0 end 
		       $Entryksys insert end $Preferences::default_console_args
		   }
		   $Entryksys configure -state normal
	        }
      }
      
      # -- Args of chosen console
      set Preferences::ChosenKonsolArgs "$Preferences::default_console_args"

}
proc Preferences::MaestroEventsCreateWidget { frm } {
     
      variable SaveBM
      variable CancelBM
      variable OkBM
      variable tt1
      variable tt2
      variable tt3

      #label $frm.lab -text "Events Setting" -font "12 "
      set tevents  [TitleFrame $frm.events  -text $Dialogs::NotB_Events]

      set subfevents  [$tevents getframe]
      
      set CtrlButton [frame $frm.ctrlbuttons -border 2 -relief flat]
      set CancelBM   [button $CtrlButton.cancel -image $XPManager::img_Cancel -command {destroy $Preferences::PreferenceWindow}]
      set OkBM       [button $CtrlButton.ok     -image $XPManager::img_Ok     -command {destroy $Preferences::PreferenceWindow }]
      set SaveBM     [button $CtrlButton.save   -image $XPManager::img_Save   -command {\
                        if {[string compare $Preferences::show_info_type "$tt1"] != 0 } {
		              Preferences::SavePref "show_info_type"  $Preferences::SaveBM $Preferences::CancelBM $Preferences::OkBM $tt1 
                        }
		        #
                        if {[string compare $Preferences::show_abort_type "$tt2"] != 0 } {
		              Preferences::SavePref "show_abort_type" $Preferences::SaveBM $Preferences::CancelBM $Preferences::OkBM $tt2 
                        }
		        #
                        if {[string compare $Preferences::show_event_type "$tt3"] != 0 } {
		              Preferences::SavePref "show_event_type" $Preferences::SaveBM $Preferences::CancelBM $Preferences::OkBM $tt3 
                        }
		      #
		     }]

      # -- Events
      set chkEvinfo  [checkbutton $subfevents.radEV1 -text "Show events Info" -font 12 -variable tt1 -onvalue true -offvalue false \
		      -command {\
                     if {[string compare $Preferences::show_info_type  "$tt1"] != 0 || \
		         [string compare $Preferences::show_abort_type "$tt2"] != 0 || \
			 [string compare $Preferences::show_event_type "$tt3"] != 0 } {
		                 $Preferences::SaveBM   configure -state normal
		                 $Preferences::OkBM     configure -state disabled
		                 $Preferences::CancelBM configure -state normal
                     } else {
		                 $Preferences::SaveBM   configure -state disabled
		                 $Preferences::OkBM     configure -state normal
		                 $Preferences::CancelBM configure -state disabled
		     }
		      }]

      set chkEvabort [checkbutton $subfevents.radEV2 -text "Show abort events" -font 12 -variable tt2 -onvalue true -offvalue false \
	              -command  {\
                      if {[string compare $Preferences::show_abort_type "$tt2"] != 0 || \
		          [string compare $Preferences::show_info_type  "$tt1"] != 0 || \
			  [string compare $Preferences::show_event_type "$tt3"] != 0 } {
		                 $Preferences::SaveBM   configure -state normal
		                 $Preferences::OkBM     configure -state disabled
		                 $Preferences::CancelBM configure -state normal
                      } else {
		                 $Preferences::SaveBM   configure -state disabled
		                 $Preferences::OkBM     configure -state normal
		                 $Preferences::CancelBM configure -state disabled
                      }
		     }]

      set chkEvent   [checkbutton $subfevents.radEV3 -text "Show events type" -font 12 -variable tt3 -onvalue true -offvalue false \
                      -command  {\
                      if {[string compare $Preferences::show_event_type "$tt3"] != 0 || \
		          [string compare $Preferences::show_abort_type "$tt2"] != 0 || \
			  [string compare $Preferences::show_info_type  "$tt1"] != 0 } {
		                 $Preferences::SaveBM   configure -state normal
		                 $Preferences::OkBM     configure -state disabled
		                 $Preferences::CancelBM configure -state normal
                      } else {
		                 $Preferences::SaveBM   configure -state disabled
		                 $Preferences::OkBM     configure -state normal
		                 $Preferences::CancelBM configure -state disabled
                      }
		      }]


      # -- pack Ok/Cancel butt.
      pack $CtrlButton -side bottom
      pack $SaveBM     -side right -padx 4
      pack $OkBM       -side left -padx 4
      pack $CancelBM    -side left -padx 4

      # -- pack events
      pack $tevents -fill x -pady 2 -padx 2
      pack $chkEvinfo  -anchor w
      pack $chkEvabort -anchor w
      pack $chkEvent   -anchor w
      pack $frm

      # -- Disable save
      $SaveBM   configure -state disable
      $CancelBM configure -state disabled

      # -- Prefer. are defined by default if they dont existe!
      if {[info exists Preferences::show_abort_type] != 0} {
               switch $Preferences::show_abort_type {
                      "true" {
		              $chkEvabort select
			     }
                      "false" {
		              $chkEvabort deselect
			      }
	       }
      } else {
	       $chkEvabort deselect
      }

      # --
      if {[info exists Preferences::show_info_type] != 0} {
               switch $Preferences::show_info_type {
                      "true" {
		              $chkEvinfo select
			     }
                      "false" {
		              $chkEvinfo deselect
			      }
	       }
      } else {
	       $chkEvinfo deselect
      }

      # --
      if {[info exists Preferences::show_event_type] != 0} {
               switch $Preferences::show_event_type {
                      "true" {
		              $chkEvent select
			     }
                      "false" {
		              $chkEvent deselect
			      }
	       }
      } else {
	       $chkEvent deselect
      }
}

proc Preferences::WallPaperIconsCreateWidget { frm } {

      global SEQ_MANAGER_BIN
      variable  _WallPaper
      variable  SaveBI
      variable  CancelBI
      variable  OkBI
      variable  ChosenIcon
      variable  ChosenWallP
      variable  ChosenGeometry
      variable  PathImages
   
      set twall    [TitleFrame $frm.wall -text $Dialogs::NotB_WallIco]
      set subfwall [$twall getframe]
      
      set lwin     [label $subfwall.lbwin -text $Dialogs::Pref_window_size -font 8]
      set lwal     [label $subfwall.lbimg -text $Dialogs::Pref_wallpaper   -font 8]
      set licn     [label $subfwall.lbicn -text $Dialogs::Pref_exp_icon    -font 8]
     
      # -- This is where the default images resides
      set PathImages "${SEQ_MANAGER_BIN}/../etc/bg_templates"

      set CtrlButton [frame $frm.ctrlbuttons -border 2 -relief flat]

      set CancelBI [button $CtrlButton.cancel  -image $XPManager::img_Cancel -command {destroy $Preferences::PreferenceWindow}]
      set OkBI     [button $CtrlButton.ok      -image $XPManager::img_Ok     -command {destroy $Preferences::PreferenceWindow}]
      set SaveBI   [button $CtrlButton.save    -image $XPManager::img_Save   -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 } { 
		              Preferences::SavePref "exp_icon"  $Preferences::SaveBI $Preferences::CancelBI $Preferences::OkBI $Preferences::ChosenIcon
                     }
                     #
		     if {[string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0 } {
		              if {[regexp {\/} $Preferences::ChosenWallP]} {
		                    Preferences::SavePref "background_image"  $Preferences::SaveBI $Preferences::CancelBI \
				    $Preferences::OkBI $Preferences::ChosenWallP
                              } else {
		                    Preferences::SavePref "background_image"  $Preferences::SaveBI $Preferences::CancelBI \
				    $Preferences::OkBI $Preferences::PathImages/$Preferences::ChosenWallP
			      }
                     }
		     #
                     if {[string compare $Preferences::flow_geometry "$kw1"] != 0 } {
		              Preferences::SavePref "flow_geometry"  $Preferences::SaveBI $Preferences::CancelBI \
			      $Preferences::OkBI $Preferences::ChosenGeometry
		     }
                   }]

      # -- Pref. are normally set at begining
      if {[info exists Preferences::background_image] != 0} {
                # -- Check if cmoi images
	        set bfile [file tail $Preferences::background_image]

		if {[lsearch -exact $Preferences::ListWallPapers $bfile] == -1 } {
                         set  Preferences::_WallPaper $Preferences::background_image
                } else {
                         set  Preferences::_WallPaper $bfile 
		}
      } else {
                set  Preferences::_WallPaper ""
      }

      set Entrywin  [Entry $subfwall.win   -textvariable kw1 \
                     -width 10 -bg $Preferences::EntryBcgkColor -helptext "window size"\
		     -command  {\
                        if {[string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			    [string compare $Preferences::exp_icon "$icon"] != 0 ||\
			    [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI   configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenGeometry "$kw1"
                        } else {
                                  $Preferences::SaveBI   configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
			}
		       }\
                     -validate key\
                     -validatecommand {Preferences::ValidKey $Preferences::SaveBI Preferences::ChosenGeometry %d %V %P}\
		       ]

      set frmIcons  [frame $subfwall.icons -border 2 -relief ridge]
      set rxp       [radiobutton $frmIcons.rxp -image $XPManager::img_ExpIcon      -variable icon -value "xp"    -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
		         [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI   configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI   configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn1       [radiobutton $frmIcons.rn1 -image $XPManager::img_ExpNoteIcon  -variable icon -value "note1" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI   configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI   configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn2       [radiobutton $frmIcons.rn2 -image $XPManager::img_ExpSunny -variable icon -value "sunny" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI   configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI   configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn3       [radiobutton $frmIcons.rn3 -image $XPManager::img_ExpThunder -variable icon -value "thunder" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI   configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI   configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn4       [radiobutton $frmIcons.rn4 -image $XPManager::img_ExpThunderstorms -variable icon -value "rain" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI   configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI   configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]
      

      set ListWall  [ComboBox $subfwall.wall  -textvariable Preferences::_WallPaper \
                     -width 45 -helptext "Available WallPapers"\
		     -editable false \
		     -autocomplete false \
		     -entrybg  $Preferences::EntryBcgkColor \
		     -values   $Preferences::ListWallPapers \
		     -bwlistbox false \
		     -selectbackground #FFFFFF \
		     -selectforeground black \
		     -justify left \
		     -insertborderwidth 0\
		     -modifycmd {\
				if {[string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0 ||\
				    [string compare $Preferences::exp_icon "$icon"] != 0 || \
				    [string compare $Preferences::flow_geometry "$kw1"] != 0  } {
		                             $Preferences::SaveBI   configure -state normal
                                             $Preferences::OkBI     configure -state disabled
                                             $Preferences::CancelBI configure -state normal
				             set Preferences::ChosenWallP $Preferences::_WallPaper 
                                } else {
                                             $Preferences::SaveBI   configure -state disabled
                                             $Preferences::CancelBI configure -state disabled
                                             $Preferences::OkBI     configure -state normal
				} }]


      set Browse_gif [button $subfwall.bgif -text "Browse" -command {\
                      set types {
		                 {"Image Files"   {.gif}  }
		      } 
		     
		      set bkg_gif [tk_getOpenFile  -initialdir $::env(HOME) -filetypes $types -parent $Preferences::PreferenceWindow]
		      # -- Do check the min size of the gif

		      # -- strip path if Depot images
		      if {[regexp {bg_templates} $bkg_gif]} {
		                 set bkg_gif [file tail $bkg_gif]
		      }
                      
		      set Preferences::_WallPaper $bkg_gif

		      if {[string compare [file tail $Preferences::background_image] $bkg_gif] != 0 ||\
		          [string compare $Preferences::exp_icon "$icon"] != 0 || \
			  [string compare $Preferences::flow_geometry "$kw1"] != 0} {
		                  $Preferences::SaveBI   configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				 set Preferences::ChosenWallP $Preferences::_WallPaper 
                      } else {
                                 $Preferences::SaveBI   configure -state disabled
                                 $Preferences::CancelBI configure -state disabled
                                 $Preferences::OkBI     configure -state normal
		      }
	   }]


      # -- pack Ok/Cancel butt.
      pack $CtrlButton  -side bottom
      pack $SaveBI      -side right -padx 4
      pack $OkBI        -side left  -padx 4
      pack $CancelBI    -side left  -padx 4


      # -- pack 
      pack $twall -fill x -pady 2 -padx 2
     

      grid $lwin      -row 0 -column 0 -sticky w
      grid $Entrywin  -row 0 -column 1 -sticky w -pady 4

      grid $licn      -row 1 -column 0 -sticky w
      grid $frmIcons  -row 1 -column 1 -sticky w -pady 4
      
      pack $rxp -side left -padx 4
      pack $rn1 -side left -padx 4
      pack $rn2 -side left -padx 4
      pack $rn3 -side left -padx 4
      pack $rn4 -side left -padx 4

      grid $lwal        -row 2 -column 0 -sticky w
      grid $ListWall    -row 2 -column 1 -sticky w 
      grid $Browse_gif  -row 2 -column 2 -sticky w -pady 4


      pack $frm


      # -- Preferences are normally set by def. at begining
      if {[info exists Preferences::flow_geometry] != 0 } {
              $Entrywin delete 0  end
              $Entrywin insert end $Preferences::flow_geometry
      }
      
      if {[info exists Preferences::exp_icon] != 0} {
            switch $Preferences::exp_icon {
	      "xp"    {
	                 $rxp select
	              }
              "note1" {
	                 $rn1 select
	              }
	      "sunny" {
	                 $rn2 select
		      }
	      "rain" {
	                 $rn4 select
		      }
	      "thunder" {
	                 $rn3 select
		      }
	    }
      } else {
	    $rxp deselect
	    $rn1 deselect
	    $rn2 deselect
	    $rn3 deselect
	    $rn4 deselect
      }

      # -- Disable save cancel
      $SaveBI   configure -state disabled
      $CancelBI configure -state disabled

}

proc Preferences::UpdateButtons { widget utility bsave bok bcancel} {

       eval set wid \$Preferences::$widget

       if {[string compare $wid $utility] != 0 } {
               $bok     configure -state disabled
               $bcancel configure -state normal
               $bsave   configure -state normal
       } else {
               $bok     configure -state normal
               $bcancel configure -state disabled
               $bsave   configure -state disabled
       }

       switch $widget {
            "text_viewer" {
                            set Preferences::ChosenEditor "$utility"
                            set Preferences::ChosenEditorArgs ""
			  }
            "browser"     {
                            set Preferences::ChosenBrowser "$utility"
                            set Preferences::ChosenBrowserArgs ""
			  }
            "default_console" {
                            set Preferences::ChosenKonsol "$utility"
                            set Preferences::ChosenKonsolArgs ""
			  }
       }

}


proc Preferences::DisableEditorsEntries { frame EntryToEnable args } {

       set largs [split $args " "]

       foreach arg $largs {
             $frame.$arg configure -state disabled
       }

       # - Enable Entry 
       if {[string compare $EntryToEnable "def"] != 0} {
            $frame.$EntryToEnable configure -state normal 
       } 
}


# -- add code to test if any exp existe in  this path
# -- path must not contain /  or ////, /././. , ... etc  --> check
# -- We dont want to recurs to much here 
proc Preferences::FindAndValidateExpDir { path nbk } {
          # -- remove blanks
	  XPManager::update_progdlg $Preferences::ConfigDepotWin "" "Finding Experiences ... "
	  regsub -all {[ ][\t]*} $path {} path 
	  if {[string compare $path ""] != 0} {

	      # -- try to find Exp's
	      set listE [split [exec find $path/ -maxdepth 5 -type l -name EntryModule] "\n"]
              set len [llength $listE]
              if { $len == 0 } {  
	             return 1
              }

	      # -- Check to see if this path is already in the ExpUsrRepositiry list ie:case where refrence link 
	      # -- are not the same but the lead to same directory

              # -- get depot for notebook
	      set listxp [Preferences::GetTabListDepots $nbk "r"]

	      if {[string compare $listxp ""] != 0} {
	             set to_add [string trimright [file join [file normalize $path] { }]]
	             file stat $to_add statinfo
                     set dev_toadd $statinfo(dev)
                     set ino_toadd $statinfo(ino)
                     set match 0
	             foreach upth $listxp { 
	                      if { $upth == "no-selection" || "$upth" == "" } {
		                  continue
                              }
	                      file stat "[string trimright [file join [file normalize $upth] { }]]" statinfo
		              if { $statinfo(ino) == $ino_toadd } {
		                        set match 1
                              }
	             }

	             if { $match != 0 } {
	                      return 2
	             }
	      } else {
	             return 0
	      }
	  } else {
	      return 3
	  }
	  
	  return 0
}


proc xBtn {w {args {}} } {
      catch {destroy $w}
      catch {destroy ${w}_lbl}
      eval button $w  $args
      pack propagate $w 0
      pack [label ${w}_lbl -text [$w cget -text] ] -side right -in $w
      foreach item [bind Button] {
        bind ${w}_lbl $item [string map "%W $w" [bind Button $item]]
      }
     return $w
}
# pack [xBtn .myB -image image1 -text "Test button" -height 40 -width 80]

proc Preferences::Config_table {} {

     # Create the font TkDefaultFont if not yet present
     catch {font create TkDefaultFont -family Helvetica -size -12}
	      
     option add *Font                    TkDefaultFont
     option add *selectBackground        #678db2
     option add *selectForeground        white

     option add *Tablelist.background        white
     option add *Tablelist.stripeBackground  #e4e8ec
     option add *Tablelist.setGrid           yes
     option add *Tablelist.movableColumns    yes
     option add *Tablelist.labelCommand      tablelist::sortByColumn
     option add *Tablelist.labelCommand2     tablelist::addToSortColumns

}

proc Preferences::ParseUserMaestrorc { } {
 
   global MUSER
   global array ArrayTabsDepot

   set Preferences::ERROR_NOT_RECOGNIZED_PREF  0

   if [catch {exec cp $::env(HOME)/.maestrorc  $::env(TMPDIR)/maestrorc.tmp} message] {
                 puts "PROBLEME COPYING CONFIG FILE:.MAESTRORC TO TMPDIR: $message"
   }

   set fid    [open "$::env(TMPDIR)/maestrorc.tmp" r]
   set dfile  [read $fid]
   close $fid

   set data   [split $dfile "\n"]

   # -- Get the navtabs names
   foreach line $data {
            regexp "\^\[ \\t\]\*navtabs\[ \\t=\]\(\.\*\)" $line  matched tabs
   }
   

   # -- If tabs ok ,Update values 
   switch $MUSER {
                ^afsi(ops|sio) {
                                    set Preferences::ListUsrTabs [list "$Dialogs::XpB_OpExp" "$Dialogs::XpB_PoExp"]
	                       }
                ^afsipar       {
                                    set Preferences::ListUsrTabs [list "$Dialogs::XpB_PaExp"]
	                       }
                default        { 
                                   if {[info exists tabs] != 0} {
                                              set Preferences::ListUsrTabs [split $tabs ":"]
                                   } else {
                                              set Preferences::ListUsrTabs {"My_experiments"}
					      # --Put in .maestrorc file
					      catch { [exec echo "# User can configure his tabs" >> $::env(HOME)/.maestrorc] }
					      catch { [exec echo "navtabs=My_experiments" >> $::env(HOME)/.maestrorc] }
                                   }
                               }
   }

   # -- Operational tabs will alws be put by default
   foreach line $data {
        
	  # remove = 
	  regsub -all {=} $line { } line
	  # only one blank
          regsub -all " +" $line " " line 

	  set lname    [split [string trim $line " "] " "]
          set PerfName [string trim [lindex $lname 0] " "]
	  set UtilName [lindex $lname 1]
          set lerest   [join [lrange $lname 2 end] " "]

          switch -regexp $line {
	            "^\[ \t]*$"                     { }
	            "^\[ \t]\*#\+"                  { }
                    "^\[ \\t\]\*UsrExpRepository "  { }
		    "^\[ \\t\]\*auto_msg_display "  { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*auto_launch "       { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*show_abort_type "   { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*show_event_type "   { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*show_info_type "    { Preferences::setPrefValues $PerfName $UtilName $lerest }
                    "^\[ \\t\]\*node_display_pref " { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*default_console "   { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*text_viewer "       { Preferences::setPrefValues $PerfName $UtilName $lerest }
                    "^\[ \\t\]\*browser "           { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*flow_geometry "     { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*background_image "  { Preferences::setPrefValues $PerfName $UtilName $lerest }
                    "^\[ \\t\]\*exp_icon "          { Preferences::setPrefValues $PerfName $UtilName $lerest }
                    "^\[ \\t\]\*use_bell "          { Preferences::setPrefValues $PerfName $UtilName $lerest }
                    "^\[ \\t\]\*xflow_scale "       { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*user_tmp_dir "      { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*mc_show_console "   { Preferences::setPrefValues $PerfName $UtilName $lerest }
                    "^\[ \\t\]\*suites_file "       { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*vcs_app_name "      { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*vcs_path "          { Preferences::setPrefValues $PerfName $UtilName $lerest }
		    "^\[ \\t\]\*navtabs "           { }
                   default {
		               set err 1
		               foreach ltb $Preferences::ListUsrTabs {
				    set ltb [string trim  $ltb " "]
                                    if {[regexp "\^\[ \]*$ltb " $line]} {
                                           regexp "\^\[ \\t\]\*$ltb\(\.\*\)" $line  match tabdepot
				           set ArrayTabsDepot($ltb) [string trim $tabdepot " "]
					   set err 0
				    }
			       }
			       if { $err == 1 } {
		                         set Preferences::ERROR_NOT_RECOGNIZED_PREF  1
			                 #puts "You Have a non Recognize token ... $line "
			       }
			   }
	   }
   }
}

proc Preferences::setPrefValues { PName name args } {
          
          global SEQ_MANAGER_BIN
	
          set word [join $args " "]
	  switch $PName {
                 "UsrExpRepository"  { }
		 "auto_msg_display"  { set  Preferences::auto_msg_display  $name }
		 "auto_launch"       { set  Preferences::auto_launch       $name }
		 "show_abort_type"   { set  Preferences::show_abort_type   $name }
		 "show_event_type"   { set  Preferences::show_event_type   $name }
		 "show_info_type"    { set  Preferences::show_info_type    $name }
		 "node_display_pref" { set  Preferences::node_display_pref $name }
		 "default_console"   {
                                       set  Preferences::default_console   $name 
                                       set  Preferences::default_console_args "$word"
		                     }
		 "text_viewer"       {
                                       set  Preferences::text_viewer $name 
                                       set  Preferences::text_viewer_args "$word"
		                     }
		 "browser"           {
                                       set  Preferences::browser $name
                                       set  Preferences::browser_args "$word"
		                     }
		 "flow_geometry"     { set  Preferences::flow_geometry $name }
		 "background_image"  { 
                                       regsub -all {[ \r\n\t]+} $name {} name
                                       set  Preferences::background_image $name 
		                     }
		 "exp_icon"          { 
                                       switch $name {
                                         "xp"    {
                                                set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.gif] 
                                 		set  Preferences::exp_icon "xp"
                                                 }
                                         "note1" {
                                                 set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.note.gif] 
                                 		 set  Preferences::exp_icon "note1"
                                                 }
                                         "rain"  {
                                                set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/Thunderstorms.gif]
                                		set  Preferences::exp_icon "rain"
                                                 }
                                        "thunder" {
                                                 set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/Thunder.gif]
                                		 set  Preferences::exp_icon "thunder"
                                                }
                                        "sunny" {
                                                set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/Sunny.gif]
                                		set  Preferences::exp_icon "sunny"
                                                }
                                        default {
                                                set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.gif] 
                                		set  Preferences::exp_icon "xp"
						puts ">>>>>Preferences::exp_icon_img in default name=$name"
                                                }
                                      }
			            }
		 "user_tmp_dir"     { set  Preferences::user_tmp_dir $name }
		 "use_bell"         { set  Preferences::use_bell     $name }
		 "xflow_scale"      { set  Preferences::xflow_scale  $name }
		 "mc_show_console"  { }
		 "suites_file"      { }
		 "vcs_app_name"     { }
		 "vcs_path"         { }
                 default            { 
		                       set Preferences::ERROR_NOT_RECOGNIZED_PREF 1
		                       puts "DEFAULT:$PName name=$name args=$word" 
				    }
	  }
}

#--------------------------------------------
#  GetTabListDepots
# in  :  list of user tabs
# out :  list of tabs return all depot
#--------------------------------------------
proc Preferences::GetTabListDepots { nbk type} {
      global array ArrayTabsDepot

      set ldepot {}
      if {[string compare $nbk "none"] == 0 } {
            foreach ltb $Preferences::ListUsrTabs {
	           if {[info exists ArrayTabsDepot([string trim $ltb " "])] != 0 } {
                        set tab $ArrayTabsDepot([string trim $ltb " "])
                        set ltmp [split $tab ":"]
	                lappend ldepot {*}$ltmp
		   } else {
	                set ldepot ""
		   }
            }
      } else {
            # -- got notebook
	    if {[info exists ArrayTabsDepot([string trim $nbk " "])] != 0 } {
                      set tab $ArrayTabsDepot([string trim $nbk " "])
                      set ldepot [split $tab ":"]
            } else {
	              set ldepot ""
	    }
      }
  
      # -- Check if depot is writable by user
      set return_this_list {}
      switch $type {
           "w" {
                 if {[string compare $ldepot ""] != 0 } {
                    foreach ldp $ldepot {
                      if {[file writable $ldp]} {
                           lappend  return_this_list $ldp
                      }
                    }
                 } else {
	            set return_this_list ""
                 }
	       }
           "r" {
	          lappend return_this_list {*}$ldepot
	       }
      }

      return $return_this_list

}


proc Preferences::set_liste_Wall_Papers {} {
     global SEQ_MANAGER_BIN

     # does user have access to images ?
     if {[catch {file stat ${SEQ_MANAGER_BIN}/../etc/bg_templates entry} err]} {
            puts "Couldn't stat ${SEQ_MANAGER_BIN}/../etc/bg_templates "
     } else {
            foreach wfile [glob -nocomplain -type { f r} -path ${SEQ_MANAGER_BIN}/../etc/bg_templates/ *.gif] {
		lappend Preferences::ListWallPapers [file tail $wfile]
            }
     }
}

proc Preferences::set_prefs_default {} {

              global SEQ_MANAGER_BIN

              set listPref {}

	      if {[info exists Preferences::auto_msg_display] == 0} {
	              lappend listPref "auto_msg_display=true"
	      }
	      if {[info exists Preferences::auto_launch] == 0} {
	              lappend listPref "auto_launch=true"
	      }
	      if {[info exists Preferences::show_abort_type] == 0} {
	              lappend listPref "show_abort_type=true"
	      }
	      if {[info exists Preferences::show_event_type] == 0} {
	              lappend listPref "show_event_type=true"
	      }
	      if {[info exists Preferences::show_info_type] == 0} {
	              lappend listPref "show_info_type=true"
	      }
	      if {[info exists Preferences::node_display_pref] == 0} {
	              lappend listPref "node_display_pref=normal"
	      }
	      if {[info exists Preferences::default_console] == 0} {
	              lappend listPref "default_console=konsole -e"
		      set Preferences::default_console_args "-e"
	      }
	      if {[info exists Preferences::text_viewer] == 0} {
	              lappend listPref "text_viewer=gvim"
		      set Preferences::text_viewer_args ""
	      }
	      if {[info exists Preferences::browser] == 0} {
	              lappend listPref "browser=firefox"
		      set Preferences::browser_args ""
	      }
	      if {[info exists Preferences::flow_geometry] == 0} {
	              lappend listPref "flow_geometry=800x600"
	      }
	      if {[info exists Preferences::background_image] == 0} {
	              lappend listPref "background_image=$SEQ_MANAGER_BIN/../etc/bg_templates/artist_canvas_darkblue.gif"
	      }
	      if {[info exists Preferences::exp_icon] == 0} {
	              set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.gif]
		      set  Preferences::exp_icon "xp"
		      set  Preferences::ChosenIcon $Preferences::exp_icon
	              lappend listPref "exp_icon=xp"
	      }
	      if {[info exists Preferences::user_tmp_dir] == 0} {
	              lappend listPref "user_tmp_dir=default"
	      }
	      if {[info exists Preferences::use_bell] == 0} {
	              lappend listPref "use_bell=true"
	      }
	      if {[info exists Preferences::xflow_scale] == 0} {
	              lappend listPref "xflow_scale=1"
	      }

	      # -- Remove any previous file
	      catch {[exec rm -f $::env(TMPDIR)/prefs.default]} 

	      if {[llength $listPref] != 0 } {
                  foreach item $listPref {
		       puts "Setting default for $item"
                       set lit   [split $item "="]
		       set util  [lindex $lit 0] 
		       set name_args [lindex $lit 1]
		       set lnargs [split $name_args " "]
		       set Preferences::$util [lindex $lnargs 0]

		       catch {[exec echo "$item" >> $::env(TMPDIR)/prefs.default]} 
		  }
		  if {[file exist $::env(TMPDIR)/prefs.default]} {
                              catch {[exec cat $::env(TMPDIR)/prefs.default >> $::env(HOME)/.maestrorc]}
		  }
	      }
}


proc Preferences::OpenConfigAndSetPrefs {token value args} {

          catch {[exec rm -f $::env(TMPDIR)/.maestrorc*]}

          # -- concat args
          set word [join $args " "]

          # -- work in TMPDIR
	 
          set fid [open "$::env(HOME)/.maestrorc" r]
          set file_pref [read $fid]
	  close $fid
          
	  set first_time 0
	  #  Process data file
	  set data [split $file_pref "\n"]
          set fid  [open "$::env(TMPDIR)/.maestrorc.tmp" w]

	  foreach line $data {
	         if {[regexp  "\^\[ \\t\]\*$token" $line]} {
		     if { $first_time == 0 } {
		        eval regsub -all \{\=\.*\} \$line \{\=$value $word\} line
			puts $fid [string trim $line " "] 
	               set first_time 1
                     }
		 } else {
			puts $fid $line
                 } 
	  }
	  close $fid

	  # -- Replace file
	  catch [exec mv $::env(TMPDIR)/.maestrorc.tmp   $::env(HOME)/.maestrorc]
	  if  {[file exist $::env(TMPDIR)/.maestrorc]} {
	              Dialogs::show_msgdlg "Error Copying .maestrorc file ok warning " ok warning "" $Preferences::PreferenceWindow
		      return 
          }

}


