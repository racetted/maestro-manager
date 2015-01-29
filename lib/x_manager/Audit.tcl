package require tablelist 5.5

global notebook 
global array TabFrames1
global array TabFrames2


namespace eval Audit {
          namespace inscope :: package require tablelist 5.5
          variable _selected1 no-selection
          variable _selected2 no-selection
          variable _filter 
          
          variable _TabFrame1 
          variable _TabFrame2 
}

proc Audit::apopup {win nb X Y pane } {
              
             # check to see if current click is on the top tab
             if {[string compare [$nb raise] $pane] == 0} {
                        tk_popup $win $X $Y
               }
}

proc Audit::AuditExp { exp1 } {

      global notebook
      global TabFrames1 
      global TabFrames2 
      global ListAllExperiments
     
      variable AuditWin
      variable BAudit
      variable subf1
      variable subf2
      variable subf3

      if {[winfo exists .audit]} {
            destroy .audit
      }

      set top .audit
      set AuditWin [toplevel $top] 
      wm title $AuditWin $Dialogs::Aud_title 
      wm minsize $AuditWin 800 860

      set frm [frame .audit.frame -border 2 -relief groove]

      # -- kill any remaining popup 
      Audit::killPopMenus

      # set list of Filters
      set ListFilters {}
      lappend ListFilters "Show Only Changed Files"
      lappend ListFilters "Show All"

      # set default _filter to All
      set Audit::_filter "Show All"

      set texp1 [TitleFrame $frm.texp1 -text $Dialogs::Aud_Exp1]
      set texp2 [TitleFrame $frm.texp2 -text $Dialogs::Aud_Exp2]
      set texp3 [TitleFrame $frm.texp3 -text $Dialogs::Aud_filtre]

      set subf1 [$texp1 getframe]
      set subf2 [$texp2 getframe]
      set subf3 [$texp3 getframe]


      set eexp1 [ComboBox $subf1.list -textvariable Audit::_selected1 \
                    -width 75 \
                    -editable false \
                    -autocomplete false \
                    -entrybg  #FFFFFF \
                    -values $ListAllExperiments \
                    -modifycmd {\
		          set Audit::_selected1 [lindex [$Audit::subf1.list cget -values] [$Audit::subf1.list getvalue]];
			  Audit::EnableAuditBut $Audit::_selected2 
			  } \
                    -bwlistbox false \
                    -selectbackground #FFFFFF \
                    -selectforeground black \
                    -justify left \
                    -insertborderwidth 0\
                    -helptext "Experiment path"]


      set eexp2 [ComboBox $subf2.list -textvariable Audit::_selected2 \
                    -width 75 \
                    -editable false \
                    -autocomplete false \
                    -entrybg  #FFFFFF \
                    -values $ListAllExperiments \
                    -modifycmd {\
		            set Audit::_selected2 [lindex [$Audit::subf2.list cget -values] [$Audit::subf2.list getvalue]]; 
			    Audit::EnableAuditBut $Audit::_selected1 
			    } \
                    -bwlistbox false \
                    -selectbackground #FFFFFF \
                    -selectforeground black \
                    -justify left \
                    -insertborderwidth 0\
                    -helptext "Experiment path"]
      
      set efilter [ComboBox $subf3.list -textvariable Audit::_filter \
                    -width 25 \
                    -editable false \
                    -autocomplete false \
                    -entrybg  #FFFFFF \
                    -values $ListFilters \
                    -modifycmd {set Audit::_filter [lindex [$Audit::subf3.list cget -values] [$Audit::subf3.list getvalue]] } \
                    -bwlistbox false \
                    -selectbackground #FFFFFF \
                    -selectforeground black \
                    -justify left \
                    -insertborderwidth 0\
                    -helptext "Filters"]


      Button $subf1.but1 -text "..." \
                 -image $XPManager::img_XpSel \
                 -command {
		            set xp [tk_chooseDirectory -initialdir $env(HOME)/ -title "Choose an Experiment" -parent .audit]
			    if { "$xp" ne "" } {
			         set kris [catch {file type $xp/EntryModule} ftype]
			         if {$kris != 0} {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_ProvideExpPath ok warning "" .audit
			         } else {
			                 set Audit::_selected1 $xp
			                 set kiki1 $xp
			         }
			    }
			  }

      Button $subf2.but2 -text "..." \
                 -image $XPManager::img_XpSel \
                 -command  {
		            set xp [tk_chooseDirectory -initialdir $env(HOME)/ -title "Choose an Experiment" -parent .audit]
			    if { "$xp" ne "" } {
			         set kris [catch {file type $xp/EntryModule} ftype]
			         if {$kris != 0} {
		                         Dialogs::show_msgdlg $Dialogs::Dlg_ProvideExpPath ok warning "" .audit
			         } else {
			                 set Audit::_selected2 $xp
			                 set kiki2 $xp
			         }
			    }
			  }
     
      set BAudit [Button $frm.but3 -text $Dialogs::Aud_button -bg gray -command "Audit::AuditAll $AuditWin"]

      label $frm.lab -text "Audit Experiments" -font "ansi 12"
      frame $frm.btn -height 2 -borderwidth 1 -relief flat
      button $frm.btn.close -text "Close" -image $XPManager::img_Close -command {
	     Audit::killPopMenus
             if { [winfo exists .audit] } {
	             destroy .audit
             }
      }

      button $frm.btn.help -text "Help" -image $XPManager::img_Help -command { Audit::ShowHelp }

      frame $frm.sep1 -height 2 -borderwidth 1 -relief sunken
      frame $frm.sep2 -height 2 -borderwidth 1 -relief sunken

      # -- create notebook
      set notebook [NoteBook ${frm}.nb]

      $notebook  insert 1 modules   -text "modules"
      $notebook  insert 2 resources -text "resources"
      $notebook  insert 3 bin       -text "Bin"
      $notebook  insert 4 constants -text "hub/constants"
      $notebook  insert 5 exphome   -text "ExpHome"

      foreach panel {modules resources bin constants exphome}  {
                set pane [$notebook getframe $panel]
		set pw  [PanedWindow $pane.pw -side top]

	
                set bf [frame $pane.b]
		eval variable RedoBut_$panel
                eval set RedoBut_$panel [button $bf.b1 -text "Audit" -font "ansi 9" -bg gray -command {\
		         Audit::AuditComponent $Audit::AuditWin [$notebook raise]
		        }] 

		set pne [$pw add -weight 1]
		set tl  [TitleFrame $pne.lf -text "$Dialogs::All_experience 1" -side center]
                
		set _frame1 [$tl getframe] 
		set _TabFrame1 [frame ${_frame1}.t -class ScrollArea]
		set TabFrames1($panel) $_TabFrame1
                
                Audit::CreateTabliste "no-selection" $_TabFrame1 $_frame1 ${panel}0
		pack $tl -fill both -expand yes

		set pne [$pw add -weight 2]
		set tl  [TitleFrame $pne.lf -text "$Dialogs::All_experience 2" -side center]
		set _frame2 [$tl getframe]
		set _TabFrame2 [frame ${_frame2}.t -class ScrollArea]
		set  TabFrames2($panel) $_TabFrame2

                Audit::CreateTabliste "no-selection" $_TabFrame2 $_frame2 ${panel}1
		pack $tl -fill both -expand yes
                
		# -- pack
                eval pack \$RedoBut_$panel -side left -padx 4
                pack $bf -side top -anchor w

		pack $pw -fill both -expand yes
                 
      }


      # make a popup menu for the tabs (just add commands)
      #menu .popup -tearoff 0 -activeborderwidth 0
      #.popup add separator 
      #.popup add command -label "Audit This Component Only" -command {Audit::AuditComponent $Audit::AuditWin [$notebook raise]}

      # bind right mouse button to the popup menus
      #$notebook bindtabs <Button-3> [list Audit::apopup .popup $notebook %X %Y]
      #$notebook compute_size

      $notebook raise [$notebook page 0]

      # -- Pack everything
      pack $frm -fill x
      pack $frm.lab -fill x

      pack $frm.btn.close -side left -anchor w -padx 4
      pack $frm.btn.help -side left -anchor e -padx 4
      pack $frm.btn -side bottom

      pack $frm.sep1 -side bottom -fill x -pady 4

      pack $notebook -fill both -expand yes -padx 4 -pady 4 -side bottom
      pack $frm.sep2 -side bottom -fill x -pady 4

      pack $texp1 -anchor w -pady 2 -padx 2
      pack $eexp1 -side left -padx 4
      pack $subf1.but1 -side left -padx 4
      
      pack $texp2 -anchor w -pady 2 -padx 2
      pack $eexp2 -side left -padx 4
      pack $subf2.but2 -side left -padx 4
      
      pack $texp3 -anchor w -pady 2 -padx 2
      pack $efilter -side left -padx 4 -pady 6

      pack $BAudit -side left

      # -- Set the values given
      regsub -all {\/\/} $exp1 {/} exp1 
      set Audit::_selected1 $exp1 
      set Audit::_selected2 ""

      # -- At startup disable audit button
      $BAudit configure -state disabled

      # -- For now disable exphome
      #$notebook itemconfigure exphome -state disabled
}

proc Audit::EnableAuditBut { sentry } {
       
       if {[string compare $sentry "no-selection"] != 0 && [string compare $sentry ""] != 0} {
            # - Enable audit All butt
	    $Audit::BAudit configure -state normal
       } 
}

proc Audit::EnableAllComponentBut {} {

   # Enable components buttons
      foreach indx {0 1} {
         foreach item {modules resources bin constants exphome} {
          eval \$Audit::UpBut_${item}${indx} configure -state normal
          eval \$Audit::DirUp_${item}${indx} configure -state normal
         }
      }
}

proc Audit::killPopMenus {} {
    set kiki {0 1}
     foreach panel {modules resources bin constants exphome}  {
        foreach i $kiki {
             if { [winfo exists .menu${panel}$i] } {
                   destroy .menu${panel}$i
             }
        }
     }
     if { [winfo exists .popup] } {
             destroy .popup  
     }
}

proc Audit::AuditAll {w} {

      global   notebook       
      global array TabFrames1  
      global array TabFrames2  
      variable _selected1
      variable _selected2

      # -- must have 2 Exps
      if {  [string compare $Audit::_selected1 "no-selection"] == 0 \
         || [string compare $Audit::_selected1 ""] == 0 \
         || [string compare $Audit::_selected2 "no-selection"] == 0 \
	 || [string compare $Audit::_selected2 ""] == 0} {
               Dialogs::show_msgdlg $Dialogs::Dlg_ErrorAudit2Exp  ok warning "" .
               return
      }

      # -- put a progress bar here
      XPManager::show_progdlg $w "Audit in progress"



      foreach panel {modules resources bin constants exphome} {
             set x $TabFrames1($panel)
             set y $TabFrames2($panel)

	     if {[string compare $panel "constants"] == 0 } { 
	             set modifier "/hub/constants"
             } elseif {[string compare $panel "exphome"] == 0 }  {
	             set modifier "."
	     } else {
	             set modifier $panel
	     }

	     if {(![file isdirectory $_selected1/$modifier] || ![file readable $_selected1/$modifier])} {
                        XPManager::update_progdlg $w $panel "Audit in progress"
                        Audit::putContents "no-selection" $x.tbl root
	     } else {
                        XPManager::update_progdlg $w $panel "Audit in progress"
                        Audit::putContents "$_selected1/$modifier" $x.tbl root
		        $x.tbl expandall
             }

	     if {(![file isdirectory $_selected2/$modifier] || ![file readable $_selected2/$modifier])} {
                        XPManager::update_progdlg $w $panel "Audit in progress"
                        Audit::putContents "no-selection" $y.tbl root
	     } else {
                        XPManager::update_progdlg $w $panel "Audit in progress"
                        Audit::putContents "$_selected2/$modifier" $y.tbl root
		        $y.tbl expandall
             }
      }

      $notebook raise modules

      destroy ${w}.progress

      # -- have to Enable buttons
      Audit::EnableAllComponentBut
}

proc Audit::AuditComponent {w ki} {

      global array TabFrames1  
      global array TabFrames2  

      # -- Check if the 2 experiment are given
      if {  [string compare $Audit::_selected1 "no-selection"] == 0 \
         || [string compare $Audit::_selected1 ""] == 0 \
         || [string compare $Audit::_selected2 "no-selection"] == 0 \
	 || [string compare $Audit::_selected2 ""] == 0} {

	       Dialogs::show_msgdlg "You Must Seelect 2 experiments" ok warning "" $w
               return
      }

      # -- put a progress bar here
      XPManager::show_progdlg $w "Audit in progress"

      set x $TabFrames1($ki)
      set y $TabFrames2($ki)

      if {[string compare $ki "constants"] == 0 } { 
	      set modifier "/hub/constants"
      } elseif {[string compare $ki "exphome"] == 0 } {
	      set modifier "."
      } else {
	      set modifier $ki
      }


      XPManager::update_progdlg $w $ki "Audit in progress ..."

      Audit::putContents "$Audit::_selected1/$modifier" $x.tbl root
      Audit::putContents "$Audit::_selected2/$modifier" $y.tbl root
      
      $x.tbl expandall
      $y.tbl expandall

      destroy ${w}.progress

      # --Enable buttons
      foreach indx {0 1} {
             eval \$Audit::UpBut_${ki}${indx} configure -state normal 
             eval \$Audit::DirUp_${ki}${indx} configure -state normal
      }
}

#------------------------------------------------------------------------------
# CreateTabliste
#
# Displays the contents of the directory dir in a tablelist widget.
#------------------------------------------------------------------------------
proc Audit::CreateTabliste {dir TabFrame Frame kaka} {

    variable bf

    set vsb $TabFrame.vsb
    set hsb $TabFrame.hsb

    tablelist::tablelist $TabFrame.tbl \
	-columns {0 "Name"	    left\
	          0 "Status"        left\
		  0 "Date Modified" left} \
	-expandcommand Audit::expandCmd -collapsecommand Audit::collapseCmd \
	-xscrollcommand [list $hsb set] -yscrollcommand [list $vsb set] \
	-movablecolumns no -setgrid no -showseparators yes -height 18 -width 40

    if {[$TabFrame.tbl cget -selectborderwidth] == 0} {
	   $TabFrame.tbl configure -spacing 1
    }

    $TabFrame.tbl columnconfigure 0 -formatcommand Audit::formatString -sortmode dictionary
    $TabFrame.tbl columnconfigure 1 -name Status -formatcommand Audit::formatString
    $TabFrame.tbl columnconfigure 2 -formatcommand Audit::formatString

    scrollbar $vsb -orient vertical   -command [list $TabFrame.tbl yview]
    scrollbar $hsb -orient horizontal -command [list $TabFrame.tbl xview]

    #
    # Create a pop-up menu with one command entry; bind the script
    # associated with its entry to the <Double-1> event, too
    #

    set menu  [menu .menu$kaka -tearoff no]
    $menu add command -label "View diff " -command  [list Audit::ViewDiff $TabFrame.tbl]
    $menu add command -label "View File " -command  [list Audit::ViewFile $TabFrame.tbl] 
    $menu add command -label "Quit "      -command  {} 


    set bodyTag [$TabFrame.tbl bodytag]
    bind $bodyTag <<Button3>>  [bind TablelistBody <Button-1>]
    bind $bodyTag <<Button3>> +[bind TablelistBody <ButtonRelease-1>]
    bind $bodyTag <<Button3>> +[list Audit::postPopupMenu %X %Y $TabFrame.tbl $kaka]
    #bind $bodyTag <Double-1>   [list Audit::putContentsOfSelFolder $TabFrame.tbl]
    bind $bodyTag <Double-1>   [list Audit::ResolveDoubleClick $TabFrame.tbl]

    #
    # Create  buttons within a frame child of the main widget
    #
    
    set frm_navigation [frame $Frame.nav -border 2 -relief groove]
    eval variable UpBut_$kaka 
    eval variable DirUp_$kaka 
    eval variable CurDir_$kaka 
    eval set UpBut_$kaka [button $frm_navigation.bup -image $XPManager::img_Up] 
    eval set DirUp_$kaka [Entry  $frm_navigation.ent -textvariable Audit::CurDir_$kaka -width 50 -bg #FFFFFF \
                          -helptext "Actual Directory" -editable false] 

    # Manage the widgets
    eval pack \$UpBut_$kaka -side left -padx 4 
    eval pack \$DirUp_$kaka -side left -padx 4 
    pack $frm_navigation -side top -anchor w

    grid $TabFrame.tbl -row 0 -rowspan 2 -column 0 -sticky news
    grid [$TabFrame.tbl cornerpath] -row 0 -column 1 -sticky ew
    grid $vsb	       -row 1 -column 1 -sticky ns
    grid $hsb -row 2 -column 0 -sticky ew
    grid rowconfigure    $TabFrame 1 -weight 1
    grid columnconfigure $TabFrame 0 -weight 1



    pack $TabFrame -side top -expand yes -fill both

    # Populate the tablelist with the contents of the given directory
    $TabFrame.tbl sortbycolumn 0
  
    # -- disable buttons at interface startup 
    eval \$UpBut_$kaka configure -state disabled
    eval \$DirUp_$kaka configure -state disabled

}

proc Audit::ViewDiff {tbl} {

        global SEQ_MANAGER_BIN
        
	set tclsh [ exec which maestro_wish8.5]

        set row [$tbl curselection]

	# -- If it is a file then process
	if { ! [$tbl hasrowattrib $row pathName]} {
	        set opt [Audit::formatString [$tbl cellcget $row,0 -text]]
		set attr [$tbl parentkey $row]
		 
		if {[string compare $attr "root" ] == 0 } { 
                      set dir1 [$tbl cellattrib $row,Status Fname]
		} else {
                      set dir1 [$tbl rowattrib $attr pathName]
                }

		set fpath1 ${dir1}/$opt
                
                catch {set ftype [exec file $fpath1]}

                # -- check if a link
		if {[regexp "symbolic link" $ftype]} {
			set base   [file dirname $fpath1]
			set lfile  [file readlink $fpath1]
			set ftype  [exec file $base/$lfile]
		}

		if {[regexp  "ASCII|Korn|HTML|text" "$ftype"]} {
	              # -- build 2nd path
	              if {[regexp $Audit::_selected1 $dir1]} {
		              regsub -all "$Audit::_selected1" $dir1 "$Audit::_selected2" dir2
	              } else {
		              regsub -all "$Audit::_selected2" $dir1 "$Audit::_selected1" dir2
	              }

                      set fpath2 ${dir2}/$opt

		      # -- We should check existence of file 1 & 2 before calling tkdiff
                      exec  ${tclsh} ${SEQ_MANAGER_BIN}/tkdiff $fpath1 $fpath2 &
                } else {
		        Dialogs::show_msgdlg $Dialogs::Dlg_NoAsciiFile ok warning "" .audit
                }
        }
}


proc Audit::ViewFile {tbl} {

        set row [$tbl curselection]

	# -- If it is a file then process
	if { ! [$tbl hasrowattrib $row pathName]} {
	        set opt [Audit::formatString [$tbl cellcget $row,0 -text]]
		set attr [$tbl parentkey $row]
		 
		if {[string compare $attr "root" ] == 0 } { 
                      set dir1 [$tbl cellattrib $row,Status Fname]
		} else {
                      set dir1 [$tbl rowattrib $attr pathName]
                }

		set fpath1 ${dir1}/$opt
                
                catch {set ftype [exec file $fpath1]}

                # -- check if a link
		if {[regexp "symbolic link" $ftype]} {
			set base   [file dirname $fpath1]
			set lfile  [file readlink $fpath1]
			set ftype  [exec file $base/$lfile]
		}

		if {[regexp  "ASCII|Korn|HTML|text|empty" "$ftype"]} {
		      # -- We should check existence of file  before calling text_viewer
                      eval exec "$Preferences::text_viewer $Preferences::text_viewer_args" $fpath1 &
                } else {
		        Dialogs::show_msgdlg $Dialogs::Dlg_NoAsciiFile ok warning "" .audit
                }
        }
}

#------------------------------------------------------------------------------
# putContents
#
# Outputs the contents of the directory dir into the tablelist widget tbl, as
# child items of the one identified by nodeIdx.
#------------------------------------------------------------------------------
proc Audit::putContents {dir tbl nodeIdx} {
   
    
    if {[string compare $dir "no-selection"] == 0 || [string compare $dir ""] == 0} {
               return ""
    }

    # -- Discard dirs in cas of exphome
    if {[string equal [file tail $dir] "."] == 0} {
	  set ExpHome "yes" 
    } else {
	  set ExpHome "no" 
    }

    #
    # The following check is necessary because this procedure
    # is also invoked by the "Refresh" and "Parent" buttons
    #


    if {[string compare $dir ""] != 0 && (![file isdirectory $dir] || ![file readable $dir])} {
	bell
	if {[string compare $nodeIdx "root"] == 0} {
	    set choice [tk_messageBox -title "Error" -icon warning -message \
			"There is no Equivalent directory \"[file nativename $dir]\" on the Other Experiment" \
			-type ok -parent $Audit::AuditWin]

	} else {
	    return ""
	}
    }

    if {[string compare $nodeIdx "root"] == 0} {
	     $tbl delete 0 end
	     set row 0
    } else {
	     set row [expr {$nodeIdx + 1}]
    }

    #
    # Build a list from the data of the subdirectories and
    # files of the directory dir.  Prepend a "D" or "F" to
    # each entry's name and modification date & time, for
    # sorting purposes (it will be removed by formatString).
    #
    set itemList {}
    if {[string compare $dir ""] == 0} {
	foreach volume [file volumes] {
	    lappend itemList [list D[file nativename $volume] -1 D $volume]
	}
    } else {
        # -- This will gather link pointing to directories
	# -- we need to discard directories which are pointed to by a link
	set matchLink {}
	foreach entry [glob -nocomplain -types {l f} -directory $dir *] {
                 set ftype [file type $entry]
		 
		 if {[string compare $ftype "link"] == 0} {
		         set PointTo [file readlink $entry]
			 regsub -all {\.\/} $PointTo "" PointTo
			 lappend matchLink $PointTo
		 }
	}


	foreach entry [glob -nocomplain -types {d f} -directory $dir *] {
             
	    if {[lsearch $matchLink [file tail $entry]] >= 0 } {
	                continue
            }

	    if {[catch {file mtime $entry} modTime] != 0} {
		        continue
	    }


	    if {[file isdirectory $entry] } {
	        if {[string equal $ExpHome "yes"] != 0 } {
		        lappend itemList [list D[file tail $entry] \
		            ""\
		            D[clock format $modTime -format "%Y-%m-%d %H:%M"] $entry]
                }
	    } else {
                # See if file has changed
	        regsub -all "$Audit::_selected1" $entry "$Audit::_selected2" kiki
		
		# -- Take other suite 
		if { [string compare $kiki $entry] == 0 } {
	            regsub -all "$Audit::_selected2" $entry "$Audit::_selected1" kiki
		}


	        if { [file exists $kiki] && [file readable $kiki]} {
                        # -- corresponding Exp1|Exp2 file is here $kiki
			# -- use only diff even for binary files??
			
			set rc [catch {exec diff -q $kiki $entry } output]
			if {$rc != 0} {
		               lappend itemList [list F[file tail $entry] \
		                   "FChanged"\
		                   F[clock format $modTime -format "%Y-%m-%d %H:%M"] "" $entry]
			} else {
			       if {[regexp {Show All}  $Audit::_filter]} {
		                      lappend itemList [list F[file tail $entry] \
		                          "FIdentical"\
		                          F[clock format $modTime -format "%Y-%m-%d %H:%M"] "" $entry]
			       }
			}
		} else {
		        lappend itemList [list F[file tail $entry] \
		        "FOnly Here"\
		        F[clock format $modTime -format "%Y-%m-%d %H:%M"] "" $entry]
		}
		

	    }
	}
    }

    #
    # Sort the above list and insert it into the tablelist widget
    # tbl as list of children of the row identified by nodeIdx
    #
    set itemList [$tbl applysorting $itemList]
    $tbl insertchildlist $nodeIdx end $itemList

    #
    # Insert an image into the first cell of each newly inserted row
    #
    foreach item $itemList {
	#set name [lindex $item end]
	set name [lindex $item 3]
	if {[string compare $name ""] == 0} {			;# file
	    $tbl cellconfigure $row,0 -image $XPManager::img_fileImg

            # -- have to do a check here for new file ,changed files ....
	    if {[string compare [lindex $item 1] "FChanged" ] == 0 } {
	                 $tbl cellconfigure $row,Status -bg #ff0e0e
	                 $tbl cellattrib $row,Status Fname [file dirname [lindex $item end]]
            } elseif {[string compare [lindex $item 1] "FIdentical" ] == 0 } {
	                 $tbl cellconfigure $row,Status -bg green
	                 $tbl cellattrib $row,Status Fname [file dirname [lindex $item end]]
	    } else {
	                 $tbl cellconfigure $row,Status -bg yellow
	                 $tbl cellattrib $row,Status Fname [file dirname [lindex $item end]]
	    }
	} else {						;# directory
	    $tbl cellconfigure $row,0 -image $XPManager::img_clsdFolderImg
	    $tbl rowattrib $row pathName $name

	    #
	    # Mark the row as collapsed if the directory is non-empty
	    #
	    if {[file readable $name] && [llength [glob -nocomplain -types {d f} -directory $name *]] != 0} {
		$tbl collapse $row
	    }
	}

	incr row
    }

    # -- Determine which side (Exp)
    if {[regexp {modules} $tbl]} {
	       set kiko modules
    } elseif {[regexp {resources} $tbl]} {
	       set kiko resources
    } elseif {[regexp {bin} $tbl]} {
	       set kiko bin
    } elseif {[regexp {constants} $tbl]} {
	       set kiko constants
    } elseif {[regexp {exphome} $tbl]} {
               set kiko exphome
    }

    # -- Crap shouldn't use this ...
    if {[regexp {f0} $tbl]} {
               set bframe "f0.frame.lf.f.b"
	       set table 0
    } else {
               set bframe "f1.frame.lf.f.b"
	       set table 1
    }


    if {[string compare $nodeIdx "root"] == 0} {
	
        # -- Configure the "Refresh" and "Parent" buttons
	eval \$Audit::RedoBut_$kiko configure -command \[list Audit::AuditComponent $Audit::AuditWin "$kiko" \]

        set pdir [file dirname $dir]

	if {[string compare $dir ""] == 0 || \
	    [string compare $pdir $Audit::_selected1] == 0 || \
	    [string compare $pdir $Audit::_selected2] == 0 || \
	    [string compare $pdir "$Audit::_selected1/hub"] == 0 || \
	    [string compare $pdir "$Audit::_selected2/hub"] == 0 } {
	    eval \$Audit::UpBut_$kiko${table} configure -state disabled
	} else {
	    eval \$Audit::UpBut_$kiko${table} configure -state normal

	    if {[string compare $pdir $dir] == 0 } {
	           # -- This should never happens
		   #eval \$Audit::UpBut_$kiko${table} configure -command \[list Audit::SyncUp "" "$tbl"  root\]
		   puts "in empty"
	    } else {
		   eval \$Audit::UpBut_$kiko${table} configure -command \[list Audit::SyncUp "$pdir" "$tbl"  root\]
	    }
	}


    }

    # -- Update Entry widget showing the current Directory
    # -- the dir is too long we will show starting from exp.
    if {[regexp $Audit::_selected1 $dir]} {
                 regsub -all "$Audit::_selected1" $dir "" toshow
    } else {
                 regsub -all "$Audit::_selected2" $dir "" toshow
    }

    # -- This has toshow the path when navigating and only the root at first time!
    # -- Remove leading /
    set toshowdir [string trimleft $toshow "/"]
    set Audit::CurDir_${kiko}${table}  $toshowdir


}

# -- This proc will try to synchronize cd'ing to parent directory if 
# -- hierarchy is the same for the 2 experiments

proc Audit::SyncUp {p tbl node} {

      # -- Test to see which Exp. 
      if {[regexp {f0} $tbl]} {
                 regsub -all {f0} $tbl {f1} tbl2 
      } else {
                 regsub -all {f1} $tbl {f0} tbl2 
      }

      # -- pick up the other Exp
      if {[regexp $Audit::_selected1 $p]} {
                 regsub -all "$Audit::_selected1" $p "$Audit::_selected2" p2
      } else {
                 regsub -all "$Audit::_selected2" $p "$Audit::_selected1" p2
      }

      # -- puts content of first
      Audit::putContents $p $tbl $node

      # -- We have to check existence of p2 before outputing contents
      if {[file isdirectory $p2]} {
                  Audit::putContents $p2 $tbl2 $node
      }

}


proc Audit::RedoAudit {panel} {
             puts "Redoing Audit for ... $panel"
}


proc Audit::SyncPutContents {p tbl node} {

     if {[regexp {\.f0\.} $tbl]} {
            regsub -all {f0} $tbl {f1} tbl2
     } else {
            regsub -all {f1} $tbl {f0} tbl2
     }
	        
     regsub -all "$Audit::_selected1" $p "$Audit::_selected2" kiki

     if { [string compare $kiki $p] == 0 } {
                # take other suite 
                regsub -all "$Audit::_selected2" $p "$Audit::_selected1" kiki
     }
    
     # -- check if dir exist on other Exp
     if {[file isdirectory $kiki]} {
                 Audit::putContents $kiki $tbl2 $node
    }
}

proc Audit::Parent  {dir tbl} {

            set row [$tbl curselection]
            if {[$tbl hasrowattrib $row pathName]} {		;# directory item
	           set dir [$tbl rowattrib $row pathName]
	           set p [file dirname $dir]
		   puts "dir=$dir p=$p"
	           if {[file isdirectory $dir] && [file readable $dir]} {
	                if {[string compare $p $dir] == 0} {
		            Audit::putContents "" $tbl root 
	                } else {
		            Audit::putContents $p $tbl root
	                }
		   } else {
		        puts "ne sais pas"
		   }
            } else {
	        puts "file item"
	    }



}


#------------------------------------------------------------------------------
# formatString
#
# Returns the substring obtained from the specified value by removing its first
# character.
#------------------------------------------------------------------------------
proc Audit::formatString val {
    return [string range $val 1 end]
}

#------------------------------------------------------------------------------
# formatSize
#
# Returns an empty string if the specified value is negative and the value
# itself in user-friendly format otherwise.
#------------------------------------------------------------------------------
proc Audit::formatSize val {
    if {$val < 0} {
	return ""
    } elseif {$val < 1024} {
	return "$val bytes"
    } elseif {$val < 1048576} {
	return [format "%.1f KB" [expr {$val / 1024.0}]]
    } elseif {$val < 1073741824} {
	return [format "%.1f MB" [expr {$val / 1048576.0}]]
    } else {
	return [format "%.1f GB" [expr {$val / 1073741824.0}]]
    }
}

#------------------------------------------------------------------------------
# expandCmd
#
# Outputs the contents of the directory whose leaf name is displayed in the
# first cell of the specified row of the tablelist widget tbl, as child items
# of the one identified by row, and updates the image displayed in that cell.
#------------------------------------------------------------------------------
proc Audit::expandCmd {tbl row} {
    
    if {[$tbl childcount $row] == 0} {
	set dir [$tbl rowattrib $row pathName]
	Audit::putContents $dir $tbl $row 
    }

    if {[$tbl childcount $row] != 0} {
	$tbl cellconfigure $row,0 -image $XPManager::img_openFolderImg
    }
}

#------------------------------------------------------------------------------
# collapseCmd
#
# Updates the image displayed in the first cell of the specified row of the
# tablelist widget tbl.
#------------------------------------------------------------------------------
proc Audit::collapseCmd {tbl row} {
    $tbl cellconfigure $row,0 -image $XPManager::img_clsdFolderImg
}

#------------------------------------------------------------------------------
# putContentsOfSelFolder
#
# Outputs the contents of the selected folder into the tablelist widget tbl.
#------------------------------------------------------------------------------
proc Audit::putContentsOfSelFolder tbl {
   
    set row [$tbl curselection]
    if {[$tbl hasrowattrib $row pathName]} {		;# directory item
	set dir [$tbl rowattrib $row pathName]
	if {[file isdirectory $dir] && [file readable $dir]} {
	    if {[llength [glob -nocomplain -types {d f} -directory $dir *]] == 0} {
		bell
	    } else {
		Audit::putContents $dir $tbl root
		# -- Synchronize (output) other Exp
		Audit::SyncPutContents $dir $tbl root 
	    }
	} else {
	    bell
	    tk_messageBox -title "Error" -icon error -message "Cannot read directory \"[file nativename $dir]\""
	    return ""
	}
    } else {						;# file item
	bell
    }
}

#------------------------------------------------------------------------------
# postPopupMenu
#
# Posts the pop-up menu .menu at the given screen position.  Before posting
# the menu, the procedure enables/disables its only entry, depending upon
# whether the selected item represents a readable directory or not.
#
# - Dont Display menu when file exist in one Experiment and not the other
#------------------------------------------------------------------------------
proc Audit::postPopupMenu {rootX rootY TabFrame kk} {

    set row [$TabFrame curselection]
    set menu .menu$kk
    if { ! [$TabFrame hasrowattrib $row pathName]} {	
	set opt [Audit::formatString [$TabFrame cellcget $row,1 -text]]
        if {   [string compare $opt "Changed"] == 0 \
	    || [string compare $opt "Identical"] == 0} {	
	              $menu entryconfigure 0 -state normal
	              $menu entryconfigure 1 -state disabled
                      tk_popup $menu $rootX $rootY
        } else {
	              $menu entryconfigure 1 -state normal
	              $menu entryconfigure 0 -state disabled
                      tk_popup $menu $rootX $rootY
	}
	             
    }

}

#------------------------------------------------------------------------------
# refreshView
#
# Redisplays the contents of the directory dir in the tablelist widget tbl and
# restores the expanded states of the folders as well as the vertical view.
#------------------------------------------------------------------------------
proc Audit::refreshView {dir tbl} {

    #
    # Save the vertical view and get the path names
    # of the folders displayed in the expanded rows
    #
    set yView [$tbl yview]
    foreach key [$tbl expandedkeys] {
	set pathName [$tbl rowattrib $key pathName]
	set expandedFolders($pathName) 1
    }

    #
    # Redisplay the directory's (possibly changed) contents and restore
    # the expanded states of the folders, along with the vertical view
    #
    Audit::putContents $dir $tbl root
    restoreExpandedStates $tbl root expandedFolders
    $tbl yview moveto [lindex $yView 0]
}

#------------------------------------------------------------------------------
# restoreExpandedStates
#
# Expands those children of the parent identified by nodeIdx that display
# folders whose path names are the names of the elements of the array specified
# by the last argument.
#------------------------------------------------------------------------------
proc Audit::restoreExpandedStates {tbl nodeIdx expandedFoldersName} {
    upvar $expandedFoldersName expandedFolders

    foreach key [$tbl childkeys $nodeIdx] {
	set pathName [$tbl rowattrib $key pathName]
	if {[string compare $pathName ""] != 0 &&
	    [info exists expandedFolders($pathName)]} {
	    $tbl expand $key -partly
	    restoreExpandedStates $tbl $key expandedFolders
	}
    }
}


#------------------------------------------------------------------------------
# ResolveDoubleClick
#
# This routine will do these actions depending on the clicked object:
# if the object is a directory it will show the content
# if the object is a file it will show diff (btw the 2 experiment) or
#    juste the content of the file if it is not present in both exp's.
#------------------------------------------------------------------------------
proc Audit::ResolveDoubleClick tbl {
   
    set row [$tbl curselection]
    if {[$tbl hasrowattrib $row pathName]} {		;# directory item
           Audit::putContentsOfSelFolder $tbl
    } else {
	set opt [Audit::formatString [$tbl cellcget $row,1 -text]]
        if {   [string compare $opt "Changed"] == 0 || [string compare $opt "Identical"] == 0} {
	          Audit::ViewDiff $tbl
        } else {
	          Audit::ViewFile $tbl
	}
    }

}

#------------------------------------------------------------------------------
# ShowHelp
#------------------------------------------------------------------------------

proc Audit::ShowHelp { } {
        Dialogs::show_msgdlg "Comming Soon" ok info "" $Audit::AuditWin
}
