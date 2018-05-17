#!/usr/bin/env python
#-*- coding:utf-8
#
'''
mysql数据调用封装

    @torndb所有方法的实现(tornado的db调用类)以及本地化
    @支持便捷批量update, insert, delete 操作
    @支持文件句柄便捷调用
    @自动重连,超时时间的优化设定。

CREATE TABLE `login_action` (
  `q_date` date DEFAULT NULL,
  `q_time` timestamp NULL DEFAULT NULL,
  `q_ip` char(50) DEFAULT '',
  `q_uid` char(20) DEFAULT '',
  `q_login_type` char(20) DEFAULT '',
  `q_dev_type` char(10) DEFAULT '',
  `q_channel` char(20) DEFAULT '',
  `q_dev_imei` char(50) DEFAULT '',
  `q_dev_model` char(50) DEFAULT '',
  `q_net` char(10) DEFAULT '',
  `q_app_ver` char(10) DEFAULT '',
  `q_sys_version` char(50) DEFAULT '',
  `q_mobile` char(20) DEFAULT '',
  `q_third_type` char(10) DEFAULT '',
  `q_third_id` char(100) DEFAULT '',
  `q_login_uid` char(10) DEFAULT '',
  `q_result_code` char(10) DEFAULT '',
  `q_opt_duration` bigint(20) DEFAULT '0',
  KEY `q_time` (`q_time`),
  KEY `q_date` (`q_date`),
  KEY `q_login_id` (`q_login_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4

'''

import sys
import copy
import itertools
import logging
import time
import fileinput
import setting
try:
    import MySQLdb
    import MySQLdb.cursors
    import MySQLdb.constants
    import MySQLdb.converters
except ImportError:
    print >> sys.stderr,"""\

There was a problem importing Python modules(MySQLdb) required.
The error leading to this problem was:
%s Please install a package which provides this module, or
verify that the module is installed correctly.

It's possible that the above module doesn't match the current version of Python,
which is:
%s
""" % (sys.exc_info(), sys.version)
#     sys.exit(1)
#     # MySQLdb = None

__all__ = ["Connection", "Insert", "Update", "Delete"]






class Connection(object):


    '''
    数据库调用封装核心类
    支持两种方法调用
    @自定义连接 (临时/不确定信息)

        from hivedb import Connection
        conn = Connection(host='192.168.1.1:3306', user='root', password='root', database="testdb")

    @句柄连接数据库(经常性连接的数据库)

        from hivedb import Connection
        conn = Connection(using="testdb")  #保证testdb在databases字典里面

    @执行查询
        cmd_sql = 'select * from testtbl'
        cmd_sql_result = conn.query(cmd_sql) #字典方式显示

    '''

    def __init__(self, host=None, database=None, user=None, password=None, max_idle_time=1*3600, using=None):

        self.host = host
        self.database = database
        self.max_idle_time = max_idle_time
        self.cursor_hander = using
        # global databases
        if self.cursor_hander:
            if setting.DATABASES[self.cursor_hander]:
                self._dbhander = setting.DATABASES[self.cursor_hander]

                args = dict(
                            host=self._dbhander['host'],
                            user=self._dbhander['user'],
                            passwd=self._dbhander['password'],
                            db=self._dbhander['database'],
                            charset=self._dbhander['charset'],
                            port=int(self._dbhander['port']),
                            )

                args.update(dict(
                            init_command='SET time_zone = "+8:00"',
                            sql_mode="TRADITIONAL")
                            )
            else:
                print 'sorry,databases hasn\'s it'
                sys.exit(1)

        else:

            args = dict(use_unicode=True, charset="utf8",
                        db=database, init_command='SET time_zone = "+8:00"',
                        sql_mode="TRADITIONAL")

            if user is not None:
                args["user"] = user
            if password is not None:
                args["passwd"] = password
            if "/" in host:
                args["unix_socket"] = host
            else:
                self.socket = None
                pair = host.split(":")
                if len(pair) == 2:
                    args["host"] = pair[0]
                    args["port"] = int(pair[1])
                else:
                    args["host"] = host
                    args["port"] = 3306

        self._db = None
        self._db_args = args
        self._last_use_time = time.time()
        # print self._db_args
        try:
            self.reconnect()

        except Exception, e:
            logging.error("Cannot connect to Mysql on %s %s" %(self.host,e), exc_info=True)





    def reconnect(self):

        self.close()
        self._db = MySQLdb.connect(**self._db_args)
        self._db.autocommit(True)

    def __del__(self):
        self.close()

    def ping(self):
        self._db.ping(True)

    def close(self):
        if getattr(self, "_db", None) is not None:
            self._db.close()
            self._db = None


    def iter(self,query, parameters):
        self._ensure_connected()
        cursor = MySQLdb.cursors.SSCursor(self._db)
        try:
            self._execute(cursor, query, parameters)
            column_names = [d[0] for d in cursor.description]
            for row in cursor:
                yield Row(zip(column_names, row))
        finally:
            cursor.close()

    def query(self, query, *parameters):
        '''
        '''
        cursor = self._cursor()
        try:
            self._execute(cursor, query, parameters)
            column_names = [d[0] for d in cursor.description]
            return [Row(itertools.izip(column_names, row)) for row in cursor]
        finally:
            cursor.close()


    def get(self, query, *parameters):

        rows = self.query(query, *parameters)
        if not rows:
            return None
        elif len(rows) > 1:
            raise Exception("Multiple rows returned for Database.get() query")
        else:
            return rows[0]

    def execute(self, query, *parameters):
        return self.execute_lastrowid(query, *parameters)

    def execute_lastrowid(self, query, *parameters):
        cursor = self._cursor()
        try:
            self._execute(cursor, query, parameters)
            return cursor.lastrowid
        finally:
            cursor.close()
    def execute_rowcount(self, query, *parameters):

        cursor = self._cursor()
        try:
            self._execute(cursor, query, parameters)
            return cursor.rowcount
        finally:
            cursor.close()

    def executemany(self, query, parameters):

        return self.executemany_lastrowid(query, parameters)

    def executemany_lastrowid(self, query, parameters):

        cursor = self._cursor()
        try:
            cursor.executemany(query, parameters)
            return cursor.lastrowid
        finally:
            cursor.close()

    def executemany_rowcount(self, query, parameters):

        cursor = self._cursor()
        try:
            cursor.executemany(query, parameters)
            return cursor.rowcount
        finally:
            cursor.close()

    def _ensure_connected(self):
        if (self._db is None or (time.time() - self._last_use_time > self.max_idle_time)):
            self.reconnect()
            self._last_use_time = time.time()

    def _cursor(self):
        self._ensure_connected()
        return self._db.cursor()

    def _execute(self, cursor, query, parameters):
        try:

            return cursor.execute(query, parameters)
        except MySQLdb.OperationalError:
            logging.error("Error connecting to MySQL on %s", self.host)
            self.close()
            raise

    def insert(self, table, **datas):

        return Insert(self, table)(**datas)

    def update(self, table, where, **datas):

        return Update(self, table, where)(**datas)

    def delete(self, table, where):
        return Delete(self, table, where)()




class Row(dict):
    def __getattr__(self, name):
        try:
            return self[name]
        except KeyError:
            raise AttributeError(name)


class Insert(object):

    '''
    批量Insert调用类
    '''

    def __init__(self, database, tblname):
        self.database = database
        self._tblname = tblname

    def __call__(self,**fileds):

        columns=fileds.keys()
        _prefix="".join(['INSERT INTO `',self._tblname,'`'])
        _fields=",".join(["".join(['`',column,'`']) for column in columns])
        _values=",".join(["%s" for i in range(len(columns))])
        _sql="".join([_prefix,"(",_fields,") VALUES (",_values,")"])
        _params=[fileds[key] for key in columns]
        return self.database.execute(_sql,*tuple(_params))

class Update(object):

    '''
    批量Update调用类
    '''

    def __init__(self, database, tblname, where):

        self.database = database
        self._tblname = tblname
        self._where = where

    def __call__(self,**fileds):

        if len(fileds)<1:
            raise MySQLdb.OperationalError,"Must have unless 1 field to update"
        _params=[]
        _cols=[]
        for i in fileds.keys():
            _cols.append("".join(["`",i,'`','=%s']))
        for i in fileds.values():
            _params.append(i)
        _sql_slice=["UPDATE ",self._tblname," SET ",",".join(_cols)]
        if self._where:
            _sql_slice.append(" WHERE "+self._where)
        _sql="".join(_sql_slice)
        return self.database.execute_rowcount(_sql, *_params)

class Delete(object):

    '''
    批量删除调用类
    '''

    def __init__(self, database, tblname, where):
        self.database = database
        self._tblname = tblname
        self._where = where

    def __call__(self):

        _sql_slice=["DELETE FROM `",self._tblname,"`"]
        if self._where:
            _sql_slice.append(" WHERE "+self._where)
            _sql="".join(_sql_slice)
            return self.database.execute_rowcount(_sql)










