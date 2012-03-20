
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
