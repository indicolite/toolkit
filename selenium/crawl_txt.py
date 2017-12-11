#_*_ coding:utf-8 _*_

from bs4 import BeautifulSoup
import requests
import time
from urllib2 import unquote
import re

url = 'http://www.56wen.com/book/20170807/118427.html'
wb_data = requests.get(url)
wb_data.encoding = 'utf-8'
soup = BeautifulSoup(wb_data.text, 'lxml')
#soup = BeautifulSoup(wb_data.text, 'html.parser')


print soup.original_encoding

title = soup.find('div',{'class':'article_title'})
content = soup.find('div',{'id':'J_article_con','class':'article_con'})
print title.get_text("",strip=True)
print content.get_text()
#print content.get_text("",strip=True)