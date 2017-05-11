#!/usr/bin/env python
# coding=utf-8

import sys
import urllib2
import time
from bs4 import BeautifulSoup
from selenium import webdriver
import psycopg2
import base64
#import qrcode_terminal
import qrcode
from datetime import datetime
from apscheduler.schedulers.blocking import BlockingScheduler

"""
postgres=# create table scanner(id serial primary key,
addr varchar(20),
port integer,
pasd varchar(20),
aesd varchar(20),
trie integer,
time timestamp with time zone default (now() at time zone 'CCT'));

alter table scanner add column code text;
alter table scanner alter column addr type text;
alter table scanner alter column pasd type text;
alter table scanner alter column aesd type text;
"""

reload(sys)
sys.setdefaultencoding('utf8')

def job_function():

    url = 'http://website.abc/'
    driver = webdriver.Chrome('/usr/local/Cellar/chromedriver/2.29/bin/chromedriver')
    driver.get(url)
    soup = BeautifulSoup(driver.page_source, "html.parser")
    lst = (soup.find_all('code'))[1:]
    data = []
    for x in lst:
        strl = "".join(x)
        data.append(strl)
    #print data

    try:
        connection = psycopg2.connect(dbname='postgres', user='postgres', host='localhost')
    except:
        print "unable to connect to the database"
        sys.exit(1)
    mark = connection.cursor()
    addr = data[0]
    port = data[1]
    pasd = data[2]
    aesd = data[3]
    trie = data[4]

    if int(trie) < 31:
        string_to = aesd + ':' + pasd + '@' + addr + ':' + port
        string_to = "ss://" + base64.b64encode(string_to)
        code = string_to
        statement = "insert into scanner(addr, port, pasd, aesd, trie, code) values (%s, %s, %s, %s, %s, %s)"
        img = qrcode.make(string_to)
        img.save("website.abc")
        data = (addr, port, pasd, aesd, trie, code)
        mark.execute(statement, data)
        connection.commit()
    else:
        print "too many connects with %s" % trie
        driver.quit()
        sys.exit(1)

    time.sleep(2)
    driver.quit()

sched = BlockingScheduler()
# Schedule job_function to be called every six hours
sched.add_job(job_function, 'interval', hours=6, start_date='2017-05-03 15:33:40', end_date='2020-05-02 15:33:40')
sched.start()
