
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


set descmenu {
            "Experiments" {} {} 0 {
                 {command "New" {} "Create New Experiment" {} -command {NewExp::New_xp "" none}}
	         {command "Audit" {}  "Audit Experiment " {} -command {Audit::AuditExp ""}}
	         {command "Import" {} "Import one Experiment " {} -command {Import::ImportExp ""}}
	         {command "Repository " {} "Experiment Repository Configuration" {} -command {Preferences::ConfigDepot}}
		 {separator}
	         {command "Quit" {} "Quit application" {} -command {exit}}
            }
	    "Preferences" {} {} 0 {
	    {command "SetUp Preferences" {} "User Preferences setup" {} -command {Preferences::PrefShow}}
            {command "Select fonts" {} $Dialogs::XpB_dkfont {} -command {DkfFont_init}}
            }
            "Help" {} {} 0 {
	      {command "Help" {} "Help" {} -command {About::Help}}
	      {command "Report Bug ... " {} "Bug" {} -command {SubmitBug::Submit}}
	      {command "About" {} "About" {} -command {About::Show}}
            }
}
