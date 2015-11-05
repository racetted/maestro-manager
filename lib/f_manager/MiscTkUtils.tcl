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


proc MiscTkUtils_positionWindow { _sourceWidget _topWidget } {
   set sourceTop [winfo toplevel ${_sourceWidget}]
   if { ${_topWidget} == "." } {
      wm geometry ${_topWidget} +100+100
   } else {
   
      set x [winfo pointerx ${sourceTop}]
      set y [winfo pointery ${sourceTop}]
     
      #set posX [expr $x + $x/3]
      #set posY [expr $y + $y/8]
      set posX [expr ${x} + 20]
      set posY ${y}
      wm geometry ${_topWidget} +${posX}+${posY}
   }
}

proc MiscTkUtils_InitPosition { _topWidget } {
   wm geometry ${_topWidget} +100+100
}

proc MiscTkUtils_normalCursor { w } {
   if { [winfo exists $w] } {
      catch {
         $w configure -cursor {}
         update idletasks
      }
   }
}

proc MiscTkUtils_busyCursor { w } {
   if { [winfo exists $w] } {
      $w configure -cursor watch
      update idletasks
   }
}

