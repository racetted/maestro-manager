#!/bin/ksh
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
