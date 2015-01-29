# the context is a generic value that binds
# all the visual nodes together
# for instance, when drawing a module flow
# the context is the module node name
# withing the experiment tree
record define FlowVisualNode {
   x1
   y1
   x2
   y2
   context
}

proc DrawUtil_drawline { canvas x1 y1 x2 y2 arrow fill drawshadow shadowColor {tag_name ""} } {

    #set width 0.5
    set width 1.0
    if { $x1 < $x2 } {
      set x2 [expr $x2 - 2 ]

      #set shadow values
      set sx1 [expr $x1 + 1 ]
      set sx2 $x2
      set sy1 [expr $y1 + 1 ]
      set sy2 $sy1
    } else {
      
      #set shadow values
      set sx1 [expr $x1 + 1]
      set sx2 $sx1
      set sy1 [expr $y1 + 1]
      set sy2 [expr $y2 + 2]
    }
    if { $drawshadow == "on" } {
      # draw shadow
      if { ${tag_name} == "" } {
         $canvas create line ${sx1} ${sy1} ${sx2} ${sy2} -width ${width} -arrow $arrow -fill $shadowColor -tags "FlowItems"
      } else {
         $canvas create line ${sx1} ${sy1} ${sx2} ${sy2} -width ${width} -arrow $arrow -fill $shadowColor -tags "FlowItems {tag_name}"
      }
    }

    # draw line
   if { ${tag_name} == "" } {
      $canvas create line ${x1} ${y1} ${x2} ${y2} -width ${width} -arrow $arrow -fill $fill -tags "FlowItems"
   } else {
      $canvas create line ${x1} ${y1} ${x2} ${y2} -width ${width} -arrow $arrow -fill $fill -tags "FlowItems ${tag_name}"
   }

}

proc DrawUtil_drawdashline { canvas x1 y1 x2 y2 arrow fill drawshadow shadowColor {tag_name ""}} {
    if { $x1 < $x2 } {
      set x2 [expr $x2 - 3 ]

      #set shadow values
      set sx1 [expr $x1 + 1 ]
      set sx2 $x2
      set sy1 [expr $y1 + 1 ]
      set sy2 $sy1
    } else {
      
      #set shadow values
      set sx1 [expr $x1 + 1]
      set sx2 $sx1
      set sy1 [expr $y1 + 1]
      set sy2 $y2
    }

    if { $drawshadow == "on" } {
      # draw shadow
      if { ${tag_name} == "" } {
         $canvas create line ${sx1} ${sy1} ${sx2} ${sy2} -width 1.0 -arrow $arrow -fill $shadowColor -dash { 4 3 } -tags "FlowItems"
      } else {
         $canvas create line ${sx1} ${sy1} ${sx2} ${sy2} -width 1.0 -arrow $arrow -fill $shadowColor -dash { 4 3 } -tags "FlowItems ${tag_name}"
      }
    }

   # draw line
   if { ${tag_name} == "" } {
      $canvas create line ${x1} ${y1} ${x2} ${y2} -width 1.0 -arrow $arrow -fill $fill -dash { 4 3 } -tags "FlowItems"
   } else {
      $canvas create line ${x1} ${y1} ${x2} ${y2} -width 1.0 -arrow $arrow -fill $fill -dash { 4 3 } -tags "FlowItems ${tag_name}"
   }
}

proc DrawUtil_drawBox { canvas tx1 ty1 text maxtext textfill outline fill binder drawshadow shadowColor } {
   # ::log::log debug "drawBox canvas:$canvas tx1:$tx1 ty1:$ty1 text:$text textfill=$textfill outline=$outline fill=$fill binder:$binder"
   $canvas create text ${tx1} ${ty1} -text $maxtext -fill $textfill \
      -justify center -anchor w -tags "FlowItems $binder ${binder}.text"
   set shadowOffset [SharedData_getMiscData CANVAS_SHADOW_OFFSET]
   # draw a box around the text
   set boxArea [$canvas bbox ${binder}.text]

   $canvas itemconfigure ${binder}.text -text $text

   set nx1 [expr [lindex $boxArea 0] -5]
   set ny1 [expr [lindex $boxArea 1] -5]
   set nx2 [expr [lindex $boxArea 2] +5]
   set ny2 [expr [lindex $boxArea 3] +5]
   $canvas create rectangle ${nx1} ${ny1} ${nx2} ${ny2} \
            -fill $fill -outline $outline -tags "FlowItems $binder ${binder}.main"
   $canvas lower ${binder}.main ${binder}.text

   if { $drawshadow == "on" } {
       # draw a shadow
       set sx1 [expr $nx1 + ${shadowOffset}]
       set sx2 [expr $nx2 + ${shadowOffset}]
       set sy1 [expr $ny1 + ${shadowOffset}]
       set sy2 [expr $ny2 + ${shadowOffset}]
       $canvas create rectangle ${sx1} ${sy1} ${sx2} ${sy2} -width 0 \
               -fill $shadowColor  -tags "FlowItems ${binder} ${binder}.shadow"
       $canvas lower ${binder}.shadow ${binder}.main
   }
}

proc DrawUtil_drawRoundBox { canvas tx1 ty1 text maxtext textfill outline fill binder drawshadow shadowColor } {
   # ::log::log debug "DrawUtil_drawRoundBox canvas:$canvas tx1:$tx1 ty1:$ty1 text:$text textfill=$textfill outline=$outline fill=$fill binder:$binder"
   $canvas create text ${tx1} ${ty1} -text $maxtext -fill $textfill \
      -justify center -anchor w -tags "FlowItems $binder ${binder}.text"
   set shadowOffset [SharedData_getMiscData CANVAS_SHADOW_OFFSET]
   # draw a box around the text
   set boxArea [$canvas bbox ${binder}.text]
   set radius 45

   $canvas itemconfigure ${binder}.text -text $text

   set nx1 [expr [lindex $boxArea 0] -5]
   set ny1 [expr [lindex $boxArea 1] -5]
   set nx2 [expr [lindex $boxArea 2] +5]
   set ny2 [expr [lindex $boxArea 3] +5]

   $canvas create arc [expr ${nx1} - 4] [expr ${ny1} + 2] [expr ${nx1} + 10] [expr ${ny2} -2] -extent 180 -start 90 -fill ${fill} -outline ${outline} -tag "FlowItems ${binder} ${binder}.arc"
   DrawUtil_roundRect ${canvas} ${nx1} ${ny1} ${nx2} ${ny2} ${radius} -fill $fill -outline ${outline} -tags "FlowItems $binder ${binder}.main"

   ${canvas} lower ${binder}.main ${binder}.text

   if { $drawshadow == "on" } {
       # draw a shadow
       set sx1 [expr $nx1 + ${shadowOffset}]
       set sx2 [expr $nx2 + ${shadowOffset}]
       set sy1 [expr $ny1 + ${shadowOffset}]
       set sy2 [expr $ny2 + ${shadowOffset}]
       DrawUtil_roundRect $canvas ${sx1} ${sy1} ${sx2} ${sy2} ${radius} \
               -fill $shadowColor  -tags "FlowItems ${binder} ${binder}.shadow"
       $canvas lower ${binder}.shadow ${binder}.main
   }
   ${canvas} lower ${binder}.arc ${binder}.main
}

# got from the web pasting it as is
proc DrawUtil_roundRect { w x0 y0 x3 y3 radius args } {

    set r [winfo pixels $w $radius]
    set d [expr { 2 * $r }]

    # Make sure that the radius of the curve is less than 3/8
    # size of the box!

    set maxr 0.75

    if { $d > $maxr * ( $x3 - $x0 ) } {
        set d [expr { $maxr * ( $x3 - $x0 ) }]
    }
    if { $d > $maxr * ( $y3 - $y0 ) } {
        set d [expr { $maxr * ( $y3 - $y0 ) }]
    }

    set x1 [expr { $x0 + $d }]
    set x2 [expr { $x3 - $d }]
    set y1 [expr { $y0 + $d }]
    set y2 [expr { $y3 - $d }]

    set cmd [list $w create polygon]
    lappend cmd $x0 $y0
    lappend cmd $x1 $y0
    lappend cmd $x2 $y0
    lappend cmd $x3 $y0
    lappend cmd $x3 $y1
    lappend cmd $x3 $y2
    lappend cmd $x3 $y3
    lappend cmd $x2 $y3
    lappend cmd $x1 $y3
    lappend cmd $x0 $y3
    lappend cmd $x0 $y2
    lappend cmd $x0 $y1
    lappend cmd -smooth 1
    return [eval $cmd $args]
 }


proc DrawUtil_drawOval { canvas tx1 ty1 txt maxtext textfill outline fill binder drawshadow shadowColor } {
   set newtx1 [expr ${tx1} + 10]
   set newty1 $ty1
   #set newty1 [expr ${ty1} + 5]
   $canvas create text ${newtx1} ${newty1} -text $maxtext -fill $textfill \
      -justify center -anchor w -tags "FlowItems $binder ${binder}.text"

   set boxArea [$canvas bbox ${binder}.text]
   $canvas itemconfigure ${binder}.text -text $txt

   set ovalSize [SharedData_getMiscData LOOP_OVAL_SIZE]
   set shadowOffset [SharedData_getMiscData CANVAS_SHADOW_OFFSET]
   set nx1 [expr [lindex $boxArea 0] - ${ovalSize}]
   set ny1 [expr [lindex $boxArea 1] - ${ovalSize}]
   set nx2 [expr [lindex $boxArea 2] + ${ovalSize}]
   set ny2 [expr [lindex $boxArea 3] + ${ovalSize}]
   
   $canvas create oval ${nx1} ${ny1} ${nx2} ${ny2}  \
          -fill $fill -tags "FlowItems $binder ${binder}.main"

   $canvas lower ${binder}.main ${binder}.text

   if { $drawshadow == "on" } {
       # draw a shadow
       set sx1 [expr $nx1 + ${shadowOffset}]
       set sx2 [expr $nx2 + ${shadowOffset}]
       set sy1 [expr $ny1 + ${shadowOffset}]
       set sy2 [expr $ny2 + ${shadowOffset}]
       $canvas create oval ${sx1} ${sy1} ${sx2} ${sy2} -width 0 \
               -fill $shadowColor  -tags "FlowItems ${binder} ${binder}.shadow"
       $canvas lower ${binder}.shadow ${binder}.main
   }
}

proc DrawUtil_drawLosange { canvas tx1 ty1 text maxtext textfill outline fill binder drawshadow shadowColor} {
   set newtx1 [expr ${tx1} + 30]
   $canvas create text ${newtx1} [expr ${ty1} + 5] -text ${maxtext} -fill $textfill \
      -justify center -anchor w -tags "FlowItems $binder ${binder}.text"

   set boxArea [$canvas bbox ${binder}.text]
   set nx1 [expr [lindex $boxArea 0] -30]
   set nx2 [lindex $boxArea 0]
   set nx3 [expr [lindex $boxArea 2] +30]
   set nx4 [lindex $boxArea 2]

   set ny1 [expr [lindex $boxArea 3] +5]
   set ny2 [expr [lindex $boxArea 1] -5]
   set ny3 $ny2
   set ny4 $ny1
   set maxY ${ny1}
   $canvas create polygon ${nx1} ${ny1} ${nx2} ${ny2} ${nx3} ${ny3} ${nx4} ${ny4} \
         -outline $outline -fill $fill -tags "FlowItems $binder ${binder}.main"

   $canvas lower ${binder}.main ${binder}.text

   if { $drawshadow == "on" } {
      # draw a shadow
      set sx1 [expr $nx1 + 5]
      set sx2 [expr $nx2 + 5]
      set sx3 [expr $nx3 + 5]
      set sx4 [expr $nx4 + 5]
      set sy1 [expr $ny1 + 5]
      set sy2 [expr $ny2 + 5]
      set sy3 [expr $ny3 + 5]
      set sy4 [expr $ny4 + 5]
      $canvas create polygon ${sx1} ${sy1} ${sx2} ${sy2} ${sx3} ${sy3} ${sx4} ${sy4} -width 0 \
            -fill $shadowColor  -tags "FlowItems $binder ${binder}.shadow"
      set maxY ${sy1}
      $canvas lower ${binder}.shadow ${binder}.main
   }

   set indexListW [DrawUtils_getIndexWidgetName ${binder} ${canvas}]
   if { ! [winfo exists ${indexListW}] } {
      ComboBox ${indexListW} -bwlistbox 1 -hottrack 1 -width 7
   }
   ${indexListW} clearvalue
   pack ${indexListW} -fill both
   # puts "DrawUtil_drawLosange ${binder} cget -switch_items [${binder} cget -switch_items]"
   ${indexListW} configure -values ""
   set switchItems [${binder} cget -switch_items]
   if { ${switchItems} != "" } {
      ${indexListW} configure -values ${switchItems}
      set initialIndex first
      set curSelection [${binder} cget -curselection]
      set foundIndex [lsearch ${switchItems} ${curSelection}]
      if { ${curSelection} != "" && ${foundIndex} != -1 } {
         set initialIndex @${foundIndex}
         ${indexListW} setvalue ${initialIndex}
      }
   }

   set barY [expr ${maxY} + 15]
   set barX [expr ($nx1 + $nx3)/2]
   ${canvas} create window ${barX} ${barY} -window ${indexListW} -tags "FlowItems ${binder} ${binder}.index_widget"
}

proc DrawUtils_getIndexWidgetName { _binder _canvas } {
   set newNode [regsub -all "/" ${_binder} _]   
   set newNode [regsub -all {[\.]} ${newNode} _]
   set indexListW "${_canvas}.[string tolower ${newNode}]"
}

proc DrawUtil_highLightNode { _binder _canvas _restoreCmd } {
   upvar #0 ${_restoreCmd} evalCmdList

   set canvasTag ${_binder}.main
   set selectColor [SharedData_getColor SELECT_BG]
   set currentWidth [${_canvas} itemcget ${canvasTag} -width ]
   set currentOutline [${_canvas} itemcget ${canvasTag} -outline]
   ${_canvas} itemconfigure ${canvasTag} -width 2 -outline ${selectColor}

   append evalCmdList ";${_canvas} itemconfigure ${canvasTag} -width ${currentWidth} -outline ${currentOutline}"
}

proc DrawUtil_resetHighLightNode { _restoreCmd } {
   # ::log::log debug "DrawUtil_resetHighLightNode _restoreCmd:${_restoreCmd}"
   catch { eval ${_restoreCmd} }
}

proc DrawUtil_setShadowColor { _binder _canvas _color } {
   ::log::log debug "DrawUtil_setShadowColor $_binder $_canvas $_color"
   ${_canvas} itemconfigure ${_binder}.shadow -fill ${_color}
}

proc DrawUtil_clearCanvas { _canvas } {
   if { [winfo exists ${_canvas}] } {
      # flush everything in the canvas which fave a FlowItems tag
      eval ${_canvas} delete [${_canvas} find withtag FlowItems]
   }
   update idletasks
}

# this function adds a background image to a flow canvas.
# The image is created once when the canvas is created; this function is called
# when the flow is redrawn or the window is resized
proc DrawUtil_AddCanvasBg { _canvas _imageFile } {
   package require img::png
   if { [${_canvas} find withtag CanvasBgImage] == "" } {
      #set imageFileName [SharedData_getMiscData IMAGE_DIR]/artist_canvas_center.png
      set sourceImage [image create photo -file ${_imageFile}]
      set tiledImage [image create photo]

    ${_canvas} create image 0 0 \
        -anchor nw \
        -image $tiledImage \
        -tags CanvasBgImage

     ${_canvas} lower CanvasBgImage

    bind ${_canvas} <Configure> [list DrawUtil_tileBgImage ${_canvas} $sourceImage $tiledImage]
    bind ${_canvas} <Destroy> [list image delete $sourceImage $tiledImage]
    DrawUtil_tileBgImage ${_canvas} $sourceImage $tiledImage
  }
}

proc DrawUtil_tileBgImage { _canvas _sourceImage _tiledImage} {
   set canvasBox [${_canvas} bbox all] 
   set canvasItemsW [lindex ${canvasBox} 2]
   set canvasItemsH [lindex ${canvasBox} 3]
   set canvasW [winfo width ${_canvas}]
   set canvasH [winfo height ${_canvas}]
   set usedW ${canvasItemsW}
   if { ${canvasW} > ${canvasItemsW} } {
   set usedW ${canvasW}
   }    
   set usedH ${canvasItemsH}
   if { ${canvasH} > ${canvasItemsH} } {
   set usedH ${canvasH}
   }    

   ${_tiledImage} copy ${_sourceImage} \
      -to 0 0 [expr ${usedW} + 20] [expr ${usedH} + 20]
}
