
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
            }
            "Help" {} {} 0 {
	      {command "Help" {} "Help" {} -command {About::Help}}
	      {command "Report Bug ... " {} "Bug" {} -command {SubmitBug::Submit}}
	      {command "About" {} "About" {} -command {About::Show}}
            }
}
