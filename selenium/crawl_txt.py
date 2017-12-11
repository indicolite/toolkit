#_*_ coding:utf-8 _*_

from bs4 import BeautifulSoup
import requests
import time
from urllib2 import unquote
import re
#import pdb

nothing = '/book/20170807/118427.html'

def get_content(nothing):
    #url = 'http://www.56wen.com/book/20170807/118427.html'
    sourceUrl = 'http://www.56wen.com'
    #urlContent = urllib.urlopen(sourceUrl + nothing).read()
    ###>>>for line in soup.select('#next'):
    ###...    print line.get('href')
    ###>>>/book/20170807/118428.html

    url = sourceUrl + nothing
    wb_data = requests.get(url,allow_redirects=False)
    wb_data.encoding = 'utf-8'
    soup = BeautifulSoup(wb_data.text, 'lxml')
    #soup = BeautifulSoup(wb_data.text, 'html.parser')


    #print soup.original_encoding

    title = soup.find('div',{'class':'article_title'})
    content = soup.find('div',{'id':'J_article_con','class':'article_con'})
    for line in soup.select('#next'):
        next_url = line.get('href')
    print "href: " + next_url
    for line in soup.select('#next'):
        newNothing = line.get('href')
    urlContent = sourceUrl + newNothing
    print "next: " + urlContent
    nothing = next_url

    file = open("./kaifengzhiguai.txt", "a")
    file.write((title.get_text("",strip=True)).encode('utf-8'))
    file.write((content.get_text()).encode('utf-8'))
    file.close()
    return nothing

if __name__ == '__main__':
    theEndSkip = ""
    #start_url = 'http://www.56wen.com/book/20170807/118427.html'
    while True:
        nothing = get_content(nothing)
        time.sleep(5)
