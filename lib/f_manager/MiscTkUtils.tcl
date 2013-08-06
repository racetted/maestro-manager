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

