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


namespace eval About {
               variable _bugr
               variable subBug_win
}


#--------------------------------------------------------------------------
# About 
# show Information about application 
#--------------------------------------------------------------------------
proc About::Show {} {
      
      variable About

      set About [toplevel .about]
      wm minsize  $About 340 160
      wm geometry $About 340x160+0+0

      set frm [frame $About::About.frame -border 2 -relief groove]
     
      set t1 [TitleFrame $frm.titf1 -text "xm  eXperiment Manager"]
      set subf [$t1 getframe]

      
      #label $subf.bim -text "" -image $XPManager::img_bug 
      label $subf.app -text "Application : eXperiment Manager (xm)" -font "ansi 10 "
      label $subf.aut -text "Author      : Rochdi Lahlou, CMOI " -font "ansi 10 "
      label $subf.ver -text "Version     : $XPManager::_version " -font "ansi 10 "

      Button $subf.close -text "Close" -image $XPManager::img_Close -command {destroy $About::About}

      # -- Pack everything

      pack $t1 -fill x -pady 2 -padx 2
      #pack $subf.bim -anchor e
      pack $subf.app -anchor w
      pack $subf.aut -anchor w
      pack $subf.ver -anchor w

      pack $subf.close -side bottom -pady 8 

      pack $frm -fill x

}

#--------------------------------------------------------------------------
# help 
# show Help 
#--------------------------------------------------------------------------
proc About::Help {} {
     
      variable MHelp

      set MHelp [toplevel .xmHelp]
      wm minsize  $MHelp 500 200
      wm geometry $MHelp 500x200+0+0

      set frm [frame $About::MHelp.frame -border 2 -relief groove]
     
      set t1 [TitleFrame $frm.titf1 -text "Help Page"]
      set subf [$t1 getframe]
      Button $subf.close -text "Close" -image $XPManager::img_Close -command {destroy $About::MHelp}

      pack $t1 -fill x -pady 2 -padx 2
      pack $subf -anchor w
      pack $frm -fill x

      Dialogs::show_msgdlg "Comming Soon "  ok info "" $About::MHelp
}
