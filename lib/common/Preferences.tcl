global array TreesWidgets

namespace eval Preferences {

           variable  PreferenceWindow

           variable ERROR_PARSING_USER_CONFIG 0

	   # -- Preference variables
	   variable UsrExpRepository
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
	   variable user_tmp_dir
	   variable ChosenIcon
	   variable ListWallPapers

	   variable EntryBcgkColor "#FFFFFF"


}

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

      $nbook  insert 0 UserExpDepot    -text $Dialogs::NotB_ExpDepot 
      $nbook  insert 1 TextEditor      -text $Dialogs::NotB_TextEdit 
      $nbook  insert 2 W3Browsers      -text $Dialogs::NotB_Browsers 
      $nbook  insert 3 Konsoles        -text $Dialogs::NotB_Konsole
      $nbook  insert 4 MaestroEvents   -text $Dialogs::NotB_Events
      $nbook  insert 5 WallPaperIcons  -text $Dialogs::NotB_WallIco

      foreach panel {UserExpDepot TextEditor W3Browsers Konsoles MaestroEvents WallPaperIcons} {
              set pane [$nbook getframe $panel]
              ${panel}CreateWidget $pane 
	      #$nbook itemconfigure $panel -createcmd  "Preferences::${panel}Create $pane $PrefWin" 
              $nbook raise $panel 
      }


      $nbook compute_size
      $nbook raise UserExpDepot 

      pack $frm  -fill x
      pack $frm.lab -fill x
      pack $nbook -fill both -expand yes -padx 4 -pady 4
}

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

proc Preferences::UserExpDepotCreateWidget { frm } {

      variable listPath
      variable SaveBU
      variable CancelBU
      variable OkBU
      variable ExpPathsRemove
      variable SelectionToRemove

      #label $frm.lab -text "Experiments Depot Setting" -font "ansi 12 "
      set t2 [TitleFrame $frm.titf2 -text $Dialogs::NotB_ExpDepot]
      
      set subfP [$t2 getframe]

      # -- Whre to put add/remove butt.
      set AddRemButton [frame $frm.addrembuttons -border 2 -relief flat]

      set ExpPathsBadd [Button $AddRemButton.butadd  -image $XPManager::img_Add -command { Preferences::AddExpToPref }]
                                 

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
      if {[info exists Preferences::UsrExpRepository] != 0 } {
           foreach upath $Preferences::UsrExpRepository { 
               if { [string compare $upath "no-selection"] != 0 } {
                        $listPath insert end "$upath" -text "$upath" 
               }
           }
      }


      set CtrlButton [frame $frm.ctrlbuttons -border 2 -relief flat]
      set OkBU     [button $CtrlButton.ok     -image $XPManager::img_Ok     -command {destroy $Preferences::PreferenceWindow}]
      set CancelBU [button $CtrlButton.cancel -image $XPManager::img_Cancel -command {destroy $Preferences::PreferenceWindow}]
      set SaveBU   [button $CtrlButton.save   -image $XPManager::img_Save   -command {Preferences::SavePrefToConfig}]

     
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

      pack $frm

      # -- first disable until changes in User Xp. list ie: UsrExpRepository
      $SaveBU         configure -state disabled
      $CancelBU       configure -state disabled
      $ExpPathsRemove configure -state disabled
}

proc Preferences::AddExpToPref { } {

    set ExpDir [tk_chooseDirectory -initialdir $::env(HOME)/ -title \
    "Choose Experiment directory" -parent $Preferences::PreferenceWindow]

    if { "$ExpDir" != "" } {
                 set numslash [regsub -all {\/} $ExpDir "" kiki]
                 if {[string compare $ExpDir [file normalize $::env(HOME)]] == 0 || [string compare $ExpDir "/" ] == 0 || $numslash <=4 } {
                             Dialogs::show_msgdlg $Dialogs::Dlg_PathDeep  ok error "" $Preferences::PreferenceWindow
	                     return
	            }

                    XPManager::show_progdlg $Preferences::PreferenceWindow "Finding Experiments in progress "
                    set ret [Preferences::FindAndValidateExpDir $ExpDir]
                    destroy $Preferences::PreferenceWindow.progress 

	            switch $ret {
	                          0 {
                                         # -- Ok add it to list ,but before check if altready there
                                         set itms [$Preferences::listPath items]
	                                 set litems [split $itms " "]
                                         # -- need grep maybe 
	                                 set _error 0
                                         foreach it $litems {
	                                        if { $it == $ExpDir } {
                                                       Dialogs::show_msgdlg $Dialogs::Dlg_ExpPathInList  ok error "" $Preferences::PreferenceWindow
			                               set _error 1
                                                   } 
                                         }

	                                 if { $_error == 0 } {
                                                   regsub -all {[ ][\t]*} $ExpDir {} ExpDir; 
                                                   $Preferences::listPath insert end "$ExpDir" -text "$ExpDir" 
                                                   # -- Ok Update Global Depot
					           #set Preferences::UsrExpRepository [split [$Preferences::listPath items] " "]
					 }
					 # -- Ok, We can save somthing!  NOT NOW
					 #$Preferences::SaveBU configure -state normal
				    }
                                  1 {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_NoExpPath  ok error "" $Preferences::PreferenceWindow
					 return
		                    }
                                  2 {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_ExpPathInList  ok error "" $Preferences::PreferenceWindow
					 return
		                    }
                                  3 {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_NoValExp  ok error "" $Preferences::PreferenceWindow
					 return
		                    }
				  }
	            # -- Empty Entry
		    set ExpDir ""
  
                    $Preferences::SaveBU         configure -state normal
                    $Preferences::CancelBU       configure -state normal
                    $Preferences::OkBU           configure -state disabled
   }
}

proc Preferences::SavePrefToConfig { } {

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
  if {[info exists Preferences::UsrExpRepository] != 0 } {
         # -- Slash is special char. protect it  
         regsub -all {/} $lPath {\/} lPath
	 catch {file delete $::env(TMPDIR)/.maestrorc}

	 if {[string compare $lPath ""] != 0} {
                  catch {[exec cat $::env(HOME)/.maestrorc  | sed "s/^UsrExpRepository\.*=\.\*/UsrExpRepository=$lPath/g" >  $::env(TMPDIR)/.maestrorc]}  
         } else {
                  catch {[exec cat $::env(HOME)/.maestrorc  | grep -v "^UsrExpRepository" >  $::env(TMPDIR)/.maestrorc]}  
	 }

         if {[file exist  $::env(TMPDIR)/.maestrorc]} {
                   # -- ok cp to HOME
                   catch {set retv [exec cp $::env(TMPDIR)/.maestrorc $::env(HOME)/.maestrorc]} 
         } else {
                   Dialogs::show_msgdlg "Error copying config file"  ok warning "" $Preferences::PreferenceWindow
		   return
	 }
	 set retv 0
  } else {
         if [catch {exec echo "UsrExpRepository=$lPath" >> $::env(HOME)/.maestrorc}] {
                   Dialogs::show_msgdlg "Error copying config file"  ok warning "" $Preferences::PreferenceWindow
		   return
         }
  }

  # -- Ok Update Global Depot
  set Preferences::UsrExpRepository [split [$Preferences::listPath items] " "]
  set ret [Dialogs::show_msgdlg $Dialogs::Dlg_UpdateExpBrowser  yesno question "" $Preferences::PreferenceWindow]
  if { $ret == 0 } {
	       # -- Ok Update XpBrowser NOTE: For Now Always User Tree
	       set crap_tcl [$Preferences::listPath items] 
	       XTree::reinit $::TreesWidgets($Dialogs::XpB_MyExp) {*}$crap_tcl
  }

  # should disable remobe ,save,cancel button here
  $Preferences::ExpPathsRemove configure -state disabled
  $Preferences::SaveBU         configure -state disabled
  $Preferences::CancelBU       configure -state disabled
  $Preferences::OkBU           configure -state normal

  # -- if no Exp at all Undef Preferences::UsrExpRepository
  # -- How many tem
  set nitem [$Preferences::listPath items]
  if {[string compare $nitem ""] == 0} {
           unset Preferences::UsrExpRepository
  }
   
}

proc Preferences::TextEditorCreateWidget { frm } {

      variable SaveBT
      variable CancelBT
      variable OkBT
      variable ChosenEditor
      variable ChosenEditorArgs
      variable subfeditor

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
      set txtvi       [label $subfeditor.vitxt -text "gvim " -font 10]
      set radEvi      [radiobutton $subfeditor.radE1  -variable t -value "gvim" -command  {\
                        Preferences::UpdateButtons "text_viewer" "gvim" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			set Preferences::ChosenEditor "gvim"
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor vi emacs xemacs kate oth
			}]

      
      set txtemacs    [label $subfeditor.emacstxt -text "emacs " -font 10]
      set radEmacs    [radiobutton $subfeditor.radE2  -variable t -value "emacs" -command  {\
                        Preferences::UpdateButtons "text_viewer" "emacs" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			set Preferences::ChosenEditor "emacs"
		        # -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor emacs xemacs kate vi oth
			}]

      
      set txtxemacs   [label $subfeditor.xemacstxt -text "xemacs " -font 10]
      set radXEmacs   [radiobutton $subfeditor.xradE3 -variable t -value "xemacs" -command  {\
                        Preferences::UpdateButtons "text_viewer" "xemacs" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			set Preferences::ChosenEditor "xemacs"
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor xemacs emacs kate vi oth
			}]

      
      set txtkate     [label $subfeditor.katetxt -text "kate " -font 10]
      set radEkate    [radiobutton $subfeditor.radE4  -variable t -value "kate" -command  {\
                        Preferences::UpdateButtons "text_viewer" "kate" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			set Preferences::ChosenEditor "kate"
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor kate emacs xemacs  vi oth

			}]

      set txtother    [label $subfeditor.other -text "Other " -font 10]
      set radOther    [radiobutton $subfeditor.roth    -variable t -value "oth" -command  {\
                        Preferences::UpdateButtons "text_viewer" "other" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			if {[string compare $Preferences::ChosenEditorArgs ""] != 0 } {
			            #regsub -all {[ \r\n\t]+} $Preferences::ChosenEditorArgs {} Preferences::ChosenEditorArgs
				    #set kiko [string trimleft $Preferences::ChosenEditorArgs " "]
				    #set lkiko [split $kiko " "]
			            #set Preferences::ChosenEditor   [lindex $lkiko 0]
				    #set Preferences::ChosenEditorArgs [join [lrange $lkiko 1 end] " "]
				    #puts "edit=$Preferences::ChosenEditor  args=$Preferences::ChosenEditorArgs"
			} else {
			}
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor oth vi emacs xemacs kate
			}]



      set txtdefault    [label $subfeditor.default -text "Default" -font 10]
      set radDefault    [radiobutton $subfeditor.rdef    -variable t -value "def" -command  {\
                        Preferences::UpdateButtons "text_viewer" "def" $Preferences::SaveBT $Preferences::OkBT $Preferences::CancelBT
			set Preferences::ChosenEditor "def"
			# -- Need to disable all the others
			Preferences::DisableEditorsEntries $Preferences::subfeditor def oth vi emacs xemacs kate
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
                        -validatecommand {Preferences::UserEditor $Preferences::SaveBT Preferences::ChosenEditorArgs %d %V %P}]

if { 1 == 2 } { 
if {[string compare "$Preferences::ChosenEditorArgs" ""] != 0 } {
   regsub -all {[ \r\n\t]+} "$Preferences::ChosenEditorArgs" {} Preferences::ChosenEditorArgs
   set kiko [string trimleft "$Preferences::ChosenEditorArgs" " "]
   set lkiko [split $kiko " "]
   set Preferences::ChosenEditor   [lindex $lkiko 0]
   set Preferences::ChosenEditorArgs [join [lrange $lkiko 1 end] " "]
}
}
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

      grid $radDefault  -row 6 -column 1 -stick e
      grid $txtdefault  -row 6 -column 2 -stick w
      
      pack $frm

      # -- Disable save
      $SaveBT   configure -state disable
      $CancelBT configure -state disabled

      #if {[info exists Preferences::text_viewer] != 0 } {
      #        set txtview $Preferences::text_viewer
      #} else {
      #        set txtview "def"
      #}

      # -- Deselect ALL entries
      $EntryEvi    configure -state disabled
      $EntryEkate  configure -state disabled
      $EntryEmacs  configure -state disabled
      $EntryXEmacs configure -state disabled
      $EntryEvi    configure -state disabled
      $EntryOth    configure -state disabled

      # -- Args of Editor & chosen Editor
      set Preferences::ChosenEditor     "$Preferences::text_viewer"
      set Preferences::ChosenEditorArgs "$Preferences::text_viewer_args"

      switch "$Preferences::ChosenEditor" {
           "gvim" {
	            $radEvi select 
		    if {[info exist Preferences::text_viewer_args] != 0} {
                          $EntryEvi    configure -state normal
	  	          $EntryEvi delete 0 end
	  	          $EntryEvi insert end $Preferences::text_viewer_args
		    }
	          }
	   "kate" {
                    $radEkate select
		    if {[info exist Preferences::text_viewer_args] != 0} {
                          $EntryEkate  configure -state normal
	  	          $EntryEkate delete 0 end
	  	          $EntryEkate insert end $Preferences::text_viewer_args
		    }
	          }
	  "emacs" {
	            $radEmacs select 
		    if {[info exist Preferences::text_viewer_args] != 0} {
                          $EntryEmacs  configure -state normal
	    	          $EntryEmacs delete 0 end 
	  	          $EntryEmacs insert end $Preferences::text_viewer_args
		    }
	          }
	  "xemacs" {
	            $radXEmacs select 
		    if {[info exist Preferences::text_viewer_args] != 0} {
                          $EntryXEmacs configure -state normal
	  	          $EntryXEmacs delete 0 end 
	  	          $EntryXEmacs insert end $Preferences::text_viewer_args
                    }
	           }
         "default" {
	            $radDefault select 
		    if {[info exist Preferences::text_viewer_args] != 0} {
	  	          $EntryXEmacs delete 0 end 
	  	          $EntryXEmacs insert end $Preferences::text_viewer_args
                    }
	           }
         "*" {
	            $radOther select 
		    if {[info exist Preferences::text_viewer_args] != 0} {
	  	          $EntryOth delete 0 end 
	  	          $EntryOth insert end $Preferences::text_viewer_args
                    }
	           }
        }
}

proc Preferences::ValidKey { SaveW ArgVar action type str } {

          switch $type {
	       "key" {
	                if { $action == 1 } {
	                         eval set $ArgVar \"$str\"
				 if {[string compare $str "" ] != 0 &&  [regexp {[a-zA-Z0-9\-\+]} $str]} {
			                      $SaveW configure -state normal
				 } else {
			                      $SaveW configure -state disabled
					      return 0
				 }
	                         return 1
                        } elseif { $action == 0 } {
	                         eval set $ArgVar \"$str\"
	                         return 1
			}
                     }
	  }


	  return 1
}

proc Preferences::UserEditor {SaveW ArgVar action type str } {

     set ret [Preferences::ValidKey $SaveW $ArgVar $action $type $str]
     if { $ret == 1 } {
              if {[string compare "$Preferences::ChosenEditorArgs" ""] != 0 } {
                         regsub -all {[ \r\n\t]+} "$Preferences::ChosenEditorArgs" {} Preferences::ChosenEditorArgs
                         set kiko [string trimleft "$Preferences::ChosenEditorArgs" " "]
                         set lkiko [split $kiko " "]
                         set Preferences::ChosenEditor   [lindex $lkiko 0]
                         set Preferences::ChosenEditorArgs [join [lrange $lkiko 1 end] " "]
              }
     }
}

# -- Note entry need to be modifief so not to have args error
proc Preferences::SavePref {compname sbuton cancelb okb utility args} {
              set word [join $args " "]
             
	      puts "word = $word"

	      catch {file delete $::env(TMPDIR)/.maestrorc}

	      # -- Need this for paths
	      regsub -all {/} $utility {\/} utility

              # -- What if the pref. doe not exist e in config file?
	      # -- Have to add code
	      catch [exec cat $::env(HOME)/.maestrorc | sed "s/^$compname\.*=\.\*/$compname=$utility $word/g" >  $::env(TMPDIR)/.maestrorc]
    
              if {[file exist $::env(TMPDIR)/.maestrorc]} {
	           catch [exec mv $::env(TMPDIR)/.maestrorc   $::env(HOME)/.maestrorc]
		   if  {[file exist $::env(TMPDIR)/.maestrorc]} {
		          Dialogs::show_msgdlg "Error Copying .maestrorc file ok warning "" $Preferences::PreferenceWindow
			  return 
                   }
              } else {
		   Dialogs::show_msgdlg "Error Updating .maestrorc file  ok warning"  ok warning "" $Preferences::PreferenceWindow
		   return 
	      }

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
		     set Preferences::ChosenBrowser "firefox"
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
                     Preferences::UpdateButtons "browser" "chrome" $Preferences::SaveBW $Preferences::OkBW $Preferences::CancelBW
		     set Preferences::ChosenBrowser "chromium-browser"
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
		     set Preferences::ChosenBrowser "konqueror"
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


      # -- Args of chosen WWW Browser
      set Preferences::ChosenBrowserArgs "$Preferences::browser_args"

      switch $www  {
         "firefox" {
	            $radffox select 
		    if {[info exist Preferences::browser_args] != 0} {
		           $Entryfox delete 0 end 
		           $Entryfox insert end $Preferences::browser_args
		    }
                    $Entryfox configure -state normal
	        }
	 "chromium-browser" {
                   $radchrome select
		   if {[info exist Preferences::browser_args] != 0} {
		        $Entrychr delete 0 end 
		        $Entrychr insert end $Preferences::browser_args
		   }
                   $Entrychr configure -state normal
	        }
      "konqueror" {
	           $radKonq select 
		   if {[info exist Preferences::browser_args] != 0} {
		        $Entrykon delete 0 end 
		        $Entrykon insert end $Preferences::browser_args
		   }
                   $Entrykon configure -state normal
	        }
      }
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
		     set Preferences::ChosenKonsol "konsole"
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
		     set Preferences::ChosenKonsol "xterm"
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
		     set Preferences::ChosenKonsol "ksystraycmd"
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

      # -- disable all
      $Entrycon  configure -state disabled
      $Entryxtr  configure -state disabled
      $Entryksys configure -state disabled

      # -- Args of chosen console
      set Preferences::ChosenKonsolArgs "$Preferences::default_console_args"

      switch $Kon {
         "konsole" {
	           $radCkonsol select 
		   if {[info exist Preferences::default_console_args] != 0} {
		        $Entrycon delete 0 end 
		        $Entrycon insert end $Preferences::default_console_args
		   }
		   $Entrycon  configure -state normal
	        }
	 "xterm" {
                   $radCxterm select
		   if {[info exist Preferences::default_console_args] != 0} {
		       $Entryxtr delete 0 end 
		       $Entryxtr insert end $Preferences::default_console_args
		   }
		   $Entryxtr  configure -state normal
	        }
   "ksystraycmd" {
                   $radksys select
		   if {[info exist Preferences::default_console_args] != 0} {
		       $Entryksys delete 0 end 
		       $Entryksys insert end $Preferences::default_console_args
		   }
		   $Entryksys configure -state normal
	        }
      }

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
      set PathImages "/home/binops/afsi/sio/datafiles/images/MaestroExpManager"

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
                                  $Preferences::SaveBI configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn1       [radiobutton $frmIcons.rn1 -image $XPManager::img_ExpNoteIcon  -variable icon -value "note1" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn2       [radiobutton $frmIcons.rn2 -image $XPManager::img_ExpSunny -variable icon -value "sunny" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn3       [radiobutton $frmIcons.rn3 -image $XPManager::img_ExpThunder -variable icon -value "thunder" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI configure -state disabled
                                  $Preferences::CancelBI configure -state disabled
                                  $Preferences::OkBI     configure -state normal
		     }
		    }]

      set rn4       [radiobutton $frmIcons.rn4 -image $XPManager::img_ExpThunderstorms -variable icon -value "rain" -command {\
                     if {[string compare $Preferences::exp_icon "$icon"] != 0 ||\
		         [string compare $Preferences::flow_geometry "$kw1"] != 0 ||\
			 [string compare [file tail $Preferences::background_image] $Preferences::_WallPaper] != 0} {
                                  $Preferences::SaveBI configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				  set Preferences::ChosenIcon "$icon"
                     } else {
                                  $Preferences::SaveBI configure -state disabled
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
		      if {[regexp {\/home\/binops\/afsi\/sio\/datafiles\/images\/MaestroExpManager} $bkg_gif]} {
		                 set bkg_gif [file tail $bkg_gif]
		      }
                      
		      set Preferences::_WallPaper $bkg_gif

		      if {[string compare [file tail $Preferences::background_image] $bkg_gif] != 0 ||\
		          [string compare $Preferences::exp_icon "$icon"] != 0 || \
			  [string compare $Preferences::flow_geometry "$kw1"] != 0} {
		                  $Preferences::SaveBI configure -state normal
                                  $Preferences::OkBI     configure -state disabled
                                  $Preferences::CancelBI configure -state normal
				 set Preferences::ChosenWallP $Preferences::_WallPaper 
                      } else {
                                 $Preferences::SaveBI configure -state disabled
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
proc Preferences::FindAndValidateExpDir { path } {
          # -- remove blanks
	  XPManager::update_progdlg $Preferences::PreferenceWindow "" "Finding Experiences ... "
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
	      if {[info exists Preferences::UsrExpRepository] != 0} {
	             set to_add [string trimright [file join [file normalize $path] { }]]
	             file stat $to_add statinfo
                     set dev_toadd $statinfo(dev)
                     set ino_toadd $statinfo(ino)
                     set match 0
	             foreach upth $Preferences::UsrExpRepository { 
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

proc Preferences::ParseUserMaestrorc {} {

           set prefparser [interp create -safe]
	   $prefparser alias UsrExpRepository Preferences::set_prefs_cmd_UsrExpRepository
	   $prefparser alias auto_msg_display Preferences::set_prefs_cmd_auto_msg_display
	   $prefparser alias auto_launch Preferences::set_prefs_cmd_auto_launch
	   $prefparser alias show_abort_type Preferences::set_prefs_cmd_show_abort_type
	   $prefparser alias show_event_type Preferences::set_prefs_cmd_show_event_type
	   $prefparser alias show_info_type Preferences::set_prefs_cmd_show_info_type
	   $prefparser alias node_display_pref Preferences::set_prefs_cmd_node_display_pref
	   $prefparser alias default_console Preferences::set_prefs_cmd_default_console
	   $prefparser alias text_viewer Preferences::set_prefs_cmd_text_viewer
	   $prefparser alias browser Preferences::set_prefs_cmd_browser
	   $prefparser alias flow_geometry Preferences::set_prefs_cmd_flowgeometry
	   $prefparser alias background_image Preferences::set_prefs_cmd_background_image
	   $prefparser alias exp_icon Preferences::set_prefs_cmd_expicon
	   $prefparser alias user_tmp_dir Preferences::set_prefs_user_tmp_dir
	   # -- check for these
	   $prefparser alias vcs_app_name Preferences::set_prefs_vcs_app_name
	   $prefparser alias vcs_path Preferences::set_prefs_vcs_path

	   set cmd {
	           catch [exec grep -v "^#"  $::env(HOME)/.maestrorc | tr -s "=" " " > $::env(TMPDIR)/kaka]
	           set fid [open [file join $::env(TMPDIR) kaka] r]
		   set script [read $fid]
		   close $fid
		   $prefparser eval $script
	   }
	   if {[catch  $cmd err] != 0} {
		    set Preferences::ERROR_PARSING_USER_CONFIG  1
           }
}

proc Preferences::set_prefs_cmd_UsrExpRepository {name args} {

   regsub -all {[ \r\n\t]+} $name {} name
    if {[string compare $name ""] != 0} {
            set Preferences::UsrExpRepository [split $name ":"]
    }
}

proc Preferences::set_prefs_cmd_auto_msg_display {name args} {
   set  Preferences::auto_msg_display $name
}
proc Preferences::set_prefs_cmd_auto_launch {name args} {
   set  Preferences::auto_launch $name
}
proc Preferences::set_prefs_cmd_show_abort_type {name args} { 
   set  Preferences::show_abort_type $name
}
proc Preferences::set_prefs_cmd_show_event_type {name args} { 
   set  Preferences::show_event_type $name
}
proc Preferences::set_prefs_cmd_show_info_type {name args} { 
   set  Preferences::show_info_type $name
}
proc Preferences::set_prefs_cmd_node_display_pref {name args} { 
   set  Preferences::node_display_pref $name
}
proc Preferences::set_prefs_cmd_default_console {name args} { 
   set  Preferences::default_console $name 
   set  Preferences::default_console_args "$args"
}
proc Preferences::set_prefs_cmd_text_viewer {name args} { 
   set  Preferences::text_viewer $name 
   set  Preferences::text_viewer_args "$args"
}
proc Preferences::set_prefs_cmd_browser {name args} { 
   set  Preferences::browser $name
   set  Preferences::browser_args "$args"
}
proc Preferences::set_prefs_cmd_flowgeometry {name} {
   set  Preferences::flow_geometry $name
}

proc Preferences::set_prefs_cmd_background_image {name} {
   regsub -all {[ \r\n\t]+} $name {} name
   set Preferences::background_image  $name 
}

proc Preferences::set_prefs_user_tmp_dir {name} {
   set  Preferences::user_tmp_dir $name
}

proc Preferences::set_prefs_cmd_expicon {name} {
   global SEQ_MANAGER_BIN

   switch $name {
          "xp" {
                 set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.gif] 
		 set  Preferences::exp_icon "xp"
               }
       "note1" {
                 set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.note.gif] 
		 set  Preferences::exp_icon "note1"
               }
       "rain" {
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
       "*"     {
                 set  Preferences::exp_icon_img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.gif] 
		 set  Preferences::exp_icon "xp"
               }
   }
}

proc Preferences::set_liste_Wall_Papers {} {
     foreach wfile [glob -nocomplain -type { f r} -path /home/binops/afsi/sio/datafiles/images/MaestroExpManager/ *.gif] {
		lappend Preferences::ListWallPapers [file tail $wfile]
     }
}

proc Preferences::set_prefs_vcs_app_name {name args} {
}

proc Preferences::set_prefs_vcs_path {name args} {
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
	              lappend listPref "default_console=xterm"
	      }
	      if {[info exists Preferences::text_viewer] == 0} {
	              lappend listPref "text_viewer=gvim"
	      }
	      if {[info exists Preferences::browser] == 0} {
	              lappend listPref "browser=firefox"
	      }
	      if {[info exists Preferences::flow_geometry] == 0} {
	              lappend listPref "flow_geometry=800x600"
	      }
	      if {[info exists Preferences::background_image] == 0} {
	              lappend listPref "background_image=artist_canvas_darkblue.gif"
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

	      # -- Remove any previous file
	      catch {[exec rm -f $::env(TMPDIR)/prefs.default]} 

	      if {[llength $listPref] != 0 } {
                  foreach item $listPref {
		       puts "item=$item"
		       catch {[exec echo "$item" >> $::env(TMPDIR)/prefs.default]} 
		  }
		  if {[file exist $::env(TMPDIR)/prefs.default]} {
                              #catch {[exec cat $::env(TMPDIR)/prefs.default >> $::env(HOME)/.maestrorc]}
		  }
	      }
}


