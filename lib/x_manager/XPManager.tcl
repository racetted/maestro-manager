
global SEQ_MANAGER_BIN
global MUSER 
global array ExperimentInode
global array ArrayTabsDepot


# -- read args --> Crap this should not be here
set SEQ_MANAGER_BIN [lindex $argv 0] 

# -- get user
set MUSER [exec id -nu]

# ---------- NOT used for Now -----------------
# -- Global Code for Error Trapping
# -- set the proc
proc bug_Report {error} {

     global errorInfo env argv argv0

     set bugReport $errorInfo
     set question "Unexpected Error : $error"

    puts "$error   $errorInfo"
}
# -- set the Handler
#proc bgerror {error} {
#           bug_Report $error
#}
#----------------------------------------------

namespace eval XPManager {

    global SEQ_MANAGER_BIN 

    variable _wfont

    variable notebook
    variable mainframe
    variable MCGfrm
    variable status
    variable prgtext
    variable prgindic -1
    variable progmsg
    variable progval
    variable _progress 0
    variable _afterid  ""
    variable _status "Compute in progress..."
    variable font
    variable font_name
    variable f0
    variable _version "1.0"
    variable EntryPoint no-selection
    variable ExpOpsRepository
    variable ExpParRepository
    variable ExpPreOpsRepository

    # -- buttons icones
    foreach img {bug XpSel FoldXp Tool Refresh Ok Cancel Close Add Stop Remove Save Next Previous Apply Help Quit Notify Up} {
               eval variable img_$img [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/$img.gif]
    }

    # -- Audit
    variable img_clsdFolderImg     [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/clsdFolder.gif]
    variable img_openFolderImg     [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/openFolder.gif]
    variable img_fileImg           [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/file.gif]

    # -- Palacard
    variable img_placard [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/placard.gif]
    
    # -- Exp Icons
    variable img_ExpIcon           [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.gif]
    variable img_ExpNoteIcon       [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/xp.note.gif]
    variable img_ExpSunny          [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/Sunny.gif]
    variable img_ExpThunder        [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/Thunder.gif]
    variable img_ExpThunderstorms  [image create photo -file ${SEQ_MANAGER_BIN}/../etc/images/Thunderstorms.gif]

    foreach script {Dialogs.tcl XTree.tcl TreeUtil.tcl NewExp.tcl Audit.tcl Import.tcl XpBrowser.tcl SubmitBug.tcl About.tcl} {
	namespace inscope :: source ${SEQ_MANAGER_BIN}/../lib/x_manager/$script
    }

    foreach script { Preferences.tcl XpOptions.tcl } {
	namespace inscope :: source ${SEQ_MANAGER_BIN}/../lib/common/$script
    }
   
    # this is for the exp's configs *.cfg files
     namespace inscope :: source ${SEQ_MANAGER_BIN}/../lib/f_manager/ExpModTreeView.tcl
}

proc XPManager::create { } {
    global SEQ_MANAGER_BIN MUSER
    
    variable _wfont
    variable notebook
    variable mainframe
    variable MCGfrm

    variable font
    variable prgtext "Please wait while loading font..."
    variable prgindic -1
    variable f0
    variable EntryPoint
    variable ExpOpsRepository
    variable ExpParRepository
    variable ExpPreOpsRepository

    _create_intro
    update

    SelectFont::loadfont
    bind all <F12> { catch {console show} }

   if { [info exists ::env(CMCLNG)] == 0 || [string compare "$::env(CMCLNG)" "english"] == 0 } {
              source ${SEQ_MANAGER_BIN}/../lib/x_manager/menu_english.tcl
   } else {
              source ${SEQ_MANAGER_BIN}/../lib/x_manager/menu_francais.tcl
   }

   set prgtext   "Creating MainFrame..."
   set prgindic  0
   
   set mainframe [MainFrame .mainframe \
                       -menu         $descmenu \
                       -textvariable XPManager::status \
		       -progressfg blue\
                       -progressvar  XPManager::prgindic]

   # -- Parse Config files 
   set  prgtext   "Parsing Config files ..."
   incr prgindic
  
   Preferences::ParseUserMaestrorc

   # -- Check if all the vars All There
   Preferences::set_prefs_default
   Preferences::set_liste_Wall_Papers

   XPManager::ParseOpParExpDepot
  
   # -- Find Op Par Experiments and make them avail. to apl. 
   set  prgtext   "Findind Op, Par Experiments ..."
   incr prgindic

   # -- list of ALL OP exps
    XPManager::ListExperiments

   # --Show Name and Version
   set host [exec hostname]
    
   if {[regexp {afsiops|afsisio|afsipar} $MUSER]} { 
             $mainframe addindicator -text "$MUSER@$host" -bg #4dbaff
   } else {
             $mainframe addindicator -text "$MUSER@$host" -bg Azure
   }

   # --NoteBook creation
   set prgtext   "Creating Notebook..."
   incr prgindic
   
   set MCGfrm    [$mainframe getframe]

   set prgtext   "Creating Browser..."
   incr prgindic
   
   XpBrowser::create $MCGfrm


   set prgtext   "Done"
   incr prgindic
   
    
   pack $mainframe -fill both -expand yes
   update idletasks
   destroy .intro



}


proc XPManager::update_font { newfont } {
    variable _wfont
    variable notebook
    variable font
    variable font_name

    . configure -cursor watch
    if { $font != $newfont } {
        $_wfont configure -font $newfont
        $notebook configure -font $newfont
        set font $newfont
    }
    . configure -cursor ""
}


proc XPManager::_create_intro { } {
    
    global SEQ_MANAGER_BIN

    set top [toplevel .intro -relief raised -borderwidth 2]

    wm withdraw $top
    wm overrideredirect $top 1


    set ximg  [label $top.x -image $XPManager::img_placard -background white]
    set bwimg [label $ximg.bw -bitmap @${SEQ_MANAGER_BIN}/../etc/images/xm.xbm -foreground grey90 -background white]
    
    
    set frame [frame $ximg.f -background white]
    set lab1  [label $frame.lab1 -text "Loading ..."  -background white -font {times 8}]
    set lab2  [label $frame.lab2 -textvariable XPManager::prgtext  -background white -font {times 8} -width 35]

    set prg   [ProgressBar $frame.prg -width 50 -height 10 -variable XPManager::prgindic -maximum 5]


    pack $lab1 $lab2 $prg
    place $frame -x 0 -y 0 -anchor nw
    place $bwimg -relx 1 -rely 1 -anchor se
    pack $ximg

    BWidget::place $top 0 0 center
    
    wm deiconify $top
}

proc XPManager::main {} {
   
    global SEQ_MANAGER_BIN

    lappend ::auto_path [file dirname ${SEQ_MANAGER_BIN}]
    lappend ::auto_path [file dirname ${SEQ_MANAGER_BIN}]/lib/common
    lappend ::auto_path [file dirname ${SEQ_MANAGER_BIN}]/lib/f_manager

    namespace inscope :: package require BWidget 1.9

    option add *TitleFrame.l.font {helvetica 11 bold italic}

    wm withdraw .
    wm title . $Dialogs::XPM_ApplicationName 

    XPManager::create
    BWidget::place . 0 0 center
    wm deiconify .
    wm minsize . 700 500
    raise .
    focus -force .
}

proc XPManager::_show_progress { } {
    variable _progress
    variable _afterid
    variable _status

      
    if { $_progress } {
        set XPManager::status   "In progress..."
        set XPManager::prgindic 0
        $XPManager::mainframe showstatusbar progression
        if { $_afterid == "" } {
            set _afterid [after 10 XPManager::_update_progress]
        }
    } else {
        set XPManager::status ""
        $XPManager::mainframe showstatusbar status
        set _afterid ""
    }
}


proc XPManager::_update_progress { } {
    #variable _progress
    variable _afterid

    if { $XPManager::_progress } {
        if { $XPManager::prgindic < 100 } {
            #incr XPManager::prgindic 5
            puts "prgindic -> $XPManager::prgindic _progress-> $XPManager::_progress"
            set _afterid [after 10 XPManager::_update_progress]
        } else {
            set $XPManager::_progress 0
            $XPManager::mainframe showstatusbar status
            set XPManager::status "Done"
            set _afterid ""
            after 500 {set XPManager::status ""}
        }
    } else {
        set _afterid ""
    }
}

proc XPManager::show_progdlg {w titre} {

    set XPManager::progmsg "$titre ..."
    set XPManager::progval 0

    ProgressDlg ${w}.progress -parent $w -title "Wait..." \
            -type         incremental \
            -width        30 \
            -textvariable XPManager::progmsg \
            -variable     XPManager::progval \
            -stop         "" \
            -command      "destroy ${w}.progress"

}

proc XPManager::update_progdlg {w pn titre} {
    if { [winfo exists ${w}.progress] } {
            set XPManager::progval 5
	    set XPManager::progmsg "$titre  ... $pn"
    } 
}


proc XPManager::ListExperiments {} {
    global ListAllExperiments
    set ListAllExperiments {}
  
    set buf1 {}
    set buf2 {}
    # set buf1 [XTree::FindExps $XPManager::ExpOpsRepository]
    # set buf2 [XTree::FindExps $XPManager::ExpParRepository]

    # -- Add user stuf now all
    set buf3 {}
    set user_list [Preferences::GetTabListDepots "none" "r"]
    foreach lusrd $user_list {
       lappend buf3 {*}[XTree::FindExps $lusrd]
    }

    set ListAllExperiments [concat $buf1 $buf2 $buf3]

    # -- Now find Experiment Inode
    set ExperimentInode [TreeUtil::FindExpInode $ListAllExperiments]

    # DEBUG
    #dict for {id info} $ExperimentInode {
    #	    dict with info {
    #              puts "ExpId=$id inode=$inode Exp_path=$experiment"
    #	    }
    #}
}

proc XPManager::ParseOpParExpDepot {} {
           
           global SEQ_MANAGER_BIN

           set prefDparser [interp create -safe]
           $prefDparser alias ExpOpsRepository    XPManager::set_prefs_cmd_ExpOpsRepository
           $prefDparser alias ExpParRepository    XPManager::set_prefs_cmd_ExpParRepository
           $prefDparser alias ExpPreOpsRepository XPManager::set_prefs_cmd_ExpPreOpsRepository
	   # this is temp. 
           $prefDparser alias DefaultModDepot XPManager::set_prefs_cmd_DefaultModDepot

           set cmd {
                   set fid [open [file join ${SEQ_MANAGER_BIN}/../etc/config/ xm.cfg ] r]
                   set script [read $fid]
                   close $fid
                   $prefDparser eval $script
           }
           if {[catch  $cmd err] != 0} {
		    #Dialogs::show_msgdlg $Dialogs::Dlg_ErrorParseConfigOP  ok warning "" .
		    puts "Error Parsing file config"
           }

}

proc XPManager::set_prefs_cmd_ExpOpsRepository   {name args} { 
           global array ArrayTabsDepot

           set XPManager::ExpOpsRepository  $name
	   # -- Puts alws by default OP. exps
	   set ArrayTabsDepot($Dialogs::Nbk_OpExp)  $name
}

proc XPManager::set_prefs_cmd_ExpParRepository   {name args} { 
           global array ArrayTabsDepot

           set XPManager::ExpParRepository  $name
	   # -- Puts alws by default OP. exps
	   set ArrayTabsDepot($Dialogs::Nbk_PaExp)   $name
}

proc XPManager::set_prefs_cmd_ExpPreOpsRepository {name args} { 
           global array ArrayTabsDepot

           set XPManager::ExpPreOpsRepository    $name
	   # -- Puts alws by default OP. exps
	   set ArrayTabsDepot($Dialogs::Nbk_PrExp) $name
}

# this is temp.
proc XPManager::set_prefs_cmd_DefaultModDepot {name args} { 
}

# -- Global script
set script {
      if {[%W identify %x %y] == "close_button"} {
               set tabs [$XPManager::notebook tabs] 
               set ind  [%W index @%x,%y] 
               set tab [lindex $tabs $ind]
               destroy $tab
               break
     }
}

proc sleep {N} {
   after [expr {int($N * 1000)}]
}

# -- Prepar widget display language
Dialogs::setDlg
#Preferences::Config_table

XpOptions::globalOptions
XpOptions::tablelistOptions

XPManager::main
wm geom . [wm geom .]

# -- warn if parsing error user .maestrorc file
if { $Preferences::ERROR_PARSING_USER_CONFIG == 1 } {
                     Dialogs::show_msgdlg $Dialogs::Dlg_Error_parsing_user_file  ok warning "" .
}

#if { $Preferences::ERROR_NOT_RECOGNIZED_PREF == 1 } {
#                     Dialogs::show_msgdlg $Dialogs::Dlg_NonRecognizedPref  ok warning "" .
#}

if {[string compare $Preferences::ListUsrTabs "" ] == 0 } {
                     Dialogs::show_msgdlg $Dialogs::Dlg_DefineExpPath  ok warning "" .
}

# -- depot which  do not existe (ie could be erased by user and left in .maestrorc)
#if { $Preferences::ERROR_DEPOT_DO_NOT_EXIST == 1 } {
#                     Dialogs::show_msgdlg $Dialogs::Dlg_DepotNotExist  ok warning "" .
#}
