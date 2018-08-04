[TOC]

## MySQL中字符串区分大小写的问题？
https://dev.mysql.com/doc/refman/5.7/en/binary-varbinary.html
https://dev.mysql.com/doc/refman/5.7/en/charset-applications.html
http://docs.sqlalchemy.org/en/latest/dialects/mysql.html#sqlalchemy.dialects.mysql.VARCHAR.params.binary
- MySQL默认查询是不区分大小写的，如果需要区分，必须在建表的时候加上Binary标示敏感的属性
- 在SQL语句中实现，WHERE **BINARY** name='CaseSensitive';
- 设置字符集，**utf8_general_ci**不区分大小写，**utf8_bin**区分大小写
```
class sqlalchemy.dialects.mysql.VARCHAR(length=None, **kwargs)¶
   Bases: sqlalchemy.dialects.mysql.types._StringType, sqlalchemy.types.VARCHAR
   MySQL VARCHAR type, for variable-length character data.
     __init__(length=None, **kwargs)
       Construct a VARCHAR.
       Parameters:
         charset – Optional, a column-level character set for this string value. Takes precedence to ‘ascii’ or ‘unicode’ short-hand.
         collation – Optional, a column-level collation for this string value. Takes precedence to ‘binary’ short-hand.
         ascii – Defaults to False: short-hand for the latin1 character set, generates ASCII in schema.
         unicode – Defaults to False: short-hand for the ucs2 character set, generates UNICODE in schema.
         national – Optional. If true, use the server’s configured national character set.
         binary – Defaults to False: short-hand, pick the binary collation type that matches the column’s character set. Generates BINARY in schema. This does not affect the type of data stored, only the collation of character data.
```