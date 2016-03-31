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


namespace eval Dialogs {
         variable msg
}

proc Dialogs::setDlg {} {
         
	 variable XPM_ApplicationName

	 variable Dlg_NoExpPath
         variable Dlg_NoValExpPath
         variable Dlg_ProvideExpPath
         variable Dlg_ExpPathInList
         variable Dlg_UpdateExpBrowser
         variable Dlg_BrowserUpdated
         variable Dlg_NoAsciiFile
         variable Dlg_DefineExpPath
         variable Dlg_NodeNotExists
	 variable Dlg_TreeNotExists
	 variable Dlg_NonRecognizedPref
	 variable Dlg_ErrorParseConfigOP
	 variable Dlg_PathDeep
	 variable Dlg_DefaultBrowser
	 variable Dlg_DefaultKonsole
	 variable Dlg_ErrorAudit2Exp
	 variable Dlg_AddPath
	 variable Dlg_CreatePath
	 variable Dlg_PathNotOwned
	 variable Dlg_Error_parsing_user_file
	 variable Dlg_NotUnderHOME
	 variable Dlg_DepotNotExist
	 variable Dlg_ExpInvalidName
	 variable Dlg_ModInvalidName
	 variable Dlg_ExpNameMiss
	 variable Dlg_NameEntryMod
	 variable Dlg_NewExpPath
	 variable Dlg_ExpPathInvalid
	 variable Dlg_ExpDateInvalid
	 variable Dlg_CatchupInvalid
	 variable Dlg_NumCarCatchup
	 variable Dlg_ExpExiste
	 
	 variable Gui_selectedExp
	 variable Gui_ControlExp
	 variable Gui_ExpName
	 variable Gui_ExDatep
	 variable Gui_ExpCatchup

	 variable Nbk_MyExp
	 variable Nbk_OpExp
	 variable Nbk_PaExp
	 variable Nbk_PrExp
	 
	 variable New_ExpTitle
	 variable New_ExpName
	 variable New_ExpSubD
	 variable New_ExpDest
	 variable New_ExpEnMo
	 variable New_ExpResFile
         variable New_ExpRemoteWarning
	 variable New_Dirs
	 variable New_DirName
	 variable New_Pointto
	 variable New_Parametres
	 variable New_NoRemoteDirs
	 
	 variable Aud_title
	 variable Aud_Exp1
	 variable Aud_Exp2
	 variable Aud_button
	 variable Aud_filtre

	 variable Imp_title
	 variable Imp_selected
	 variable Imp_NoExpSel
	 variable Imp_ExpName
	 variable Imp_ExpSubD
	 variable Imp_ExpDest
	 variable Imp_ExpGit
	 variable Imp_Parametres
	 variable Imp_Overwrite
	 variable Imp_Ok
	 variable Imp_Ko
	 variable Imp_NoConstants
	 
	 variable Pref_title
	 variable Pref_depot_title
	 variable Pref_window_size
	 variable Pref_exp_icon
	 variable Pref_wallpaper
	 
	 variable NotB_ExpDepot
	 variable NotB_TextEdit
	 variable NotB_Browsers
	 variable NotB_Konsole
	 variable NotB_Events
	 variable NotB_WallIco

         variable XpB_flowmgr 
         variable XpB_xflow 
         variable XpB_import 
         variable XpB_audit
         variable XpB_exptime
         variable XpB_overv
         variable XpB_xpbrowser
         
	 variable XpB_MyExp
	 variable XpB_OpExp
	 variable XpB_PaExp
	 variable XpB_PoExp
         
	 variable Bug_message
	 variable Bug_title 

         variable All_experience
         
          if {[info exists ::env(CMCLNG)] == 0 || $::env(CMCLNG) == "english" } {
	          set XPM_ApplicationName "Experiment manager"
	          set Dlg_NoExpPath "The Path You provided does not contain any valid Experiments!"
	          set Dlg_NoValExpPath "The Path You provided is not Valid!"
	          set Dlg_ExpPathInList "The Path You provided is already in the list!"
	          set Dlg_UpdateExpBrowser "Do you want to Update the Experiment Browser?"
		  set Dlg_NoAsciiFile "Not An Ascii File"
		  set Dlg_DefineExpPath "Define Your Experiment Depot if you have one: Preferences->SetUp Preferences->Experiments Depot\nor create a New Exp."
		  set Dlg_NodeNotExists "Node Do not Exists !"
		  set Dlg_TreeNotExists "Tree Do not Exists !"
		  set Dlg_NonRecognizedPref "You have a non-recognized Preference in your  $::env(HOME)/.maestrorc"
		  set Dlg_ErrorParseConfigOP "Please ask CMOI to check the syntax in file \$SEQ_MANAGER_BIN/../etc/config/Operational_Exp.cfg"
		  set Dlg_PathDeep "This path is too Deep to look for Experiments"
		  set Dlg_DefaultBrowser "You Default browser has been configured to firefox"
		  set Dlg_DefaultKonsole "You Default konsole has been configured to xterm"
		  set Dlg_ErrorAudit2Exp "You must give 2 Experiments"
		  set Dlg_AddPath "Your should consider adding another directory level to your path to easly find Experiments" 
		  set Dlg_CreatePath "Directory will be created "
		  set Dlg_Error_parsing_user_file "There is an Error in your ~/.maestrorc file ... please check"
		  set Dlg_PathNotOwned "You dont have permissions to write into this path"
		  set Dlg_BrowserUpdated "Experiment Browser Updated !"
		  set Dlg_NotUnderHOME "Experiment depot must not be directly under \$HOME"
		  set Dlg_DepotNotExist "Your Experiment depot does not exist!"
		  set Dlg_ExpInvalidName "Invalid caracters in Exp. name.\nAccpeted are: a-zA-Z0-9-_."
		  set Dlg_NameEntryMod "You must provide the name of the Entry Module"
		  set Dlg_ModInvalidName "Invalides caracters in Entry module name.\nAccpeted are: a-zA-Z0-9-_."
		  set Dlg_NewExpPath "You must provide the destination path of the Experiment"
		  set Dlg_ExpPathInvalid "Invalid caracters in destination path.\nAccepted are:A-Za-z0-9_-./"
		  set Dlg_ExpNameMiss "You must give the Experiment Name"
		  set Dlg_ExpDateInvalid "Invalid caracter in ExpDate"
		  set Dlg_CatchupInvalid "Invalid caracter in Catchup value"
		  set Dlg_NumCarCatchup "Invalid number of digit, should be 1 or 2"
		  set Dlg_ExpExiste "Experiment already existe ... Please remove"
	          set Gui_selectedExp "Selected Experiment"
	          set Gui_ControlExp "Experiment Control"
	          set Gui_ExpName "Name"
	          set Gui_ExDatep "Date"
	          set Gui_ExpCatchup "Catchup"
	          set Nbk_MyExp "My_experiments"
	          set Nbk_OpExp "Operational"
	          set Nbk_PaExp "Parallel"
	          set Nbk_PrExp "Pre-operational"
	          set New_ExpTitle "Create New Experiment"
	          set New_ExpName "Experiment Name"
	          set New_ExpSubD "Experiment Sub-directories"
	          set New_ExpDest "Experiment destination path"
	          set New_ExpEnMo "Experiment Entry Module Name"
                  set New_ExpResFile "Experiment Resource File (optional)"
                  set New_ExpRemoteWarning "Warning: if hub, modules, sequencing, resources or listings are set to remote,\nthen they need to be visible from all execution hosts. However, for listings and hub,\nthe host-specific links underneath do not need to be visible. "
	          set New_Dirs "Experiment Directories"
	          set New_DirName "Directory name"
	          set New_Pointto "Point to"
	          set New_Parametres "New Experiment Parametres"
		  set New_NoRemoteDirs "Some Remote Directories are not defined!:"
	          set Aud_title "Audit Experiments"
	          set Aud_Exp1 "Experiment 1"
	          set Aud_Exp2 "Experiment 2"
	          set Aud_button "Audit All"
		  set Aud_filtre "Filter"
	          set Imp_title "Import Experiment(s)"
	          set Imp_selected "Experiment to Import"
	          set Imp_ExpName "New Experiment name"
	          set Imp_ExpSubD "Experiment Sub-directories"
	          set Imp_ExpDest "Experiment destination path"
		  set Imp_ExpGit  "Import Git/Constante Files"
	          set Imp_Parametres "Experiment(s) to import"
		  set Imp_NoConstants "There is No Constants files!"
		  set Imp_NoExpSel "No Experiment Selected!"
		  set All_experience "Experiment" 
		  set Imp_Overwrite "An (a family of) experiment(s) already exist with this name. Do you want to overwrite it?"
		  set Imp_Ok "Import Successful"
		  set Imp_Ko "There are Error in the Import action ... Please examine listing"
		  set Pref_title "Preferences Setting"
	          set NotB_ExpDepot "Experiments Depot"
	          set NotB_TextEdit "Text Editors"
	          set NotB_Browsers "Browsers"
	          set NotB_Konsole "Konsoles"
	          set NotB_Events  "Events"
	          set NotB_WallIco "Wallpapers and icons"
                  set XpB_flowmgr "Flow manager"
                  set XpB_xflow "Run time flow"
                  set XpB_import "Import"
                  set XpB_audit "Audit with"
                  set XpB_exptime "Exp. Timing"
                  set XpB_overv "Add to Overview"
		  set Bug_message "Launch Bugzilla"
		  set Bug_title "Submit a bug Report"
	          set Pref_window_size "Xflow window size"
	          set Pref_exp_icon "Experiment icon"
	          set Pref_wallpaper "Wallpaper image for Xflow"
		  set Pref_depot_title "Experiments Depot Configuration"
		  set XpB_xpbrowser "Experiment Browser"
	          set XpB_MyExp "My_experiments"
	          set XpB_OpExp "Operational"
	          set XpB_PaExp "Parallel"
	          set XpB_PoExp "Pre-operational"
		  set Dlg_ProvideExpPath "You must Provide A correct path of an Experiment"
          } else {
	          set XPM_ApplicationName "Gestionnaire d'experiences"
	          set Dlg_NoExpPath "Le Chemin que vous avez fournis ne contient aucune Experience valide!"
	          set Dlg_NoValExpPath "Le Chemin que vous avez fournis n'est pas Valid!"
	          set Dlg_ExpPathInList "Le Chemin que vous avez fournis est deja dans la liste!"
	          set Dlg_UpdateExpBrowser "Voulez-vous rafraichir le navigateur des Experiences ?"
		  set Dlg_NoAsciiFile "Le fichier n'est pas de format Ascii"
		  set Dlg_DefineExpPath "Definir Votre depot d'Experiences si vous en avez: Experiences->Depot ou\ncreer une Nouvelle Experience"
		  set Dlg_NodeNotExists "Le noeud n'existe pas !"
		  set Dlg_TreeNotExists "L'arbre n'existe pas !"
		  set Dlg_NonRecognizedPref "Vouz avez une variable de Preference qui n'est pas reconnue dans $::env(HOME)/.maestrorc"
		  set Dlg_ErrorParseConfigOP "SVP demander a CMOI de verifier la syntaxe du fichier \$SEQ_MANAGER_BIN/../etc/config/Operational_Exp.cfg"
		  set Dlg_PathDeep "Ce Repertoire est trop profond pour trouver les Experiences"
		  set Dlg_DefaultBrowser "Votre fureteur par default est firefox"
		  set Dlg_DefaultKonsole "Votre konsole par default est xterm"
		  set Dlg_ErrorAudit2Exp "Vous devez fournir 2 Experiences"
		  set Dlg_AddPath "Vous devriez ajouter un autre repertoire pour faciliter la recherche des experiences" 
		  set Dlg_CreatePath "Le repertoire va etre creer "
		  set Dlg_Error_parsing_user_file "Il y'a une erreure dans votre fichier  \$HOME/.maestrorc  ... svp verifier"
		  set Dlg_PathNotOwned "Vous n'avez pas la permission d'ecrire dans ce repertoire"
		  set Dlg_BrowserUpdated "Le Navigateur d'experiences est mis a jour!"
		  set Dlg_NotUnderHOME "Le depot des Experiences ne doit pas se situer directement sous le \$HOME"
		  set Dlg_DepotNotExist "Votre depot des Experiences n'existe pas!"
		  set Dlg_ExpInvalidName "Caracteres invalides dans le nom de l'experience.\nAcceptes sont:a-zA-Z0-9-_."
		  set Dlg_ModInvalidName "Caracteres invalides dans le nom du module d'entree.\nAcceptes sont:a-zA-Z0-9-_."
		  set Dlg_NameEntryMod "Vous devez fournir le nom du module d'entreede l'experience"
		  set Dlg_NewExpPath "Vous devez fournir le chemin de destination de l'experience"
		  set Dlg_ExpPathInvalid "Caracters invalides dans le chemin de destination de l'experience.\nAcceptee sont:A-Za-z0-9_-./"
		  set Dlg_ExpNameMiss "Vous devez fournir le nom de l'experience"
		  set Dlg_ExpDateInvalid "Caractere invalide dans la valeur de ExpDate"
		  set Dlg_CatchupInvalid "Caracter invalide dans la valeur de Catchup"
		  set Dlg_NumCarCatchup "la valeur doit comporter au maximum 2 chiffres"
		  set Dlg_ExpExiste "l'Experience existe deja SVP enlever"
	          set Gui_selectedExp "Experience Selectionnee"
	          set Gui_ControlExp "Controle de l'Experience"
	          set Gui_ExpName "Nom"
	          set Gui_ExDatep "Date"
	          set Gui_ExpCatchup "Catchup"
	          set Nbk_MyExp "My_experiments"
	          set Nbk_OpExp "Operational"
	          set Nbk_PaExp "Parallel"
	          set Nbk_PrExp "Pre-operational"
	          set New_ExpTitle "Creer Une Nouvelle experience"
	          set New_ExpName "Nom de L'experiences"
	          set New_ExpSubD "Sous-repertoires de l'exprience"
	          set New_ExpDest "Chemin de Destination de l'experience"
	          set New_ExpEnMo "Module d'entree de l'experience"
                  set New_ExpResFile "Fichier de ressource de l'experience (optionnel)"
                  set New_ExpRemoteWarning "Attention: si hub, modules, sequencing, resources ou listings sont places en remote,\nils doivent etre visibles par tous les hosts qui executent l'experience. Par contre, pour listings and hub,\nles liens specifiques du host n'ont pas besoin d'etre visibles. "
	          set New_Dirs "Repertoires de l'experience"
	          set New_DirName "Nom du repertoire"
	          set New_Pointto "Pointe a"
	          set New_Parametres "Parametres de la nouvelle experience"
		  set New_NoRemoteDirs "Des repertoires non-locaux ne sont pas definis!:"
	          set Aud_title "Audit des experiences"
	          set Aud_Exp1 "Experience 1"
	          set Aud_Exp2 "Experience 2"
	          set Aud_button "Audit tous"
		  set Aud_filtre "Filtre"
	          set Imp_title "Importer des experiences"
	          set Imp_selected "Experience a Importer"
	          set Imp_ExpName "Nouveau nom de l'experience"
	          set Imp_ExpSubD "Sous-repertoire de l'experience"
	          set Imp_ExpDest "Destination de l'experience"
		  set Imp_ExpGit  "Importer Git/Fichiers des constantes"
	          set Imp_Parametres "Experience(s) a Importer"
		  set Imp_NoConstants "Il n'y a pas de fichiers de constantes!"
		  set Imp_NoExpSel "Pas d'Experience Selectionnee!"
		  set All_experience "Experience" 
		  set Imp_Overwrite "Une(famille) Experience(s) Existe deja avec ce nom. Voudriez vous l'effacer ?"
		  set Imp_Ok "Experience(s) Importe(es) avec succes!"
		  set Imp_Ko "Il y'a des erreurs dans l'operation d'import ... svp examinez le listing"
		  set Pref_title "Configuration des preferences"
	          set NotB_ExpDepot "Depot des Experiences"
	          set NotB_TextEdit "Editeurs text"
	          set NotB_Browsers "Fureteurs"
	          set NotB_Konsole "Consoles"
	          set NotB_Events  "Evenements"
	          set NotB_WallIco "Fond d'ecran et icones"
                  set XpB_flowmgr "Gestionnaire du flow"
                  set XpB_xflow "Execution du flow"
                  set XpB_import "Importer"
                  set XpB_audit "Audit avec"
                  set XpB_exptime "Temps Exp."
                  set XpB_overv "Ajouter dans l'Overview"
		  set Bug_message "Lancer bugzilla"
		  set Bug_title "Soumettre un bogue"
		  set Pref_depot_title "Configuration du depot des Experiences"
	          set Pref_window_size "Taille d'ecran de Xflow"
	          set Pref_exp_icon "Icone d'une experience"
	          set Pref_wallpaper "Image de fond pour Xflow"
		  set XpB_xpbrowser "Navigateur d'Experiences"
	          set XpB_MyExp "My_experiments"
	          set XpB_OpExp "Operational"
	          set XpB_PaExp "Parallel"
	          set XpB_PoExp "Pre-operational"
		  set Dlg_ProvideExpPath "Vous devriez fournir le chemin d'une Experience"
	  }
}

#---------------------------------------------------------------
# icons -> error, info, question or warning. 
# type  -> abortretryignore 3 buttons : abort, retry and ignore.
#         ok
#         okcancel     -> 2 but  ok , cancel
#         retrycancel  -> 2 but 
#         yesno        -> 2 but 
#         yesnocancel  -> 3 but 
#         user         -> Displays buttons of -buttons option.
#---------------------------------------------------------------
proc Dialogs::show_msgdlg { Mess type icon butt parent } {
    variable msg

    destroy .msgdlg_win
    MessageDlg .msgdlg_win -parent $parent \
        -message $Mess \
        -type    $type \
        -icon    $icon \
        -buttons $butt

}

