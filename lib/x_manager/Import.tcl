global stdin stdout

namespace eval Import {
    
      variable ImportW 
      variable ImportW2
      variable _selected "no-selection"
      variable _ExpDir "no-selection" 
      variable _FromWhere "browser" 
      variable initdir 
}

proc Import::ImportExp { exp } {
      
      global ListAllExperiments
      
      variable _importGit 
      variable _importCte 
      variable ImportCte 
      variable ImportW 
      variable initdir 
      variable Destination 

      if {[winfo exists .import]} {
              destroy .import
      }
      
      set ImportW [toplevel .import] 
      wm title $ImportW $Dialogs::Imp_title 
      wm minsize $ImportW 600 340

      # -- Initialize 
      set Import::initdir "" 
      set Import::_importGit 0 
      set Import::_importCte 0 

      # -- get everything for now
      set Import::initdir [Preferences::GetTabListDepots "none"]
      if {[string compare $Import::initdir "" ] == 0 } {
                     set Import::initdir $::env(HOME)/
      }

      # -- What if UsrExpRepository is not given
      if { 1 == 2 } {
      if {[info exists Preferences::UsrExpRepository] != 0 } {
                # have to check if depot is owned by user
		foreach dpt $Preferences::UsrExpRepository {
		       if {[file writable $dpt]} {
		               lappend Import::initdir $dpt 
		       }
		}
      } else {
                set Import::initdir $::env(HOME)/ 
      }
      }


      set frm [frame .import.frame -border 2 -relief groove]

      set iexp  [TitleFrame $frm.iexp -text $Dialogs::Imp_selected]
      set nexp  [TitleFrame $frm.nexp -text $Dialogs::Imp_ExpName]
      set hexp  [TitleFrame $frm.hexp -text $Dialogs::Imp_ExpSubD]
      set dexp  [TitleFrame $frm.dexp -text $Dialogs::Imp_ExpDest]
      set gexp  [TitleFrame $frm.gexp -text $Dialogs::Imp_ExpGit]

      set subf1 [$iexp getframe]
      set subf2 [$nexp getframe]
      set subf3 [$hexp getframe]
      set subf4 [$dexp getframe]
      set subf5 [$gexp getframe]

      set ImpExpName [ComboBox $subf1.list -textvariable Import::_selected \
                    -width 60 \
		    -editable false \
		    -autocomplete false \
		    -entrybg  #FFFFFF \
                    -values $ListAllExperiments \
		    -modifycmd "Import::UpdateIMportWidget $subf1 $subf5" \
		    -bwlistbox false \
		    -selectbackground #FFFFFF \
		    -selectforeground black \
		    -justify left \
		    -insertborderwidth 0\
		    -helptext "List of Available Experiments"]

      set NewExpName [Entry $subf2.entrys  -textvariable Import::_importname \
                -width 60\
		-bg #FFFFFF \
                -command  {Import::CheckName $subf2.entrys} \
		-helptext "Import Name "]
      
      set ListPath [ComboBox $subf4.list -textvariable Import::Destination \
                    -width 60 \
		    -editable true \
		    -autocomplete false \
		    -entrybg  #FFFFFF \
                    -values $Import::initdir \
		    -modifycmd {} \
		    -bwlistbox false \
		    -selectbackground #FFFFFF \
		    -selectforeground black \
		    -justify left \
		    -insertborderwidth 0\
		    -helptext "List of Available Paths"]

      set ImportGit [checkbutton $subf5.radgit -text "Import Git" -font 8 -variable Import::_ImportGit -onvalue 1 -offvalue 0]
      set ImportCte [checkbutton $subf5.radcte -text "Copy Constants Localy (MB)" -font 8 -variable Import::_ImportCte -onvalue 1 -offvalue 0 \
                      -command {Import::GetConstantsSize $Import::_selected} ]

      set ImportSize [Entry  $subf5.size -textvariable Import::_Importsize \
                      -width 10\
		      -bg #FFFFFF \
		      -helptext "Total Size of constants to import "]

      #  -modifycmd {compo .a } --> proc compo {w} { puts "Your Favourite Composer is [$w get]"; destroy .a}

      set XpBrBut [Button $subf1.but1 -text "..." \
                 -image $XPManager::img_XpSel \
                 -command {
		      #set xp [XpSelector::selectXp]
		      set xp [tk_chooseDirectory -initialdir $env(HOME)/ -title "Choose a directory" -parent $Import::ImportW]
		      if {$xp ne ""} {
		            puts  "Selected $xp"
			    if { ! [file exist $xp/EntryModule] } {
			           Dialogs::show_msgdlg $Dialogs::Dlg_ProvideExpPath ok warning "" $Import::ImportW
			    } else {
		                   set Import::_selected $xp
			    }
		      } 
		      }]


      label $frm.lab -text $Dialogs::Imp_title -font "ansi 12 "
      frame $frm.btn -height 2 -borderwidth 1 -relief flat

      set CancelB [button $frm.btn.cancel -text "Cancel" -image $XPManager::img_Cancel -command {destroy $Import::ImportW}]
      set NextB   [button $frm.btn.next   -text "Next"   -image $XPManager::img_Next   -command {Import::NextButton}]

      set HelpB   [button $frm.btn.help -text "Help" -image $XPManager::img_Help -command {\
                   Dialogs::show_msgdlg "This will Show Help " ok info "" $Import::ImportW}]

      frame $frm.sep1 -height 2 -borderwidth 1 -relief sunken
      frame $frm.sep2 -height 2 -borderwidth 1 -relief sunken


      # -- Pack everything
      pack $frm.lab -fill x

      pack $frm.btn -side bottom
      pack $NextB -side right  -padx 4
      pack $CancelB -side right 
      pack $HelpB -side left 

      pack $frm.sep1 -side bottom -fill x -pady 4

      pack $iexp -anchor w -pady 2 -padx 2
      pack $ImpExpName -side left -padx 4

      if {[string compare $exp ""] == 0} {
               pack $XpBrBut -side left -padx 4
	       set Import::_importname ""
      } else {
              # -- Is User wanting only one Exp.?
	      if {[file exist $exp/EntryModule]} {
                      set Import::_importname [file tail $exp] 
              } else {
                      set Import::_importname "" 
	      }
      }


      pack $nexp -anchor w -pady 2 -padx 2
      pack $NewExpName -side left -padx 4

      pack $dexp -anchor w -pady 2 -padx 2
      pack $ListPath -side left -padx 4

      pack $gexp -anchor w -pady 2 -padx 2
      pack $ImportGit -side left -padx 4
      pack $ImportCte -side left -padx 4
      pack $ImportSize -side left -padx 4

      pack $frm -fill x

      # -- Set values
      set Import::_selected $exp
      set Import::_Importsize ""

      # -- deselected 
      $ImportCte deselect

      # -- disable Exp name if not an experiment
      #if {[string compare $Import::_importname ""] == 0} {
      #         $NewExpName configure -state disabled
      #}
}
proc Import::NextButton { } {

             if {[string compare $Import::_selected ""] == 0} {
		            Dialogs::show_msgdlg "You Must Choose an Experiment"  ok warning "" $Import::ImportW
			    return
	     }

             if {[regexp {[ \r\n\t]+} $Import::Destination] || [string compare $Import::Destination ""] == 0} {
		            Dialogs::show_msgdlg "You Must give a Valid Destination path"  ok warning "" $Import::ImportW
			    return
             }

             if {[file writable $Import::Destination] == 0} {
		            Dialogs::show_msgdlg "You dont have the permission to write in Destination path"  ok warning "" $Import::ImportW
			    return
	     }

	     # -- ok Execute Import
            Import::ImportNext $Import::ImportW $Import::_importname $Import::_selected $Import::Destination $Import::_ImportGit $Import::_ImportCte
}


proc Import::GetConstantsSize { selected } {
 # -- If this is Only one exp
 if { [file exist $selected/EntryModule] } {
        if {[file exist $selected/hub/constants/]} { 
                 set size [exec du -ms $selected/hub/constants/ | tr \011 \040]
	         set vsize [split $size " "]
	         set Import::_Importsize [lindex $vsize 0]
        } else {
		Dialogs::show_msgdlg $Dialogs::Imp_NoConstants  ok warning "" $Import::ImportW
                $Import::ImportCte deselect
	        set Import::_Importsize 0 
	}
 } else {
            puts "selected :$selected MUltiple"
 }
}

proc Import::UpdateIMportWidget { wid1 wid2 } {
#    -modifycmd "Import::UpdateExpName $subf1.list

      Import::UpdateExpName $wid1.list
      $wid2.radcte deselect
      set Import::_Importsize ""
}

proc Import::ImportNext { win newname srcexp dest git cte} {
      
      variable ImportW2
     
      if {[winfo exists $win]} {
            destroy $win
      }

      if {[winfo exists .import2]} {
             destroy .import2
      }

      set ImportW2 [toplevel .import2] 
      wm title $ImportW2 "$Dialogs::Imp_title : continue ... "
      wm minsize $ImportW2 600 400

      # -- check how Many Exps
      # -- need changes to tclfind to return a list
      set listExp {}

      
      # -- if a multitude of exps
      if {[file exist $srcexp/EntryModule] && [catch [file link $srcexp/EntryModule]]} {
             lappend listExp $srcexp
      } else {
             set listExp [XTree::FindExps $srcexp]
      }


      set Ctrlfrm2 [frame $ImportW2.ctrf]

      set dptexp [TitleFrame $Ctrlfrm2.iexp -text $Dialogs::Imp_Parametres]
      set subf [$dptexp getframe]

      set dpexp [ListBox::create $subf.lb \
                -relief sunken -borderwidth 1 \
		-dragevent 1 \
		-height 20 \
                -width 70 -highlightthickness 0 -selectmode single -selectforeground black\
		-bg #FFFFFF \
		-padx 25]

      set ButFrame [frame $Ctrlfrm2.bfrm]
      set CancelB2 [button $ButFrame.cancel -text "Cancel"  -command {destroy $Import::ImportW2}]
      set NextB2   [button $ButFrame.next   -text "Proceed" -command [list Import::ExecImport $Import::ImportW2 $newname $srcexp $dest $git $cte]]
     
      pack $NextB2   -side right  -padx 4
      pack $CancelB2 -side right 

      pack $ButFrame -side bottom 
      pack $dptexp   -fill x
      pack $dpexp    -anchor w

      pack $Ctrlfrm2


      # -- Ok insert xps in list
      foreach exp $listExp {
            $dpexp insert end $exp -text $exp  
      }

      # -- Add info about Name and Git
      # -- Check git
      if { $git == 1 } {
             $dpexp insert end "Git" -text "Import Experiment Git" 
      } else {
             $dpexp insert end "Git" -text "Experiment Git will not be Imported" 
      }

      # -- Check Constants
      if { $cte == 1 } {
             $dpexp insert end "Const" -text "Constants Files will be copied locally" 
      } else {
             $dpexp insert end "Const" -text "Constants will not be Imported ... You must do link to the Source Exp." 
      }

      # -- Destination 
      $dpexp insert end "dist" -text "Destination=$dest" 

      if {[string compare "$newname" ""] != 0} {
             $dpexp insert end "Name" -text "Experiment Name will be : $newname " 
      }

}

proc Import::UpdateExpName { widgt } {
       set nom [file tail [$widgt get]]
       set Import::_importname $nom
}

proc Import::CheckName { widgt } {
     # set Import::_importname after checking
}


proc Import::ExecImport {win newname srcexp dest git cte} {
      
      variable ExeImport
      variable ERROR  0
      variable SUCCES 0

      if {[winfo exists $win]} {
             destroy $win
      }

      if {[winfo exists .execimport]} {
               destroy .execimport
      }

      set ExeImport [toplevel .execimport] 
      wm minsize $ExeImport 600 200

      set frm [frame $ExeImport.ctrf]
     

      set WinInfoWidget [text $frm.txt -xscrollcommand "$frm.xscroll set" -yscrollcommand "$frm.yscroll set"  \
                         -width 80 -height 30 -bg #FFFFFF -font 12 -wrap none]
      
      scrollbar $frm.xscroll  -command "$frm.txt xview"
      scrollbar $frm.yscroll  -command "$frm.txt yview"

      set CancelB       [button $frm.cancel -text "Quit" -bg gray -command {destroy $Import::ExeImport}]

      #pack $CancelB -side bottom 
      pack $frm -fill both -expand true 
      grid $frm.txt $frm.yscroll -sticky news
      #grid $frm.xscroll -sticky news

      #pack $CancelB -side bottom 
      #pack $scrobarx -fill x
      #pack $scrobary -side right -fill y
      #pack $WinInfoWidget -expand true -fill both
      
      grid $CancelB -sticky w
      
      $WinInfoWidget insert end "New Name=$newname \n"
      $WinInfoWidget insert end "Source=$srcexp \n"
      $WinInfoWidget insert end "Destination=$dest \n"

      set ImportScript "${SEQ_MANAGER_BIN}/import_maestro_exp"

      if { $git == 1 } {
              set arg_git "-g"
      } else {
              set arg_git ""
      }
      
      if { $cte == 1 } {
              set arg_cte ""
      } else {
              set arg_cte "-c"
      }

      # -- Notes : import will put the target name of link 
      if {[string compare "$newname" ""] != 0 } {
		set cmdargs "-s $srcexp -d $dest/$newname -n $arg_git $arg_cte"
      } else {
		set cmdargs "-s $srcexp -d $dest $arg_git $arg_cte"
      }
      
      $WinInfoWidget insert end "command= $ImportScript $cmdargs\n"

      update 
      set fid [open "|$ImportScript $cmdargs 2>@ stdout" r+]

      fconfigure $fid -buffering line -translation auto 
      fileevent  $fid readable "Import::GetImportScriptOutputs $fid $WinInfoWidget $ExeImport"

}

proc Import::GetImportScriptOutputs {fid Winfo win} {
    

      if {[gets $fid line] >= 0 } {

		$Winfo insert end "$line \n"
		$Winfo see end

		if {[regexp  {Overwrite} $line]} {
		         set ret [Dialogs::show_msgdlg $Dialogs::Imp_Overwrite  yesno question "" $win] 
			 if { $ret == 0 } {
		               puts $fid "y"
                         } else {
		               puts $fid "n"
			 }
			 flush $fid
		} elseif {[regexp {(error|ERROR)} $line]} {
		         set Import::ERROR 1
			 #$Winfo tag configure $line  -foreground red
		} elseif {[regexp {Done importing} $line]} {
		         set Import::SUCCES 1
			 #$Winfo tag configure $line  -foreground green
		} elseif {[regexp {Import[ +]Cancelled} $line]} {
		         close $fid
			 return
		}

      } else {
                close $fid
		if { $Import::SUCCES == 1 } {
		         Dialogs::show_msgdlg $Dialogs::Imp_Ok  ok info "" $win] 
		} else  {
		         Dialogs::show_msgdlg $Dialogs::Imp_Ko  ok warning "" $win] 
		}
      }
      
}


