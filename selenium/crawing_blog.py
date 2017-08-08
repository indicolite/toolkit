import sys
import urllib2
import time
from bs4 import BeautifulSoup
from selenium import webdriver
import psycopg2

"""
create table blog_xiami(id serial primary key,
title text,
content text,
time timestamp with time zone default (now() at time zone 'CCT'));

create table blog_link(id serial primary key,
title text,
url text,
time timestamp with time zone default (now() at time zone 'CCT'));

create table xuelianzoo(id serial primary key,
title text,
content text,
tag text,
at text,
time timestamp with time zone default (now() at time zone 'CCT'));
"""

reload(sys)
sys.setdefaultencoding('utf8')

def get_content(url):
    driver = webdriver.Chrome('/usr/local/Cellar/chromedriver/2.29/bin/chromedriver')
    driver.get(url)

    soup = BeautifulSoup(driver.page_source, "html.parser")
    content = soup.select('div.brief.poll_list')
    title = soup.select('h1')
    for tag in soup.select('div.brief.poll_list'):
        content = tag.get_text()
    for tag in soup.select('h1'):
        title = tag.get_text()
    #print content
    #print title

    try:
        connection = psycopg2.connect(dbname='postgres', user='urmcdull', host='localhost')
    except:
        print "unable to connect to the database"
        sys.exit(1)

    mark = connection.cursor()
    statement = "insert into blog_xiami(title, content) values (%s, %s)"
    data = (title, content)
    mark.execute(statement, data)
    connection.commit()
    time.sleep(2)
    driver.quit()

url_group = 'http://www.xiami.com/group/thread/id/81804/page/'
for url_ in range(1,13):
    url_groups = url_group + str(url_)


    driver = webdriver.Chrome('/usr/local/Cellar/chromedriver/2.29/bin/chromedriver')
    driver.get(url_groups)

    soup = BeautifulSoup(driver.page_source, "html.parser")
    content = soup.find_all('td',class_='title')

    for tag in content:
        title = tag.get_text()
        url = tag.a['href']
        url = 'http://www.xiami.com' + url
        get_content(url)

        try:
            connection = psycopg2.connect(dbname='postgres', user='urmcdull', host='localhost')
        except:
            print "unable to connect to the database"
            sys.exit(1)

        mark = connection.cursor()
        statement = "insert into blog_link(title, url) values (%s, %s)"
        data = (title, url)
        mark.execute(statement, data)
        connection.commit()
        time.sleep(2)
        driver.quit()






