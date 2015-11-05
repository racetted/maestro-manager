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


namespace eval SubmitBug {
          variable subBug_win
          variable URL
}

# firefox --display=DISPLAY http://bugzilla.cmc.ec.gc.ca/
# if alreday running : firefox -remote "openURL(www.mozilla.org, new-tab)"


proc SubmitBug::Submit {  } {
               
      variable subBug_win
     
      if {[winfo exists  .submitbug]} {
              destroy  .submitbug
      }

      set subBug_win [toplevel .submitbug]

      wm geometry $subBug_win 340x200+0+0

      set frm [frame $SubmitBug::subBug_win.frame -border 2 -relief groove]
     
      set t1 [TitleFrame $frm.titf1 -text $Dialogs::Bug_title]
      set subf [$t1 getframe]

      label $subf.bim -text "" -image $XPManager::img_bug 
      label $subf.app -text "Application : Experiment manager" -font "ansi 10 "
      label $subf.ver -text "Version     : $XPManager::_version " -font "ansi 10 "

      switch  $Preferences::browser {
            "firefox"   {
                         set SubmitBug::URL "-remote openURL(http://bugzilla.cmc.ec.gc.ca/)" 
		        }
            "konqueror" {
                         set SubmitBug::URL "http://bugzilla.cmc.ec.gc.ca/" 
	                }
            "chromium-browser"    {
                         set SubmitBug::URL "--app=http://bugzilla.cmc.ec.gc.ca/" 
	                }
            "*"         {
                         set SubmitBug::URL "http://bugzilla.cmc.ec.gc.ca/" 
	                }
      }

      set rad1 [Button $subf.rad1 -text $Dialogs::Bug_message \
                    -command  {eval exec "$Preferences::browser" $Preferences::browser_args --display=$::env(DISPLAY) $SubmitBug::URL 2>/dev/null &}]
		               

      Button $subf.close -text "Close" -image $XPManager::img_Close -command { destroy $SubmitBug::subBug_win }

      # -- Pack everything

      pack $t1 -fill x -pady 2 -padx 2
      pack $subf.bim -anchor e
      pack $subf.app -anchor w
      pack $subf.ver -anchor w

      pack $rad1 -side left -pady 4
      pack $subf.close -side left -pady 4

      pack $frm -fill x

}
