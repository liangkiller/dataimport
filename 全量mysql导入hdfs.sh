#!/bin/bash
#全量更新

#环境设置:u 不存在的变量报错;e 发生错误退出;pipefail 管道有错退出
set -euo pipefail

#########要更改变的变量#######
#mysql数据库信息
MYSQL_HOST=""
MYSQL_PORT=""
MYSQL_USER=''
MYSQL_PASS=''
MYSQL_DB=''
MYSQL_TABLE=''

#mysql查询命令
mysqlQuery="select * from ${MYSQL_DB}.${MYSQL_TABLE};"

#hive数据库信息
HIVE_DB=""
HIVE_TABLE=""

#hive路径
HIVE_DIR="/user/hive/warehouse"
HIVE_DB_PATH="${HIVE_DIR}/${HIVE_DB}/${HIVE_TABLE}"
HIVE_FILE_NAME="${HIVE_TABLE}.txt"
HIVE_TABLE_PATH="${HIVE_DB_PATH}/${HIVE_FILE_NAME}"

#hive sql信息
HIVE_LIMIT=10
hiveSelectSql="use ${HIVE_DB};select count(*) from ${HIVE_TABLE};select * from ${HIVE_TABLE} limit ${HIVE_LIMIT};"

#hadoop命令运行用户
CMD_PRE="sudo -u hdfs "

#临时文件目录
TMP_DIR="/var/tmp"
md5=`echo -n "${MYSQL_TABLE}"|md5sum|cut -d ' ' -f1`

#压缩:1 开启;0 关闭
COMPRESS=1
###############################
#hadoop命令
CDM_HADOOP=${CMD_PRE}" hadoop fs "
CDM_HIVE=${CMD_PRE}" hive "

echo "=======hadoop 路径========"
echo "$HIVE_DB_PATH"

echo "=======全量更新${MYSQL_TABLE}到${HIVE_DB_PATH}========"
cd ${TMP_DIR}
TMP_SAVE_NAME="${MYSQL_TABLE}-$md5.txt"
TMP_SAVE_PATH="${TMP_DIR}/${TMP_SAVE_NAME}"

echo "=======导出数据文件========"
rm -f ${TMP_SAVE_NAME}
echo "mysql -N -u${MYSQL_USER} -p\"${MYSQL_PASS}\" -h${MYSQL_HOST} -P${MYSQL_PORT} -D ${MYSQL_DB} --default-character-set=utf8   -e \"$mysqlQuery\"  | sed 's/\t/|/g;' > ${TMP_SAVE_PATH}"

mysql -N -u${MYSQL_USER} -p"${MYSQL_PASS}" -h${MYSQL_HOST} -P${MYSQL_PORT} -D ${MYSQL_DB} --default-character-set=utf8   -e "$mysqlQuery"  | sed 's/\t/|/g;' > ${TMP_SAVE_PATH}

if [ $COMPRESS -ne 0 ]
then
    echo "=======压缩数据文件========"
    echo "bzip2 -k ${TMP_SAVE_NAME}"
    bzip2 -k ${TMP_SAVE_NAME}
    TMP_SAVE_NAME=${TMP_SAVE_NAME}.bz2
    HIVE_FILE_NAME="${HIVE_TABLE}.bz2"
    HIVE_TABLE_PATH="${HIVE_DB_PATH}/${HIVE_FILE_NAME}"
fi

echo "=======导入hadoop========"
set +e
echo "${CDM_HADOOP} -rm -r ${HIVE_DB_PATH}"
echo "${CDM_HADOOP} -mkdir -p ${HIVE_DB_PATH}"
echo "${CDM_HADOOP} -copyFromLocal ${TMP_SAVE_NAME} ${HIVE_TABLE_PATH}"
${CDM_HADOOP} -rm -r ${HIVE_DB_PATH}
${CDM_HADOOP} -mkdir -p ${HIVE_DB_PATH}
${CDM_HADOOP} -copyFromLocal ${TMP_SAVE_NAME} ${HIVE_TABLE_PATH}
set -e

echo "=======hive显示========"
echo "${CDM_HIVE} -e \"$hiveSelectSql\""
${CDM_HIVE} -e "$hiveSelectSql"
