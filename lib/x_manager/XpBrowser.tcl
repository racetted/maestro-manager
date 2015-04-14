global _XpBrSelected
global _ExpDate
global _ExpCatchup

global array TreesWidgets

namespace eval XpBrowser {
            variable confNode ""
            variable Bmflow    
            variable Bxflow    
            variable Bimport   
            variable Baudit    
            variable Bexptime  
            variable Boverview 
            variable BSetExpdate 
            variable BSetCatchup 
}

# -- tk_pop for Experiments
proc XpBrowser::_getXp {frm tree node} {
      global _XpBrSelected
      global _ExpDate
      global _ExpCatchup
      variable confNode

      # -- Note : Only the Experiments have data field
      set data [$tree itemcget $node -data]
      if { $data == "root" } {
	       eval $XpBrowser::confNode
	       set _XpBrSelected ""
	       foreach but {Bmflow Bxflow Bimport Baudit Bexptime Boverview} {
	          eval \$XpBrowser::$but configure -state disabled
	       }
	       # -- disable expdate
	       $XpBrowser::Eexpdate    configure -state disabled
	       $XpBrowser::BSetExpdate configure -state disabled
	       # -- disable catchup
	       $XpBrowser::Eexpcatch   configure -state disabled
	       $XpBrowser::BSetCatchup configure -state disabled

               # -- Empty Entries (date & catchup)
	       set _ExpDate ""
	       set _ExpCatchup ""

	       return 
      }

      if { "$data" != "" } {
               set _XpBrSelected [file normalize [string trimright [XTree::getPath $tree $node] "/"]]
	       eval $XpBrowser::confNode
	       $tree itemconfigure $node -fill red
	       set XpBrowser::confNode "$tree itemconfigure $node -fill black"
               XpBrowser::ActivateExpParams $_XpBrSelected
      }

}


#---------------------------------------------------------
# Having a valid Experiments show Experiment 
# date and  catchup 
#---------------------------------------------------------
proc XpBrowser::ActivateExpParams { XpSelected } {
      

      if {[file writable $XpSelected/]} {
                $XpBrowser::Eexpdate    configure -state normal
	        $XpBrowser::BSetExpdate configure -state normal
       } else {
                $XpBrowser::Eexpdate    configure -state disabled
	        $XpBrowser::BSetExpdate configure -state disabled
       }

       # -- Show ExpDate
       set kris [catch {file type $XpSelected/EntryModule} ftype]
       if {$kris == 0 && $ftype eq "link"} {
                       # before chech if Expdate is there and not empty
		       if {[file exist $XpSelected/ExpDate] && [file size $XpSelected/ExpDate] != 0} {
                              set dte [exec cat $XpSelected/ExpDate | egrep "^(1|2)" | cut -c1-10] 
		              # have to validate
		              set ::_ExpDate $dte
                       } else {
		              set ::_ExpDate ""
		       }
       } else {
		       set ::_ExpDate ""
       }

       # -- [En|dis]able Set button
       if {[file writable $XpSelected/]} {
                $XpBrowser::Eexpcatch   configure -state normal
	        $XpBrowser::BSetCatchup configure -state normal
       } else {
                $XpBrowser::Eexpcatch   configure -state disabled
	        $XpBrowser::BSetCatchup configure -state disabled
       }

       # -- Show Catchup
       if {$kris == 0 && $ftype eq "link" && [file exist $XpSelected/catchup.xml]} {
	               # -- need to parse xml
		       set cth [exec  cat $XpSelected/catchup.xml  | grep CATCHUP | cut -d\= -f2 ]
		       regsub -all {[\"/>]} $cth {} cth
		       # have to validate
		       set _ExpCatchup $cth
       } else {
		       set _ExpCatchup ""
		       #$XpBrowser::Eexpcatch configure -state disabled
		       #$XpBrowser::BSetCatchup configure -state disabled
       }
	       
       foreach but {Bmflow Bxflow Bimport Baudit} {
          eval \$XpBrowser::$but configure -state normal
       }

}

proc XpBrowser::create { frm } {
        
      global _XpBrSelected 
      global TreesWidgets
      global MUSER
      global ArrayTabsDepot

      variable notebook

      variable Bmflow    
      variable Bxflow    
      variable Bimport   
      variable Baudit    
      variable Bexptime  
      variable Boverview 
      variable BSetExpdate 
      variable BSetCatchup 
      variable Eexpdate 
      variable Eexpcatch 
      variable XpBfrm 
      variable expsel 


      set ::_XpBrSelected ""

      set XpBfrm [frame $frm.frame  -border 2 -relief flat]
      label $XpBfrm.lab -text "" -font "12"

      # -- get a frame for Experience attributes
      set tsel [TitleFrame $XpBfrm.texp1 -text $Dialogs::Gui_selectedExp -font "ansi 10"]
      set subf1 [$tsel getframe]


      label $subf1.lname -text $Dialogs::Gui_ExpName -font "ansi 10"
      set expsel [Entry $subf1.entrysel  -textvariable ::_XpBrSelected \
                -width 70\
		-editable true\
		-bg #FFFFFF \
		-validate key\
                -validatecommand  { XpBrowser::CheckEntry %P }\
		-helptext "Selected Experiment"]

       Button $subf1.bbrowse -text "Experiment Selector" \
	                     -image $XPManager::img_XpSel \
			     -command {
			                set xp [tk_chooseDirectory -initialdir $env(HOME)/ -title "Select an Experiment" -mustexist true -parent $XpBrowser::XpBfrm]
				        if { "$xp" ne "" } {
					      XpBrowser::validateAndShowExp $xp
					}
				      }

      # -- Need an other frame to pack expdate, catchup and 2 buttons
      set frmother [frame $subf1.oth -border 2 -relief flat]

      label $subf1.ldate -text  $Dialogs::Gui_ExDatep -font "ansi 10"
      set Eexpdate [Entry $frmother.entrydate  -textvariable ::_ExpDate \
                -width 10\
		-bg #FFFFFF \
                -command  {} \
		-helptext "Experiment Date"]

      set BSetExpdate [button $frmother.bsdate       -text "Set" -command {XpBrowser::SetExpdate $::_XpBrSelected $::_ExpDate}]

      label $frmother.lcatch -text $Dialogs::Gui_ExpCatchup -font "ansi 10"
      set Eexpcatch [Entry $frmother.entrycatch  -textvariable ::_ExpCatchup \
                -width 2\
		-bg #FFFFFF \
                -command  {} \
		-helptext "Experiment Catchup"]
      
      set BSetCatchup [button $frmother.bscatch       -text "Set" -command {XpBrowser::SetCatchup $::_XpBrSelected $::_ExpCatchup}]


      # -- get frame for Control buttons
      set XpBfrmCb [frame $XpBfrm.cbutt  -border 2 -relief flat]
      set tcbut [TitleFrame $XpBfrmCb.t -text $Dialogs::Gui_ControlExp -font "ansi 10"]
      set subfcb [$tcbut getframe]

      set Bmflow     [button $subfcb.mflow  -text $Dialogs::XpB_flowmgr] 
      $Bmflow configure -command [list XpBrowser::ExpSelected $Bmflow]

      set Bxflow     [button $subfcb.xflow       -text $Dialogs::XpB_xflow     -command {\
                      catch {[exec ${SEQ_MANAGER_BIN}/Exec_MaestroXFlow.ksh $::_XpBrSelected &]}}]

      set Bimport    [button $subfcb.import      -text $Dialogs::XpB_import    -command {\
                      Import::ImportExp $::_XpBrSelected}]

      set Baudit     [button $subfcb.audit       -text $Dialogs::XpB_audit     -command {\
                      Audit::AuditExp $::_XpBrSelected}]

      set Bexptime   [button $subfcb.exptime     -text $Dialogs::XpB_exptime   -command {\
                      Dialogs::show_msgdlg "Future Use"  ok info "" .}]
      set Boverview  [button $subfcb.overview    -text $Dialogs::XpB_overv     -command {\
                      Dialogs::show_msgdlg "Future Use"  ok info "" .}]


      # -- create notebook
      set notebook [NoteBook $XpBfrm.nb]

      # -- Set Default tabs to show to any user  
      set ListTabToShow {}
      if { ! [regexp "afsiops|afsisio|afsipar" $MUSER] } {
	      #set ListTabToShow {*}$Preferences::ListUsrTabs
	      set ListTabToShow $Preferences::ListUsrTabs
              lappend ListTabToShow {*}[list "$Dialogs::XpB_OpExp" "$Dialogs::XpB_PaExp" "$Dialogs::XpB_PoExp"]
      } else {
              set ListTabToShow [list "$Dialogs::XpB_OpExp" "$Dialogs::XpB_PaExp" "$Dialogs::XpB_PoExp"]
      }

      # -- set a temp list
      set ltmp lappend
      set i 1
      foreach panel $ListTabToShow {
                set panel [string trim $panel " "]
                $notebook  insert $i $panel -text "$panel"       
                set pane [$notebook getframe $panel]
                
                if {[info exists ArrayTabsDepot($panel)]} {
                          set base [split $ArrayTabsDepot($panel) ":"]
		} else {
		          puts "warning ... Tab: $panel with no Experiments"
			  set base ""
                }

	        set pxt [XTree::create ${pane} $notebook]
                
		$notebook itemconfigure $panel \
		    -createcmd "XTree::init $pxt {*}$base" \
		    -raisecmd {
		     # on windows you can get 100x100+-200+200 [PT]
		     regexp {[0-9]+x[0-9]+([+-]{1,2}[0-9]+)([+-]{1,2}[0-9]+)} \
		      .[wm geom .] global_foo global_w global_h } \
		    -leavecmd {
		        return 1
		    }

                # -- Bind doubleclick tree elem with 
                TreeUtil::MpopNode   $pane $pxt 
		TreeUtil::MpopRNode  $pane $pxt
		TreeUtil::MpopXPNode $pane $pxt
		$pxt bindText  <Double-Button-1>  "XpBrowser::_getXp $pane $pxt [$pxt selection get]" 
              
	        # -- double click on tab should Refresh the exp's 
		# -- pane is given automatically (appended to args ) to the proc
	        $notebook bindtabs <Double-Button-1>  TreeUtil::Refresh_Exp 

                # -- Keep a trace
		set TreesWidgets($panel)  $pxt
                #TreeUtil::TLcreate $pane $ToolB $panel $pxt
	        incr i
                
		# -- geomtry propagate
                $notebook compute_size
      }

      # -- Pack everything
      pack $XpBfrm.lab -fill both

      pack $tsel -anchor w -fill x -padx 4 -pady 4 
      grid $subf1.lname   -row 0 -column 0 -padx 4 -pady 1 -sticky w 
      grid $expsel        -row 0 -column 1 -padx 2 -pady 1 -sticky w
      grid $subf1.bbrowse -row 0 -column 2 -padx 4 -sticky w
    
      grid $subf1.ldate   -row 1 -column 0 -padx 4 -pady 1 -sticky w 

      pack $Eexpdate        -side left 
      pack $BSetExpdate     -side left -padx 4
      pack $frmother.lcatch -side left -padx 4
      pack $Eexpcatch       -side left -padx 4
      pack $BSetCatchup     -side left -padx 4

      grid $frmother -row 1 -column 1 -pady 1 -sticky w

      pack $tcbut -anchor w -fill x -padx 4 -pady 4
      pack $Bmflow    -side left
      pack $Bxflow    -side left
      pack $Bimport   -side left
      pack $Baudit    -side left
      pack $Bexptime  -side left
      pack $Boverview -side left
      pack $XpBfrmCb  -fill x

      pack $notebook -fill both -expand yes -padx 4 -pady 4
      pack $XpBfrm -fill both -expand yes

      $notebook raise [$notebook page 0]
      
      switch $MUSER {
              "(afsiops|afsisio)"  {
                         $notebook raise [$notebook page 0]
			 }
              "afsipar"  {
                         $notebook raise [$notebook page 1]
			 }
     }

     # -- For now disable Pre-Op. Figure out if there is any pre-op 
     $notebook itemconfigure $Dialogs::XpB_PoExp -state disabled

     # -- [En/Dis]able date & Catchup Enries
     if {[string compare $::_XpBrSelected ""] == 0 } {
            $frmother.bsdate configure -state disabled
	    $frmother.bscatch configure -state disabled
	    foreach but {Bmflow Bxflow Bimport Baudit Bexptime Boverview} {
	        eval \$$but configure -state disabled
            }
     } else {
            $frmother.bsdate configure -state normal
	    $frmother.bscatch configure -state normal
	    foreach but {Bmflow Bxflow Bimport Baudit Bexptime Boverview} {
	        eval \$$but configure -state normal
            }
     }
    
     # - disable Expdte & Catchup at entry
     $Eexpdate    configure -state disabled
     $BSetExpdate configure -state disabled
     $Eexpcatch   configure -state disabled
     $BSetCatchup configure -state disabled

     # - bind Entry (exp name ) to return key
     bind $expsel <Key-Return> {
              XpBrowser::validateAndShowExp [ $XpBrowser::expsel get ]
     }
}
#---------------------------------
# validate string given by entry
#---------------------------------
proc XpBrowser::validateAndShowExp { sel_xp } {
      set sel_xp [file nativename $sel_xp]
      set kris [catch {file type $sel_xp/EntryModule} ftype]
      if { $kris != 0 || $ftype ne "link"  } {
                 Dialogs::show_msgdlg $Dialogs::Dlg_ProvideExpPath ok warning "" $XpBrowser::XpBfrm
		 # -- Disable button 
                 set ::_XpBrSelected ""
	         foreach but {Bmflow Bxflow Bimport Baudit} {
	              eval \$XpBrowser::$but configure -state disabled
	         }
         } else {
                 set ::_XpBrSelected $sel_xp
		 
	         #foreach but {Bmflow Bxflow Bimport Baudit} {
	         #     eval \$XpBrowser::$but configure -state normal
	         #}
		 XpBrowser::ActivateExpParams $sel_xp
         }
}

proc XpBrowser::CheckEntry { str } {
     
      # -- rm blank
       regsub -all " +" $str "" str

      if { "$str" == "" } {
	         foreach but {Bmflow Bxflow Bimport Baudit} {
	              eval \$XpBrowser::$but configure -state disabled
                 }
      }
      return true
}

proc XpBrowser::SetExpdate {exp value} {
      # -- examine format, need 10 chars
      if { ! [regexp {^[0-9]+$} $value] } {
             Dialogs::show_msgdlg $Dialogs::Dlg_ExpDateInvalid  ok warning "" .
             return
      }

      if {[regexp {[0-9]{14}$} $value]} {
          catch {[exec echo -n "${value}"     > $exp/ExpDate]}
      } else {
          catch {[exec echo -n "${value}0000" > $exp/ExpDate]}
     }
}

proc XpBrowser::SetCatchup {exp value} {
      
      if { ! [regexp {^[0-9]+$} $value] } {
             Dialogs::show_msgdlg $Dialogs::Dlg_CatchupInvalid  ok warning "" .
             return
      }
      
      if {[regexp "^\[0-9\]\{1,2\}$" $value]} {
               catch {[exec rm -f $::env(TMPDIR)/catchup.xml]}
               set fid [open "$::env(TMPDIR)/catchup.xml" w]
               puts  $fid "<?xml version=\"1.0\"?>"
               puts  $fid "<CATCHUP value=\"$value\"/>"
               close $fid
               catch {[exec cp $::env(TMPDIR)/catchup.xml  $exp/catchup.xml]}
      } else {
               Dialogs::show_msgdlg $Dialogs::Dlg_NumCarCatchup  ok warning "" .
               return
      }
}


proc XpBrowser::ExpSelected { source_w } {
       global _XpBrSelected
       ExpModTreeControl_init ${source_w} $::_XpBrSelected
}

proc XpBrowser::GetExpSelected {} {
   global _XpBrSelected
   return ${_XpBrSelected}
}

proc XpBrowser::_clearXp {} {
   global _XpBrSelected
   global _ExpDate
   global _ExpCatchup
   variable confNode

   set _XpBrSelected "";
   set _ExpDate "";
   set _ExpCatchup "";
   set confNode "";
}
