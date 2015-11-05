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
            "Experiences" {} {} 0 {
                 {command "Nouvelle" {} "Creer une Nouvelle Experience" {} -command {NewExp::New_xp "" none }}
	         {command "Audit" {}  "Audit d'une Experience " {} -command {Audit::AuditExp ""}}
	         {command "Importer" {} "Importer une Experience " {} -command {Import::ImportExp ""}}
	         {command "Depots " {} "Configuration du depot des Experiences" {} -command {Preferences::ConfigDepot}}
		 {separator}
	         {command "Quitter" {} "Quitter l'application" {} -command {exit}}
            }
	    "Preferences" {} {} 0 {
	    {command "&Configurer les preferences " {} "Preferences de l'Usager" {} -command {Preferences::PrefShow}}
            }
            "Aide" {} {} 0 {
	      {command "Aide" {} "Aide" {} -command {About::Help}}
	      {command "Rapporter un malfonctionnement  " {} "Malfonctionnement" {} -command {SubmitBug::Submit}}
	      {command "A propos" {} "A propos" {} -command {About::Show}}
            }
}
