package require tooltip
package require BWidget 1.9

proc MaestroCenter_expSelected { _sourceWidget _expPath } {
   global errorInfo
   puts "MaestroCenter_expSelected 0:$_sourceWidget 1:$_expPath"
   if { [ catch { ExpModTreeControl_init ${_sourceWidget} ${_expPath} } errMsg ] } {
      puts ${errorInfo}
      MessageDlg .msg_window -icon error -message "${errMsg}" -aspect 400 \
         -title "Application Error" -type ok -justify center -parent ${_sourceWidget}
      MaestroConsole_addErrorMsg ${errMsg}
   }
}

#global env ACTIVE_EXP ErrorMsgDb
#set ErrorMsgDb error_db
#if { ! [info exists env(SEQ_MANAGER_BIN) ] } {
#   MessageDlg .msg_window -icon error -message "The variable SEQ_MANAGER_BIN is not defined!" -aspect 400 \
#      -title "" -type ok -justify center -parent ${_sourceWidget}
#   return
#}

#puts "SEQ_MANAGER_BIN=$env(SEQ_MANAGER_BIN)"

set lib_dir $env(SEQ_MANAGER_BIN)/../lib
set auto_path [linsert $auto_path 0 $lib_dir ]

#wm iconify .

#ErrorMessages_init

#if { [info exists env(SEQ_EXP_HOME)] } {
#   set ACTIVE_EXP $env(SEQ_EXP_HOME)
#   wm withdraw .
#   MiscTkUtils_InitPosition .
#} {
#   puts "\nERROR:SEQ_EXP_HOME variable not found!"
#   exit
#}

SharedData_init
SharedData_setMiscData IMAGE_DIR $env(SEQ_MANAGER_BIN)/../etc/images
MaestroConsole_init
#MaestroCenter_expSelected . ${ACTIVE_EXP}

#ModuleFlow_readXml ${ACTIVE_EXP}/EntryModule/flow.xml

#set modCanvas [canvas .canvas -relief raised]
#grid ${modCanvas} -row 0 -column 0 -sticky nsew


