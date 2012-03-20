#!/bin/ksh

#eval `ssmuse sh -d ~afsissm/domain2 -p xflow_1.0.9_all` 

puts "sua new... xflow"
export SEQ_EXP_HOME=$1
if [[ "${SEQ_XFLOW_BIN}" == "" ]]; then 
   echo "SEQ_XFLOW_BIN not defined..."
   errMsg="SEQ_XFLOW_BIN not defined, cannot start xflow!"
   kdialogFound=0
   test $(which kdialog) && kdialogFound=1
   if [[ ${kdialogFound} == "1"  ]] ; then
      kdialog --title "xflow Startup Error" --error "${errMsg}"
   else
      echo ${errMsg}
   fi
   exit 1
else
   ${SEQ_XFLOW_BIN}/xflow
fi
