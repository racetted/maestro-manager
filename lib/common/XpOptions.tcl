namespace eval XpOptions {
}

proc XpOptions::globalOptions {} {

     # Create the font TkDefaultFont if not yet present
     catch {font create TkDefaultFont -family Helvetica -size -12}

     option add *Font                    TkDefaultFont
     #option add *selectBackground        #678db2
     option add *selectBackground        "#509df4"
     option add *selectForeground        white
     option add *activeBackground        "#509df4"

}

proc XpOptions::tablelistOptions {} {

     option add *Tablelist.background        white
     option add *Tablelist.stripeBackground  #e4e8ec
     option add *Tablelist.setGrid           yes
     option add *Tablelist.movableColumns    yes
     option add *Tablelist.labelCommand      tablelist::sortByColumn
     option add *Tablelist.labelCommand2     tablelist::addToSortColumns
}
