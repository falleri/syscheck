#!/bin/bash
#                817-delete-old-record-CRLData.sh - Delete old crldata from ejbca db
#
# create a yearly backup if you want (y/n)
# creat mysqldump of crldata table
# can be run on backend and frontend
# need tyo have working database owner account eq to ejcbca and certcerviceadmin, can be founfd in common.conf
# can be checked with  814-mysql-console-as-db-user.sh
# Get row number to delete to
# Delete old record from crldata use argument for how many rows to keep, not less then 5
# make backup of crldata db.

# Set SYSCHECK_HOME if not already set.

# 1. First check if SYSCHECK_HOME is set then use that
if [ "x${SYSCHECK_HOME}" = "x" ] ; then
# 2. Check if /etc/syscheck.conf exists then source that (put SYSCHECK_HOME=/path/to/syscheck in ther)
 if [ -e /etc/syscheck.conf ] ; then
 source /etc/syscheck.conf
 else
# 3. last resort use default path
 SYSCHECK_HOME="/opt/syscheck"
 fi
fi
if [ ! -f ${SYSCHECK_HOME}/syscheck.sh ] ; then echo "$0: Can't find syscheck.sh in SYSCHECK_HOME ($SYSCHECK_HOME)" ;exit ; fi

## Import common definitions ##
. $SYSCHECK_HOME/config/database-replication.conf

# uniq ID of script (please use in the name of this file also for convinice for finding next availavle number)
SCRIPTID=817

# Index is used to uniquely identify one test done by the script (a harddrive, crl or cert)
SCRIPTINDEX=00

getlangfiles $SCRIPTID || exit 1;
getconfig $SCRIPTID || exit 1;
schelp () {
 echo
        echo "$HELP"
        echo
        echo "${SCRIPTID}1/$DESCR_1 - $HELP_1"
        echo "${SCRIPTID}2/$DESCR_2 - $HELP_2"
        echo "${SCRIPTID}3/$DESCR_3 - $HELP_3"
        echo "${SCRIPTID}4/$DESCR_4 - $HELP_4"
        echo "${SCRIPTID}5/$DESCR_5 - $HELP_5"
        echo "${SCRIPTID}6/$DESCR_6 - $HELP_6"
        echo "${SCRIPTID}7/$DESCR_7 - $HELP_7"
        echo "${SCRIPTID}8/$DESCR_8 - $HELP_8"
        echo "${SCRIPTID}9/$DESCR_9 - $HELP_9"
        echo "${SCRIPTID}10/$DESCR_10 - $HELP_10"
        echo "${SCREEN_HELP}"
        exit
}


PRINTTOSCREEN=0

if [ "x$1" = "x-h" -o "x$1" = "x--help" ] ; then
        schelp
elif [ "x$1" = "x-s" -o  "x$1" = "x--screen" -o \
    "x$2" = "x-s" -o  "x$2" = "x--screen"   ] ; then
        PRINTTOSCREEN=1
elif [ "x$1" = "x-q" -o  "x$1" = "x--quiet" -o \
    "x$2" = "x-q" -o  "x$2" = "x--quiet"   ] ; then
        PRINTTOSCREEN=0
elif [ "x$1" = "x-m" -o  "x$1" = "x--menu" -o \
    "x$2" = "x-m" -o  "x$2" = "x--menu"   ] ; then
        MENU=1
elif [ "x$1" = "x-b" -o  "x$1" = "x--batch" -o \
    "x$2" = "x-b" -o  "x$2" = "x--batch"   ] ; then
        MENU=0
fi
if [ "x$MENU" = x ];then
  echo "Need to set value -b or -m to run, exit"
  exit
fi

DATE=`date +%Y%m%d-%H%M`
DATAFILE="$SYSCHECK_HOME/var/${SCRIPTID}.out"
OUTFILE="$SYSCHECK_HOME/var/${SCRIPTID}.sql"
LOGFILE="$SYSCHECK_HOME/var/${DATE}_${SCRIPTID}.log"
ERRFILE="$SYSCHECK_HOME/var/${SCRIPTID}.err"
RUNBYE=`who |grep "\`ps |awk '{print $2}'\`"|awk '{print $1}'`
echo "`date`:Start deleting CRL, ${RUNBYE}" >${LOGFILE}
###############
# Error rutin
Sub_Error(){
if [ $ERR != 0 ] ; then
###echo $ERR
echo "error in subrutin $1"
##cat ${ERRFILE}.$1
printlogmess ${SCRIPTID} ${SCRIPTINDEX}   ${LEVEL} ${SCRIPTID}$1 "${DESCR}"
exit $ERR
fi
}
###############
ERR=0
test -z "${ROW_SAVE}" && ERR=1
LEVEL=${LEVEL_1}
DESCR=${DESCR_1}
Sub_Error 1
test ${ROW_SAVE} -lt 5 && ERR=2
LEVEL=${LEVEL_2}
DESCR=${DESCR_2}
Sub_Error 2
###############
# Check value on enviroment, cant  be null
if [ -z  ${RUN_DELETE} ] ; then
echo "Check value on RUN_DELETE in ../config/817.conf"
exit
fi
echo ${DB_NAME}|egrep "ejbca|certservice"
if [ $? != 0 ];then
  echo " No support for database named: ${DB_NAME}"
  echo "Exit"
  exit
fi
Sub_BCK(){
###############
# create backup before starting job
if [ ${PRINTTOSCREEN} = 1 ] ; then
  echo "$SYSCHECK_HOME/related-enabled/904_make_mysql_db_backup.sh -b "
fi
echo "`date`:Start ">>${LOGFILE}
echo "`date`:Create backup before clean crldata">>${LOGFILE}
$SYSCHECK_HOME/related-enabled/904_make_mysql_db_backup.sh -b 2>${ERRFILE}.3
ERR=$?
LEVEL=${LEVEL_3}
DESCR=${DESCR_3}
Sub_Error 3

SCRIPTINDEX=$(addOneToIndex $SCRIPTINDEX)
echo "`date`:End backup ">>${LOGFILE}

##############
SCRIPTINDEX=$(addOneToIndex $SCRIPTINDEX)
}

##############
# Get all issuerDN, need to now for deleteing for each issuerDN
Sub_Get_Issuer(){
if [ ${DB_NAME} = ejbca ]; then
        echo "select distinct issuerDN from CRLData ;"
        if [ ${PRINTTOSCREEN} = 1 ] ; then
                echo "select distinct issuerDN from CRLData order by issuerDN ;"
                echo ""
        fi
echo "USE $DB_NAME;" > ${OUTFILE}.4
echo "select distinct issuerDN from CRLData order by issuerDN;" >> ${OUTFILE}.4
TABLE_NAME=CRLData
COLUMN_ISSUER=issuerDN
SERIALNUMBER=cRLNumber
elif
  [ ${DB_NAME} = certservice ]; then
        if [ ${PRINTTOSCREEN} = 1 ] ; then
                echo "select distinct issuer_id from credential_status_list order by issuer_id ;"
                echo ""
        fi
         echo "USE $DB_NAME;" > ${OUTFILE}.4
         echo "select distinct issuer_id from credential_status_list order by issuer_id ;">> ${OUTFILE}.4
TABLE_NAME=credential_status_list
COLUMN_ISSUER=issuer_id
SERIALNUMBER=serial_number
else
  echo " Do not suppport ${DB_NAME} database exist, exit"
  LEVEL=${LEVEL_4}
  DESCR=${DESCR_4}
  Sub_Error 4
  exit
fi
$MYSQL_BIN --skip-column-names $DB_NAME -u root --password=$MYSQLROOT_PASSWORD < ${OUTFILE}.4 >${DATAFILE}
ERR=$?
LEVEL=${LEVEL_4}
DESCR=${DESCR_4}
Sub_Error 4
}
Sub_Bckcrldata(){
DATE=`date +'%Y-%m-%d_%H.%M.%S'`
MYSQLBACKUPDIR=/backup/mysql/
dumpret=$($MYSQLDUMP_BIN -u root --password="${MYSQLROOT_PASSWORD}" ${DB_NAME} ${TABLE_NAME} |gzip > ${MYSQLBACKUPDIR}/default/crldata${DATE}sql.gz)
if [ $? -ne 0 ] ; then
        printlogmess ${SCRIPTID} ${SCRIPTINDEX}   $ERROR $ERRNO_4 "$DESCR_4" "$dumpret"
        exit
fi
}

Sub_Last_CRL(){
echo "Show last CRL of Issuer "
echo "Format issuer and serialnumber"
echo "Just wait,,,"
#TABLE_NAME=credential_status_list
#COLUMN_ISSUER=issuer_id
#SERIALNUMBER=serial_number
#--skip-column-names
echo "Sernum  Issuer" > ../var/SerialnumberCRL
cat ${DATAFILE}|while read ISSUERDN
do
   ROWS=`echo "SELECT $SERIALNUMBER,${COLUMN_ISSUER} from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}'order by $SERIALNUMBER desc Limit 1;" | $MYSQL_BIN  --skip-column-names $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} `
   echo "$ROWS" >>../var/SerialnumberCRL
done
}

Sub_Count_CRL(){
echo "Count Crl for issuer, show list of Issuer with most CRL"
echo "Just wait,,,"
rm -f ../var/CRLLISTA
cat ${DATAFILE}|while read ISSUERDN
do
   ROWS=`echo "SELECT count(*) from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}';" | $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} |grep -v count `
   echo "$ROWS;${ISSUERDN}" >>../var/CRLLISTA
done
echo "List of serialnumber on crl:s"
echo "============================="
cat ../var/SerialnumberCRL
echo ""
echo "-----------------------------"
echo "List CA with most CRL:s"
echo "======================="
sort -n ../var/CRLLISTA | tail -10
}
Sub_Meny(){
#cat ${DATAFILE} |cut -f3 -d"="| sort |uniq
# Displays a list of O=organisation

# Set the prompt for the select command
PS3="Type a number or 'q' to quit, or press return to main menu: "

# Create a list of files to display
fileList=$( cat ${DATAFILE} |cut -f3 -d"="| sort |uniq )
# Show a menu and ask for input. If the user entered a valid choice,
# then invoke the editor on that file
#select fileName in $fileList; do
OIFS=$IFS
IFS="
"
select fileName in `cat ${DATAFILE} |cut -f3 -d"="| sort |uniq`; do
IFS=$OIFS
    if [ -n "$fileName" ]; then
        YESNO=Y
        echo " Choose organistation: ${fileName}"
IFS="
"
        #select CA in `egrep "${fileName}" ${DATAFILE}|sort`;do
        select CA in `egrep "${fileName}" ../var/CRLLISTA|sort`;do
        if [ -n "$CA" ]; then
                YESNO=Y
                echo " Choose CA: ${CA}"
                read -r -p "Are you sure? [y/N] " response
                        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
                                then
                                echo "remove CRL from: ${CA}"
                                Sub_Clean_CRL `echo ${CA}|cut -f2 -d";"`
IFS=$OIFS
                        else
                                break
                        fi
        break
        fi
        done
    else
    break
    fi
done

}
Sub_Clean_CRL(){
#TABLE_NAME=CRLData
#COLUMN_ISSUER=issuerDN
ISSUERDN=$1
 ROWS_BEFORE=`echo "SELECT count(*) from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}';" | $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} |grep -v count `
 echo "`date`:Before $RUNBYE:$ISSUERDN,$ROWS_BEFORE" |tee -a ${LOGFILE}
 echo "USE $DB_NAME;" > ${OUTFILE}.5
   echo "select $SERIALNUMBER from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}' order by $SERIALNUMBER desc Limit ${ROW_SAVE};" >> ${OUTFILE}.5
   ROWNUM=`$MYSQL_BIN $DB_NAME -u ${DB_USER} --password=$DB_PASSWORD < ${OUTFILE}.5 |tail -1`
   ERR=$?
   LEVEL=${LEVEL_5}
   DESCR=${DESCR_5}
   Sub_Error 5
   echo "`date`:$RUNBYE:Remove rows from ${ISSUERDN} current rows:${ROWS} delete until Crlnumber:${ROWNUM}">>${LOGFILE}
   echo "`date`:$RUNBYE:Current rows;${ROWS_BEFORE} :Delete until Crlnumber:${ROWNUM} where issuer is:${ISSUERDN}">>${LOGFILE}

 if [ ${RUN_DELETE} = "Yes" ] ; then
      echo "USE $DB_NAME;" > ${OUTFILE}.6
      echo "delete from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}' and $SERIALNUMBER < ${ROWNUM};" >> ${OUTFILE}.6
      #cat  ${OUTFILE}.6 >>${LOGFILE}
      $MYSQL_BIN $DB_NAME -u root --password=$MYSQLROOT_PASSWORD < ${OUTFILE}.6  >${ERRFILE}.6
      ERR=$?
   else
      echo ":$RUNBYE: NO DELETE:delete from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}' and $SERIALNUMBER < ${ROWNUM};" >> ${LOGFILE}
      ERR=$?
   fi
   LEVEL=${LEVEL_6}
   DESCR=${DESCR_6}
   Sub_Error 6
   ROWS=`echo "SELECT count(*) from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}';" | $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} |grep -v count `
   echo "`date`:After $RUNBYE:$ISSUERDN,$ROWS" |tee -a ${LOGFILE}
   sed -i "s/$ROWS_BEFORE;$ISSUERDN/$ROWS;$ISSUERDN/" ../var/CRLLISTA
}
Sub_Clean_CRL_Batch(){
# Get number of row to delete to desending from each issuerDN
echo "Run cleaning in batch mode, just wait...."
cat ${DATAFILE}|while read ISSUERDN
do
   ROWS=`echo "SELECT count(*) from ${TABLE_NAME} where $COLUMN_ISSUER='${ISSUERDN}';" | $MYSQL_BIN $DB_NAME  -u ${DB_USER} --password=${DB_PASSWORD} |grep -v count `
   if [ ${PRINTTOSCREEN} = 1 ] ; then
      echo "select ${SERIALNUMBER} from ${TABLE_NAME} where $COLUMN_ISSUER='${ISSUERDN}' order by ${SERIALNUMBER} desc Limit ${ROW_SAVE};"
      echo ""
   fi
   echo "USE $DB_NAME;" > ${OUTFILE}.5
   echo "select ${SERIALNUMBER} from ${TABLE_NAME} where $COLUMN_ISSUER='${ISSUERDN}' order by ${SERIALNUMBER} desc Limit ${ROW_SAVE};" >> ${OUTFILE}.5
   ROWNUM=`$MYSQL_BIN $DB_NAME -u ${DB_USER} --password=$DB_PASSWORD < ${OUTFILE}.5 |tail -1`
   ERR=$?
   LEVEL=${LEVEL_5}
   DESCR=${DESCR_5}
   Sub_Error 5
   echo "`date`:Remove rows from ${ISSUERDN} current rows:${ROWS} delete until Crlnumber:${ROWNUM}">>${LOGFILE}
   echo "`date`:Current rows;${ROWS} :Delete until Crlnumber:${ROWNUM} where $COLUMN_ISSUER is:${ISSUERDN}">>${LOGFILE}

##############
# Delete row
   if [ ${PRINTTOSCREEN} = 1 ] ; then
      echo "delete from ${TABLE_NAME} where  $COLUMN_ISSUER=${ISSUERDN} and ${SERIALNUMBER} < ${ROWNUM};"
      echo ""
   fi
   if [ ${RUN_DELETE} = "Yes" ] ; then
      echo "USE $DB_NAME;" > ${OUTFILE}.6
      echo "delete from ${TABLE_NAME} where $COLUMN_ISSUER='${ISSUERDN}' and ${SERIALNUMBER} < ${ROWNUM};" >> ${OUTFILE}.6
      cat  ${OUTFILE}.6 >>${LOGFILE}
      $MYSQL_BIN $DB_NAME -u root --password=$MYSQLROOT_PASSWORD < ${OUTFILE}.6  >${ERRFILE}.6
      ERR=$?
   else
      echo "delete from ${TABLE_NAME} where $COLUMN_ISSUER='${ISSUERDN}' and ${SERIALNUMBER} < ${ROWNUM};" >> ${LOGFILE}
      ERR=$?
   fi
   LEVEL=${LEVEL_6}
   DESCR=${DESCR_6}
   Sub_Error 6
   ROWS_AFTER=`echo "SELECT count(*) from ${TABLE_NAME} where $COLUMN_ISSUER='${ISSUERDN}';" | $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} |grep -v count `
   echo "`date`:New value rows;${ROWS_AFTER}  where $COLUMN_ISSUER is:${ISSUERDN}" >>${LOGFILE}
   echo "`date`:Remove rows from ${ISSUERDN} done">>${LOGFILE}
   echo "****************************************">>${LOGFILE}
   echo "">>${LOGFILE}
done
}
Sub_Get_Row(){
#############
# Count total number of row:select count(*) from ejbca.$TABLE_NAME;
echo ""
echo "Just wait, take some time,,,,"
echo ""
TOTAL_ROWS=`echo "select count(*) from $DB_NAME.$TABLE_NAME;"| $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} |grep -v count `
TOTAL_SIZE=`echo "SELECT round(((data_length + index_length) / 1024 / 1024),2) \"Size in MB\" FROM information_schema.tables WHERE table_schema = DATABASE() and TABLE_NAME ='$TABLE_NAME' order by data_length;"| $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD}|egrep -v "Size"`
echo "Before clean CRL"
BEFORE="`date`:Totalnumber of row in $DB_NAME.$TABLE_NAME ;${TOTAL_ROWS} and size in Mb;${TOTAL_SIZE}"
echo "`date`:Totalnumber of row in $DB_NAME.$TABLE_NAME ;${TOTAL_ROWS} and size in Mb;${TOTAL_SIZE}"|tee -a ${LOGFILE}
#############
}
Sub_Reclam_space(){
#######################
# Reclame space in table CRLDat£@ejbca
echo " Reclame space in table $DB_NAME.$TABLE_NAME"
cat <<EOF> ${OUTFILE}.7
use $DB_NAME;
OPTIMIZE TABLE $TABLE_NAME;
EOF
$MYSQL_BIN $DB_NAME -u root --password=$MYSQLROOT_PASSWORD < ${OUTFILE}.7  >${ERRFILE}.7
##############
ERR=$?
LEVEL=${LEVEL_7}
DESCR=${DESCR_7}
Sub_Error 7
}

Sub_Last_CRL_After(){
echo "Show last CRL of Issuer "
echo "Format issuer and serialnumber"
echo "Just wait,,,"
#TABLE_NAME=credential_status_list
#COLUMN_ISSUER=issuer_id
#SERIALNUMBER=serial_number
echo "Sernum  Issuer" > ../var/SerialnumberCRL_after
cat ${DATAFILE}|while read ISSUERDN
do
   ROWS=`echo "SELECT $SERIALNUMBER,${COLUMN_ISSUER} from $TABLE_NAME where $COLUMN_ISSUER='${ISSUERDN}' order by $SERIALNUMBER desc Limit 1;" | $MYSQL_BIN --skip-column-names $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} `
   echo "$ROWS" >>../var/SerialnumberCRL_after
done
}

Sub_Check_CRLNumber(){
echo "Shuld be empty, if entry investigate reason"
diff ../var/SerialnumberCRL  ../var/SerialnumberCRL_after
echo "======================="
echo "If empty, same crl number exist"

}

Sub_Count_Row_After(){
#######################
# Count row after job
TOTAL_ROWS_AFTER=`echo "select count(*) from $DB_NAME.$TABLE_NAME;"| $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD} |grep -v count `
TOTAL_SIZE_AFTER=`echo "SELECT round(((data_length + index_length) / 1024 / 1024),2) \"Size in MB\" FROM information_schema.tables WHERE table_schema = DATABASE() and TABLE_NAME ='$TABLE_NAME' order by data_length;"| $MYSQL_BIN $DB_NAME -u ${DB_USER} --password=${DB_PASSWORD}|egrep -v "Size"`
let REMOVE_ROWS=${TOTAL_ROWS}-${TOTAL_ROWS_AFTER}
echo $BEFORE
echo "`date`:Totalnumber of row removed: ${REMOVE_ROWS} remaing rows in $DB_NAME.$TABLE_NAME ;${TOTAL_ROWS_AFTER} and size after ${TOTAL_SIZE_AFTER}"|tee -a ${LOGFILE}
##############
ERR=$?
LEVEL=${LEVEL_8}
DESCR=${DESCR_8}
Sub_Error 8
}
Sub_Backup(){
##############
# backup after crlcleaning
echo "`date`:Create backup after clean crldata">>${LOGFILE}
$SYSCHECK_HOME/related-enabled/904_make_mysql_db_backup.sh -b 2>${ERRFILE}.9
ERR=$?
LEVEL=${LEVEL_9}
DESCR=${DESCR_9}
Sub_Error 9
echo "`date`:Backup end">>${LOGFILE}
echo "`date`:`ls -lhtr /backup/mysql/default/|tail -2`">>${LOGFILE}
}
echo "Run Backup before start (Y/N)"
read dret
if [ ${dret:=Y} = y -o ${dret:=Y} = Y ];then
  Sub_BCK
fi
Sub_Get_Issuer
echo "Create backup of CRLData, take some time, 20 min"
Sub_Bckcrldata
Sub_Get_Row
Sub_Last_CRL
Sub_Count_CRL
if [ $MENU = 1 ];then
Sub_Meny
fi
if [ $MENU = 0 ];then
Sub_Clean_CRL_Batch
fi
Sub_Reclam_space
Sub_Last_CRL_After
Sub_Check_CRLNumber
Sub_Count_Row_After
echo "Run Backup After (Y/n)"
read dret
if [ ${dret:=Y} = y -o ${dret:=Y} = Y ];then
  Sub_Backup
fi
#############
#
# If we got here, the job is finnish
printlogmess ${SCRIPTID} ${SCRIPTINDEX}   $INFO ${SCRIPTID}14 "$DESCR_10 "
echo "`date`:$0 end">>${LOGFILE}
