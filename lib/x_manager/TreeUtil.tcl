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


 package require log
 
 namespace eval TreeUtil {
            variable _PopUpSelection = "no-selection"
            variable frmt
            variable data
 }


#---------------------------------------------------
# -- tk_pop for Experiments & non Experiment nodes
#
#
#---------------------------------------------------
proc TreeUtil::_treepopup {frm tree node} {
   variable data

  # -- Note : Only the Experiments have data field
  set data [$tree itemcget $node -data] 
 

  # -- Do not show Popup on Root Element, But show Refreash & Expand All | colapse ALL & create new Exp
  if { $data == "root" } {
        # -- Enable/Disable Creating of a new xp at this Level
	if {[TreeUtil::WritableNode $tree $node] == 0 } {
                $frm.rpopup entryconfigure 3 -state normal
        } else {
                $frm.rpopup entryconfigure 3 -state disabled
	}
	
	tk_popup $frm.rpopup [winfo pointerx [focus]] [winfo pointery [focus]]
        return
  }

  if {[string compare "$data" ""] == 0 } {
        set TreeUtil::_PopUpSelection [XTree::getPath $tree $node]
	
        # -- Enable/Disable View Git & Downlad Git if no .git at this Level
        if {[TreeUtil::CheckGit $tree $node] == 0 } {
	       #$frm.stpopup  entryconfigure 5 -state normal
	       #$frm.stpopup  entryconfigure 6 -state normal
	       # -- Disable for now
	       $frm.stpopup  entryconfigure 5 -state disabled
	       $frm.stpopup  entryconfigure 6 -state disabled
        } else {
	       $frm.stpopup  entryconfigure 5 -state disabled 
	       $frm.stpopup  entryconfigure 6 -state disabled 
	}
 
        # -- Enable/Disable Creating of a new xp at this Level
	if {[TreeUtil::WritableNode $tree $node] == 0 } {
	       $frm.stpopup  entryconfigure 4 -state normal
	} else {
	       $frm.stpopup  entryconfigure 4 -state disabled 
	}

        tk_popup $frm.stpopup [winfo pointerx [focus]] [winfo pointery [focus]]
  } else {
        # -- This is an Xp node
	$frm.xpopup  entryconfigure 1 -state normal
	$frm.xpopup  entryconfigure 2 -state normal
        tk_popup $frm.xpopup [winfo pointerx [focus]] [winfo pointery [focus]]
  }
}

#---------------------------------------------------
#
#
#
#---------------------------------------------------
proc TreeUtil::_lblpopup { frm } {
        tk_popup $frm.lbpopup [winfo pointerx [focus]] [winfo pointery [focus]]
}

#---------------------------------------------------
# Pop Up menu for non experiments & root nodes
#
#
#---------------------------------------------------
proc TreeUtil::MpopNode {frm tree} {

    variable data

    # -- Create  menu, for non experiment Nodes  
    menu $frm.stpopup -tearoff 0
    $frm.stpopup add separator 

    $frm.stpopup add command -label {Expand Node Tree} -font TkTextFont  -command "TreeUtil::ExpandNode $tree"
    $frm.stpopup add command -label {Browse Node}  -font TkTextFont     -command "TreeUtil::BrowseNode $tree"

    $frm.stpopup add command  -label {Import Exps below} -font TkTextFont -command {
			                 Import::ImportExp $TreeUtil::_PopUpSelection 
			            }


    $frm.stpopup add command  -label {Create New Exp at this level} -font TkTextFont -command {NewExp::New_xp $TreeUtil::_PopUpSelection [$XpBrowser::notebook raise]}
    
    $frm.stpopup add command -label {View git}     -font TkTextFont  -command "TreeUtil::RunGit $frm $tree" 
    $frm.stpopup add command -label {Download git} -font TkTextFont -command "TreeUtil::DownloadGit $frm $tree" 
    $frm.stpopup add command -label {Quit}         -font TkTextFont -command {} 


    $tree bindText  <Button-3>  "TreeUtil::_treepopup $frm $tree [$tree selection get]"

}

#---------------------------------------------------
# Pop Up menu for Root Node
#
#
#---------------------------------------------------
# -- Root Node
proc TreeUtil::MpopRNode {frm tree} {
    variable data
    variable node
    # -- Create  menu, for Root Nodes  

    menu $frm.rpopup -tearoff 0
    $frm.rpopup add separator 
    $frm.rpopup add command -label {Expand Root Node}  -font TkTextFont            -command "TreeUtil::ExpandNode $tree"
    $frm.rpopup add command -label {Refresh Tree}      -font TkTextFont             -command "TreeUtil::Refresh_Exp $frm"
    $frm.rpopup add command -label {Create New Exp at this level} -font TkTextFont -command [list TreeUtil::NewXpRootLevel $tree [$XpBrowser::notebook raise]] 
    $frm.rpopup add command -label {Quit} -font TkTextFont -command {} 

    $tree bindText  <Button-3>  "TreeUtil::_treepopup $frm $tree [$tree selection get]"
}
#---------------------------------------------------
# Pop Up menu for Xp Nodes
#
#
#---------------------------------------------------
proc TreeUtil::MpopXPNode {frm tree} {
    variable data
    variable node
    
    # -- Create  menu, for Experiments Nodes  
    menu $frm.xpopup -tearoff 0
    $frm.xpopup add separator 
    $frm.xpopup add command -label {Exp Config}   -font TkTextFont -command "TreeUtil::EditExpConfig $tree"
    $frm.xpopup add command -label {Exp Resource} -font TkTextFont -command "TreeUtil::EditExpResources $tree"
    $frm.xpopup add command -label {Delete}       -font TkTextFont -command "TreeUtil::DeleteExp $tree"
    $frm.xpopup add command -label {Quit}         -font TkTextFont -command {} 

    $tree bindText  <Button-3>  "TreeUtil::_treepopup $frm $tree [$tree selection get]"
}
#---------------------------------------------------
# Edit Experiment config ie experiment.cfg
#---------------------------------------------------
proc TreeUtil::EditExpConfig { tree } {
     set node [$tree selection get]
     set data  [$tree itemcget $node -data]
   
     ::ModuleFlowView_goEditor $data/experiment.cfg
}

#---------------------------------------------------
# Edit Experiment resource file ie resources.def
#---------------------------------------------------
proc TreeUtil::EditExpResources { tree } {
     set node [$tree selection get]
     set data [$tree itemcget $node -data]
     
     ::ModuleFlowView_goEditor $data/resources/resources.def
}

#---------------------------------------------------
# Delete experiment from experiment browser
#---------------------------------------------------
proc TreeUtil::DeleteExp { tree } {
     set node [$tree selection get]
     set data  [$tree itemcget $node -data]
     set answer [tk_messageBox -message "$data will be removed from Maestro Manager and permanently deleted. Is it what you want?" -type yesno -icon question]
     # -- Delete exp from tree browser
     switch -- $answer {
        yes {
	   exec rm -rf $data; 
	   $tree delete $node
	   if { [XpBrowser::GetExpSelected] == ${data} } {
	      XpBrowser::_clearXp
	   }
	}
        no return
     }
}
#---------------------------------------------------
#
#
#
#---------------------------------------------------
# -- Create Exp at Root level
proc TreeUtil::NewXpRootLevel { tree nbk } {
    # -- get node
    set node [$tree selection get]
    NewExp::New_xp [XTree::getPath $tree $node] $nbk
}

#---------------------------------------------------
# NOT USED!
#
#
#---------------------------------------------------
proc TreeUtil::TLcreate { frm lbl panel tree } {

    # -- Create a menu for Tools 
    set menu   [menu $frm.lbpopup -tearoff 0]
    $menu add separator 
    $menu add command -label {Refresh Tree}       -font TkTextFont -command  "TreeUtil::Refresh_Exp $frm"
    $menu add command -label {Open Selected Node} -font TkTextFont -command  "TreeUtil::OpenNode $tree"
    $menu add command -label {List Selected Node} -font TkTextFont -command  "TreeUtil::BrowseNode $tree"
    $menu add command -label {Quit} -font TkTextFont  -command {}

    bind $lbl  <Button-3>  "TreeUtil::_lblpopup $frm"

}

#---------------------------------------------------
#
#
#
#---------------------------------------------------
proc TreeUtil::ExpandNode { tree } {

    set node [$tree selection get]
    set ilyla [ $tree exists "$node"]
   
    if { $ilyla != 0 } { 
           # -- Is this guy an Exp ?, we dont Explode an Exp
           set data [$tree itemcget $node -data]
    
           if {[string compare $data ""] == 0 || [string compare $data "root"] == 0 } {
                 $tree opentree $node
           }
    } else {
           Dialogs::show_msgdlg $Dialogs::Dlg_NodeNotExists  ok warning "" .
    }

}

#---------------------------------------------------
# Exec gitk on a root node
#
#
#---------------------------------------------------
proc TreeUtil::RunGit { frm tree } {

    global SEQ_MANAGER_BIN

    set node  [$tree selection get]
    set ilyla [ $tree exists "$node"]

    if { $ilyla != 0 } { 
           set data [$tree itemcget $node -data]
           if {[string compare $data "root"] != 0 } {
                   set path [XTree::getPath $tree $node]
	           catch {[exec ${SEQ_MANAGER_BIN}/Exec_Gitk.ksh $path/.git &]}
	   }
    }
}

#---------------------------------------------------
# Download git repository
#
#
#---------------------------------------------------
proc TreeUtil::DownloadGit { frm tree } { 
           Dialogs::show_msgdlg "Comming Soon"  ok info "" .
}

#---------------------------------------------------
# Check if a git repository exist
#
#
#---------------------------------------------------
proc TreeUtil::CheckGit { tree node } {
   
    set path ""
    set ilyla [$tree exists $node]

    if { $ilyla != 0 } {
                set path [XTree::getPath $tree $node]
                if {[string compare $path ""] != 0 && [file isdirectory $path/.git]} { 
                           return 0
		} else {
                           return 1
		}

    } else {
                   return 1
    }
}


#---------------------------------------------------
# check if a node is writable
#
#
#---------------------------------------------------
proc TreeUtil::WritableNode { tree node } {
    
    set path ""
    set ilyla [$tree exists $node]

    if { $ilyla != 0 } {
                set path [XTree::getPath $tree $node]
                if {[string compare $path ""] != 0 && [file writable $path]} { 
                          return 0
                } else {
                          return 1
		}
    } else {
                return 1
    }
}

#---------------------------------------------------
# not used !
#
#
#---------------------------------------------------
# -- this proc is not used
proc TreeUtil::BrowseNodeNotUsed { tree } {

    set node [$tree selection get]
    set ilyla [ $tree exists "$node"]
    
    if { $ilyla != 0 } { 
           # -- Is this guy an Exp ?, we dont Browse an Exp.
           set data [$tree itemcget $node -data]
           if { [string compare $data ""] == 0 } {
                   set path [XTree::getPath $tree $node]
	           TreeUtil::ShowNodeContent $path
           }
    } else {
           Dialogs::show_msgdlg $Dialogs::Dlg_NodeNotExists  ok warning "" .
    }

}

#---------------------------------------------------
#
#
#
#---------------------------------------------------
# -- Just launch dolphin on that Node
proc TreeUtil::BrowseNode { tree } {
    
    set node [$tree selection get]
    set ilyla [ $tree exists "$node"]
    
    if { $ilyla != 0 } { 
           # -- Is this guy an Exp ?, we dont Browse an Exp.
           set data [$tree itemcget $node -data]
           if { [string compare $data ""] == 0 } {
                   set path [XTree::getPath $tree $node]
                   if [catch {[exec /usr/bin/konqueror $path  &]}] {
	                    puts "Error spawning konqueror"
	           }
           }
    } else {
           Dialogs::show_msgdlg $Dialogs::Dlg_NodeNotExists  ok warning "" .
    }

}
#---------------------------------------------------
# Not used !
#
#
#---------------------------------------------------
# -- this proc is not used
proc TreeUtil::ShowNodeContent { nodepath } {
        
	set ListNode [toplevel .listnode]
	wm title $ListNode "Node Content"
	set frm [ frame $ListNode.frame -border 2 -relief flat]
	label $frm.lab -text "Content of Node : $nodepath " -font TkTextFont

        set vsb $frm.vsb
	set hsb $frm.hsb

        Preferences::Config_table

        tablelist::tablelist $frm.tbl \
	           -columns {0 "Name"          left\
	                     0 "Size"          center\
	                     0 "Md5"           center\
	                     0 "Date Modified" center} \
	        -expandcommand {} -collapsecommand {} \
	        -xscrollcommand [list $hsb set] -yscrollcommand [list $vsb set] \
	        -movablecolumns no -setgrid no -showseparators yes -height 5 -width 78

        if {[$frm.tbl cget -selectborderwidth] == 0} {
                    $frm.tbl configure -spacing 1
        }

        $frm.tbl columnconfigure 0 -formatcommand Audit::formatString -sortmode dictionary
        $frm.tbl columnconfigure 1 -formatcommand Audit::formatSize -sortmode integer 
        $frm.tbl columnconfigure 2 -formatcommand {}
        $frm.tbl columnconfigure 3 -formatcommand Audit::formatString

        scrollbar $vsb -orient vertical   -command [list $frm.tbl yview]
	scrollbar $hsb -orient horizontal -command [list $frm.tbl xview]

        # -- ok butt
	set bfrm [frame $ListNode.bframe -border 2 -relief flat]
	set Bok [button $bfrm.bok -text "Ok" -font TkTextFont -image $XPManager::img_Ok -command "destroy $ListNode"]

	pack $Bok -side bottom

        grid $frm.tbl -row 0 -rowspan 2 -column 0 -sticky news
	grid [$frm.tbl cornerpath] -row 0 -column 1 -sticky ew
	grid $vsb -row 1 -column 1 -sticky ns
	grid $hsb -row 2 -column 0 -sticky ew

	grid rowconfigure    $frm 1 -weight 1
	grid columnconfigure $frm 0 -weight 1

	pack $frm -side top -expand yes -fill both
	pack $bfrm 

	$frm.tbl sortbycolumn 0
	TreeUtil::ListContent $frm.tbl $nodepath root
}



#---------------------------------------------------
#
#
#
#---------------------------------------------------
proc TreeUtil::ListContent1 { tbl nodep nodeidx } {

      set itemList {}
    
      if {[string compare $nodeidx "root"] == 0} {
	      $tbl delete 0 end
	      set row 0
      } else {
              set row [expr {$nodeidx + 1}]
      }

      foreach entry [glob -nocomplain -types {f r} -directory $nodep * \.*] {
               
	       if {[catch {file mtime $entry} modTime] != 0} {
	                  continue
	       }

               lappend itemList [list F[file tail $entry] \
	       [file size $entry] \
	       [md5::md5 -hex -file $entry] \
	       F[clock format $modTime -format "%Y-%m-%d %H:%M"] "" $entry]
      }

      set itemList [$tbl applysorting $itemList]
      $tbl insertchildlist $nodeidx end $itemList

          foreach item $itemList {
	      $tbl cellconfigure $row,0 -image $XPManager::img_fileImg
	      incr row
          }
}


#---------------------------------------------------
#
#
#
#---------------------------------------------------
proc TreeUtil::Refresh_Exp { frmt } {
       
       # -- which notebook
       set nbk [$XpBrowser::notebook raise]

       # -- every things for now 
       set listxp [Preferences::GetTabListDepots $nbk "r"]

       if { [regexp $nbk TreeUtil::$frmt kk] } {
                 if {[string compare $listxp ""] != 0 } {
                       XTree::reinit $::TreesWidgets([string trim $nbk " "])  {*}$listxp
                 } else {
                        Dialogs::show_msgdlg $Dialogs::Dlg_TreeNotExists  ok warning "" .
                 }
       } elseif { [regexp $nbk TreeUtil::$frmt kk] } {
                  XTree::reinit $::TreesWidgets([string trim $nbk " "])       {*}$listxp
       } elseif { [regexp $nbk TreeUtil::$frmt kk] } {
                  XTree::reinit $::TreesWidgets([string trim $nbk " "])       {*}$listxp
       } elseif {  [regexp $nbk TreeUtil::$frmt kk] } {
                 if {[string compare $listexp ""] != 0 } {
                       XTree::reinit $::TreesWidgets([string trim $nbk " "])  {*}$listxp
                 } else {
                       Dialogs::show_msgdlg $Dialogs::Dlg_TreeNotExists  ok warning "" .
                 }
       }

}
#---------------------------------------------------
#  NOT USED
#
#
#---------------------------------------------------
proc TreeUtil::GetRootPath { path } {

    if {[info exists Preferences::UsrExpRepository] != 0 } {
            foreach upth $Preferences::UsrExpRepository {
                  if {[regexp $upth $path]} {
	                set upth [string trimright $upth "/"]
                        # -- Ok There is a match
			# -- check to remove exp name
			set kiki $path
			set kris [catch {file type $path/EntryModule} ftype]
			if {$kris == 0 && $ftype eq "link" } {
			         set kiki [file dirname $path]
                        }

			regsub -all $upth $kiki {} kiki

			# -- remove leading "/"
			set ki [string trimleft $kiki "/"]
			return $ki
		  }
	    }
    }

    # -- Op  path depot alws exists!
    foreach upth $XPManager::ExpOpsRepository {
            if {[regexp $upth $path]} {
	                set upth [string trimright $upth "/"]

                        # -- Ok There is a match
			# -- check to remove exp name
			set kiki $path
			set kris [catch {file type $path/EntryModule} ftype]
			if {$kris == 0 && $ftype eq "link" } {
			        set kiki [file dirname $path]
                        }
			regsub -all $upth $kiki {} kiki
			

			set ki [string trimleft $kiki "/"]
			return $ki
	    }
    }

    # -- Par path depot alws exists!
    foreach upth $XPManager::ExpParRepository {
            if {[regexp $upth $path]} {
	                set upth [string trimright $upth "/"]
			set kiki $path
			set kris [catch {file type $path/EntryModule} ftype]
			if {$kris == 0 && $ftype eq "link" } {
			        set kiki [file dirname $path]
                        }
                        
			regsub -all $upth $kiki {} kiki

			set ki [string trimleft $kiki "/"]
			return $ki
	    }
    }

    return ""
}
#---------------------------------------------------
#
#
#
#---------------------------------------------------
proc TreeUtil::FindExpInode {listExp} {
      # -- find inod of exp
      set i 0
      set dictInod [dict create]

      foreach lexp $listExp {
            file stat $lexp statinfo
	    set inode $statinfo(ino)
	    if {[info exists ExperimentInode($inode)] == 0 } {
	            dict set dictInod $i inode $inode
	            dict set dictInod $i experiment $lexp
		    incr i
	    } else {
	            puts "ERROR INODE EXISTE"
		    return $dictInod
	    }
      }

      return $dictInod
}
#---------------------------------------------------
# Check to see if a link is a dangling link
# not used now
#---------------------------------------------------
proc TreeUtil::IsBrokenLink { linkname } {
    return [expr { ! [file exists [file readlink $linkname]] }]
}

