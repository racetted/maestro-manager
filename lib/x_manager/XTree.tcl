set listExp [list]
global listExp 
interp recursionlimit {} 50

namespace eval XTree {
    variable count
    variable dblclick
    variable Exp_liste ""
}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::create { frm nb } {

    set title [TitleFrame $frm.t -text $Dialogs::XpB_xpbrowser]
    set sw    [ScrolledWindow [$title getframe].sw -relief sunken -borderwidth 1 ]

    #Tree .tree -xscrollcommand {.xsb set} -yscrollcommand {.ysb set}

    set tree  [Tree $sw.tree \
                   -relief flat -borderwidth 0 -width 15 -highlightthickness 0\
		   -redraw 0 -dropenabled 1 -dragenabled 1  -selectforeground blue \
		   -deltay 17\
                   -dragevent 3 \
		   -bg #FFFFFF \
                   -droptypes {
                       TREE_NODE    {copy {} move {} link {}}
                       LISTBOX_ITEM {copy {} move {} link {}}
                   } \
                   -opencmd   "XTree::moddir 1 $sw.tree" \
                   -closecmd  "XTree::moddir 0 $sw.tree"]
     

    $sw setwidget $tree

    pack $sw  -side top  -expand yes -fill both -pady 6
    pack $title -fill both -expand yes -pady 6

    return $tree
}

#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::getPath {w node} {
      # Note : only the experiment have data
      set res ""
      while { $node != "root" } {
          set res [$w itemcget $node -text]/$res
	  set node [$w parent $node]
      }
      string range $res 0 end ; # avoid leading //

}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::init { tree args } {

    variable count
    set count 0

    set largs [split $args " "]
    set i 0
    
    foreach adir $largs {
         # -- Test existence
	 if { ! [file isdirectory $adir] && [string compare $adir "no-selection"] != 0} {
	            set Preferences::ERROR_DEPOT_DO_NOT_EXIST 1
	 } else {
                    XTree::walkin $tree $adir "" 0 $adir root "" "" directory $i
         }
	 incr i
    }

    $tree configure -redraw 1

}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::reinit { tree args } {
 
          # -- Delete
          $tree delete [$tree nodes root]

          # -- re-initialize
          XTree::init $tree {*}$args
}

#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::getdir { tree node path } {
    variable count

    set lentries [glob -nocomplain [file join $path "*"]]
    set lfiles   {}
    foreach f $lentries {
        set tail [file tail $f]
	

        if { [file isdirectory $f] } {
                   $tree insert end $node n:$count \
                       -text      $tail \
                       -image     [Bitmap::get folder] \
                       -drawcross allways \
                       -data      $f
                   incr count
        } else {
            lappend lfiles $tail
        }
    }
    $tree itemconfigure $node -drawcross auto -data $lfiles
}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::moddir { idx tree node } {

    if { $idx && [$tree itemcget $node -drawcross] == "allways" } {
        getdir $tree $node [$tree itemcget $node -data]
        if { [llength [$tree nodes $node]] } {
            $tree itemconfigure $node -image [Bitmap::get openfold]
        } else {
            $tree itemconfigure $node -image [Bitmap::get folder]
        }
    } else {
        $tree itemconfigure $node -image [Bitmap::get [lindex {folder openfold} $idx]]
    }
}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::select { where num tree node } {
    variable dblclick


    set dblclick 1
    if { $num == 1 } {
        if { $where == "tree" && [lsearch [$tree selection get] $node] != -1 } {
            unset dblclick
            after 500 "XTree::edit tree $tree $node"
            return
        }
        if { $where == "tree" } {
            select_node $tree $node
        }
    } elseif { $where == "list" && [$tree exists $node] } {
	set parent [$tree parent $node]
	while { $parent != "root" } {
	    $tree itemconfigure $parent -open 1
	    set parent [$tree parent $parent]
	}
	select_node $tree $node
    }
}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::select_node { tree node } {

    $tree selection set $node
    update

    set dir [$tree itemcget $node -data]
    if { [$tree itemcget $node -drawcross] == "allways" } {
        getdir $tree $node $dir
        set dir [$tree itemcget $node -data]
	
    }

    set num 0
}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::edit { where tree node } {
    variable dblclick

    if { [info exists dblclick] } {
        return
    }

    if { $where == "tree" && [lsearch [$tree selection get] $node] != -1 } {
        set res [$tree edit $node [$tree itemcget $node -text]]
        if { $res != "" } {
            $tree itemconfigure $node -text $res
            $tree selection set $node
        }
        return
    }
}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::expand { tree but } {
   
    if { [set cur [$tree selection get]] != "" } {
        if { $but == 0 } {
            $tree opentree $cur
        } else {
            $tree closetree $cur
        }
    }
}

#proc XTree::lpop listVar {
#        upvar 1 $listVar l
#        set r [lindex $l end]
#        set l [lreplace $l [set l end] end] ; # Make sure [lreplace] operates on unshared object
#        return $r
#}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::walkin { tree fromDir branche level listD parent CmdList suffix ftype indice } {

    global listExp
    set matchLink {}

    #XPManager::update_progdlg $XPManager::MCGfrm "" "Finding Experiments in progress"

    set basedir [string trimright [file join [file normalize $fromDir] { }]]

    foreach fname [glob -nocomplain -type {l r} -path $basedir *] {
            set ftype [file type $fname]
	    if {[string compare $ftype "link"] == 0} {
		   set PointTo [file readlink $fname]
		   regsub -all {\.\/} $PointTo "" PointTo
		   lappend matchLink $PointTo
	    }
    }

    if { $level >= 12 } {
        if {[winfo exists .intro]} {
	      set win .intro
        } else {
	      set win .
	}
	Dialogs::show_msgdlg "You have reached the maximum recursion levels (12) ... \n
You may have a link creating recursion in your Experiment:\n
$fromDir"  ok warning ""  $win
	 return
    }

    if { $parent == "root" } {
           lappend CmdList "catch {$tree  insert end root home$indice -text $fromDir -image [Bitmap::get folder] -data root}"
	   set parent home$indice
    } else {
	   set Ftype [file type $basedir]
           if { $parent == "home$indice" } {
	          set suffix $branche  
	          if {[string compare $Ftype "link"] == 0} {
	                  lappend CmdList "catch {$tree insert end ${parent} ${branche} -text $branche -image [Bitmap::get folder]} -font {times 16}"
                  } else {
	                  lappend CmdList "catch {$tree insert end ${parent} ${branche} -text $branche -image [Bitmap::get folder]}"
		  }
	          set parent ${branche}
	   } else {
	          if {[string compare $Ftype "link"] == 0} {
	              lappend CmdList "catch {$tree insert end ${parent} ${branche}.$suffix -text $branche -image [Bitmap::get folder]} -font {times 16}"
                  } else {
	              lappend CmdList "catch {$tree insert end ${parent} ${branche}.$suffix -text $branche -image [Bitmap::get folder]}"
		  }
	          set parent ${branche}.$suffix
	   }
	   
    }

    set level [expr $level + 1]

    if { "$branche" ne "" } {
            lappend listD /$branche
    }


    # -- check if this is an expriment
    if { [file exists $basedir/EntryModule] && [catch [file link $basedir/EntryModule]] } {
                 set basename [file tail $basedir]
		 lappend listExp $basedir
		 set dd [join ${listD}/$basename ""]
	         set Ftype [file type $basedir]
		 
	         if {[string compare $Ftype "link"] == 0} {
		              lappend CmdList "catch {$tree insert end ${parent} ${basename}.$parent -text $basename -data $dd -image $Preferences::exp_icon_img} -font {times 16}"
                 } else {
		              lappend CmdList "catch {$tree insert end ${parent} ${basename}.$parent -text $basename -data $dd -image $Preferences::exp_icon_img}"
		 }
		 foreach cmd $CmdList {
		          eval  $cmd
		 }
                 #set XPManager::_progress 0

		 return
    }

    # -- if not go deep
    foreach dname [glob -nocomplain -type {d r} -path $basedir *] {
              if {[file isdirectory $dname]} {
		   # -- discard directories refered to by a link
		   if {[lsearch $matchLink [file tail $dname]] >= 0 } {
		           continue
		   }
	           set Ftype [file type $dname]
	           if { [file exists $dname/EntryModule] && [catch [file link $dname/EntryModule]] } {
		       set basename [file tail $dname]
		       lappend listExp $dname
		      
		       set dd [join ${listD}/$basename ""]
	               if {[string compare $Ftype "link"] == 0} {
		             lappend CmdList "catch {$tree insert end ${parent} ${basename}.$parent -text $basename -data $dd -image $Preferences::exp_icon_img} -font {times 16}"
                       } else {
		             lappend CmdList "catch {$tree insert end ${parent} ${basename}.$parent -text $basename -data $dd -image $Preferences::exp_icon_img}"
		       }
		       foreach cmd $CmdList {
		             eval  "$cmd"  
		       }
		   } else {
		      set basename [file tail $dname]
		      # -- dont Recurse on hub , bin, src
		      if { $basename != "hub" && $basename != "bin" && $basename != "src" && \
		            $basename != "listings" && $basename != "logs" && $basename != "resources" } {
                                walkin $tree $dname $basename $level $listD $parent $CmdList $suffix $Ftype $indice
		      }
                   }
              } 
    }
}

#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::lshift listVar {
    upvar 1 $listVar l
    if {![info exists l]} {
             # make the error message show the real variable name
            error "can't read \"$listVar\": no such variable"
    }

    set r [lindex $l 0]
    set l [lreplace $l [set l 0] 0]
    return $r
}

#---------------------------------------------
# -- Find Experiment in a given directory
# -- Need to detect recursion
#---------------------------------------------
proc XTree::FindExps {args} {

   set files {}
   set matchLink {}

   # - We need to do a first pass to gather link
   foreach x [glob -nocomplain [file join $args *]] {
		   set type [file type $x]
		   if {[string compare $type "link"] == 0} {
		         set Flink [file tail $x]
			 set PointTo [file readlink $x]
			 regsub -all {\.\/} $PointTo "" PointTo
			 lappend matchLink $PointTo 
		   }
   }

   while {[set dir [XTree::lshift args]] != ""} {
           foreach x [glob -nocomplain [file join $dir *]] {
		  if {[file isdir $x]} {
		           if { [file exists $x/EntryModule] && [catch [file link $x/EntryModule]] } {
		                  lappend files $x 
				  continue
                           }

		           set basename [file tail $x]
			 
			   if {  $basename != "hub" && $basename != "bin" && $basename != "src" && $basename != "listings" && \
			         $basename != "logs" && $basename != "resources" && $basename != "sequencing" && $basename != "modules" } {
                                   # -- check  if this is referenced already by a link
				   if {[lsearch $matchLink $basename] < 0 } {
                                            lappend args  $x
                                   }
			   }
		  }
           }
  }

  # -- return list of Exps.
  return $files
}
