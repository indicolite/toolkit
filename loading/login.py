#!/usr/bin/env python
#coding=utf-8


import time
import datetime
import json
import sys
import json
from db import Connection
import traceback
import string



def read_in_chunks(filePath, chunk_size=1024*1024):
    file_object = open(filePath)
    while True:
        chunk_data = file_object.read(chunk_size)
        if not chunk_data:
            break
        yield chunk_data

def main():
    
    the_date = (datetime.datetime.now()  + datetime.timedelta(days = -1)).strftime("%Y-%m-%d")
    if len(sys.argv) > 1:
        the_date = sys.argv[1]
    
    log_file = "./login_%s.txt" %(the_date)
 
    insertSql = "insert into bd_action.login_action(q_date,q_time,q_ip,q_uid,q_login_type,q_dev_type,q_result_code,q_channel,q_dev_imei,q_dev_model,q_net,q_app_ver,q_sys_version,q_mobile,q_login_uid,q_third_type,q_third_id,q_opt_duration) values(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s);"
    delSql = "delete from  bd_action.login_action where q_date='%s'" %(the_date)
    
    conn = Connection(using="bd")
    conn.execute(delSql)

    '''
    filePath = './big.txt'
    for chunk in read_in_chunks(filePath):
        print chunk
    '''

    params = []

    for line in open(log_file):
        log_str = line.strip()
        
        log = json.loads(line)
        param = log.get("q_req_param","{}") 
        
        req_data = None
        if isinstance(param.get("data",[{}])[0],dict) == False:
            req_data = json.loads(param.get("data",[{}])[0])
        else:
            req_data = param.get("data",[{}])[0] 
        
        result  = None
        if isinstance(log.get("q_opt_result"),dict) == False:
            result = json.loads(log.get("q_opt_result"))
        else: 
            result = log.get("q_opt_result")

        result_data = result.get("data",{})
        
        if req_data.get("openid","").find("Testyaliceshi") <> -1:
            continue
        if req_data.get("isTest",0) == 1:
            continue
        q_time = log.get("q_opt_time","0")
        if str(q_time).find(":") == -1:
            q_time = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(string.atof(log.get("q_opt_time","0"))/1000))
        
        resultArr = [the_date,q_time,log.get("q_ip","").split(",",-1)[0],log.get("q_uid",""),log.get("q_action",""),log.get("q_dev_type",""),result.get("code",""),log.get("q_channel",""),log.get("q_dev_imei",""),log.get("q_dev_model",""),log.get("q_net",""),log.get("q_app_ver",""),log.get("q_sys_version",""),req_data.get("mobile",""),result_data.get("userId",""),req_data.get("thirdType",""),req_data.get("openid",""),log.get("q_opt_duration","0")]
        params.append(resultArr)

        #conn.execute(insertSql,*tuple(resultArr))

    try:
        conn.executemany(insertSql, params)

    except Exception,e:
        print traceback.format_exc()
        print line  
 
    conn.close()

if __name__ == "__main__":
    main()
