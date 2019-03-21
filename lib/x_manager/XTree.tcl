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


global listExp 
global stopDirList
interp recursionlimit {} 50
global listInodes


array set stopDirList { "hub" "1" "bin" "1" "src" "1" "listins" "1" "logs" "1" "resources" "1" "sequencing" "1" "modules" "1" "constants" "1" }
array set listExp {}

namespace eval XTree {
    variable count
    variable dblclick
    variable Exp_liste ""
}


#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::create { frm nb } {

    set title [TitleFrame $frm.t -text $Dialogs::XpB_xpbrowser ]
    set sw    [ScrolledWindow [$title getframe].sw -relief sunken -borderwidth 2 ]

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

    pack $sw    -side top  -expand yes -fill both -pady 6
    pack $title -fill both -expand yes -pady 6

    return $tree
}

#-----------------------------------------------------------
#-----------------------------------------------------------
proc XTree::getPath {w node} {
      # Note : only experiments have data
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
    global listInodes CmdList stopDirList listExp ListAllExperiments
    variable count
    set count 0

    set largs [split $args " "]
    set i 0
    
    foreach adir $largs {
         # -- Test existence
	 if { ! [file isdirectory $adir] && [string compare $adir "no-selection"] != 0} {
	            set Preferences::ERROR_DEPOT_DO_NOT_EXIST 1
	 } else {
                    # -- empty list
                    array unset listInodes
                    set CmdList {}

                    #XTree::walkin $tree $adir "" 0 $adir root "" "" directory $i
                    XTree::FindDrawTree $tree $adir "" 0 $adir root "" "" directory $i
		    set ListAllExperiments [lsort [array names listExp]]

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
                       -font TkTextFont \
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
   # puts "XTree::select where:${where} num:${num} tree:${tree} node:${node}"
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
   # puts "XTree::select_node tree:${tree} node:${node}"

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
    # puts "XTree::edit where:${where} tree:${tree} node:${node}"
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
    # puts "XTree::expand tree:${tree} but:${but}"
    if { [set cur [$tree selection get]] != "" } {
        if { $but == 0 } {
            $tree opentree $cur
        } else {
            $tree closetree $cur
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

proc XTree::FindDrawTree { tree fromDir branche level listD parent CmdList suffix ftype indice } {
    # puts "XTree::FindDrawTree tree:$tree fromDir:$fromDir branche:$branche level:$level"
    global listExp listInodes stopDirList

    set basedir [string trimright [file join [file normalize $fromDir] { }]]

    if { $level >= 12 } {
	 puts  "You have reached the maximum recursion levels (12) ...  You may have a link creating recursion in your Experiment:\n"
	 return
    }

    # -- check if this is an expriment
   set kris [catch {file type $basedir/EntryModule} ftype]
   if {  $kris == 0 &&  $ftype eq "link" } {
                 set basename [file tail $basedir]
		 set listExp($basedir) "1"
		 set dd [join ${listD}/$basename ""]
		 file stat $basedir statinfo
		 set inode $statinfo(ino)
                 # add the experiment node
		 set string ";catch { $tree insert end ${parent} ${parent}.${basename} -text $basename -data $dd -image $Preferences::exp_icon_img }"
		 append CmdList $string
		 eval $CmdList
                 set CmdList {}
		 if {[array get listInodes $inode] == "" } {
		    set listInodes($inode) 1
		 }

                 # found an experiment, we are done
		 return
    }

    # not an experiment, search deeper 
    if { $parent == "root" } {
           # suite depot level
           set currentNode home$indice 
           set string ";catch { $tree  insert end root ${currentNode} -text $fromDir -image [Bitmap::get folder] -data root }"
    } else {
           # sub directory level
	   set Ftype [file type $basedir]
           set currentNode  ${parent}.${branche} 
	   set string ";catch { $tree insert end ${parent} ${currentNode} -text $branche -image [Bitmap::get folder] }"
           # puts "adding $tree insert end ${parent} ${currentNode} -text $branche"
    }
    set parent ${currentNode}
    append CmdList $string

    set level [expr $level + 1]

    if { "$branche" ne "" } {
            lappend listD /$branche
    }

    # -- if not go deep, the code capture dir and links
    # There is a check further to filter out items with the same inode
    set dirList [lsort [glob -nocomplain -type {l d r} -path $basedir *]]
   
    foreach dname ${dirList} {
              # puts "go deep on dname:$dname level:$level"
	      set basename [file tail $dname]
	      set Ftype [file type $dname]
	      file stat $dname statinfo
	      set inode $statinfo(ino)
              if { $Ftype eq "directory" } {
                   set kris [catch {file type $dname/EntryModule} ftype]
	           if { $kris == 0 && $ftype eq "link" == 0 } {
                       # found an experiment
		       set listExp($basedir) "1"
		      
		       set dd [join ${listD}/$basename ""]
		       set string ";catch { $tree insert end ${parent} ${parent}.${basename} -text $basename -data $dd -image $Preferences::exp_icon_img }"
		       
		       append CmdList $string
		       eval $CmdList
                       set CmdList {}
		       if {[array get listInodes $inode] == "" } {
		          set listInodes($inode) 1
		       }
		   } else {
		      # -- dont Recurse on hub , bin, src
                      # if the inode is the same as one that I already saw, skip it
                      # this means if a suite has both a link and a directory, only one of them will show up
                      # i.e. gdps -> gdps_20150212
		      if {[array get listInodes $inode] == "" } {
		         set listInodes($inode) 1
                         if { [array get stopDirList ${basename}] == "" } {
                            FindDrawTree $tree $dname $basename $level $listD $parent $CmdList $suffix $Ftype $indice 
		         }
		      }
                   }
              } else {
	        set PointingTo [ exec true_path $dname]
	        #set PointingTo [file normalize $dname]
		# -- dont follow link pointing to files|links
		if {[file isdirectory $PointingTo]} {
		     file stat $PointingTo statinfo
		     set inode $statinfo(ino)
		     if {[array get listInodes $inode] == "" } {
		        set listInodes($inode) 1
                        if { [array get stopDirList ${basename}] == "" } {
                           FindDrawTree $tree $dname $basename $level $listD $parent $CmdList $suffix $Ftype $indice 
		        }
		     }
		}
	      }
    }
    set CmdList {}
}

#---------------------------------------------
# -- Find Experiment in a given directory
# -- Need to detect recursion
#---------------------------------------------

proc XTree::FindExps {args} {
   global stopDirList
   set files {}
   array set myListInodes {}

   while {[set dir [XTree::lshift args]] != ""} {
           foreach x [glob -nocomplain [file join $dir *]] {
	          set Ftype [file type $x]
                  set basename [file tail $x]
                  if {$Ftype ne "link" } {
		           # puts "x=$x is a dir"
			   file stat $x statinfo
			   set inode $statinfo(ino)
                           
			   set kris [catch {file type $x/EntryModule} ftype]
                           if  {$kris == 0 && $ftype eq "link"}  {
		                  if { [catch {set Module [exec true_path $x/EntryModule]}] == 0 }  {
                                        lappend files $x 
		                        if {[array get myListInodes $inode] == "" } {
		                           set myListInodes($inode) 1
                                        }
				  }
                                  continue
                           }

                         
                           # -- check  if this is referenced already by a link
                           if { [array get stopDirList ${basename}] == "" && [array get myListInodes $inode] == "" } {
                                  lappend args  $x
		                  set myListInodes($inode) 1
                           }
                  } else {
		      # puts "x=$x is a link"
		      if { [catch {set PointingTo [exec true_path $x]}] == 0 }  {
		           if {[file isdirectory $PointingTo]} {
		               file stat $PointingTo statinfo
			       set inode $statinfo(ino)
                               set basename [file tail $PointingTo]
                               if { [array get stopDirList ${basename}] == "" && [array get myListInodes $inode] == "" } {
                                  lappend args  $x
		                  set myListInodes($inode) 1
			       }
			    }
		      }
		  }
	   }
   }

   # -- return list of Exps.
   return $files
}

