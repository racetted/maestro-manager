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
     option add *disabledForeground      "#4e144dbb4d62"
     option add *Entry.background        white
     option add *Listbox.background      white
     option add *Spinbox.background      white
     option add *Text.background         white

}

proc XpOptions::tablelistOptions {} {

     option add *Tablelist.background        white
     option add *Tablelist.disabledForeground "#4e144dbb4d62"
     option add *Tablelist.stripeBackground  #e4e8ec
     option add *Tablelist.setGrid           yes
     option add *Tablelist.movableColumns    yes
     option add *Tablelist.labelCommand      tablelist::sortByColumn
     option add *Tablelist.labelCommand2     tablelist::addToSortColumns
}
