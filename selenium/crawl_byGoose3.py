#_*_ coding:utf-8 _*_

from bs4 import BeautifulSoup
import requests
import time
#from urllib2 import unquote
import re
#import pdb

from goose3 import Goose
from goose3.text import StopWordsChinese

'''
>>> from goose3 import Goose
>>> from goose3.text import StopWordsChinese
>>> url  = 'http://www.bbc.co.uk/zhongwen/simp/chinese_news/2012/12/121210_hongkong_politics.shtml'
>>> g = Goose({'stopwords_class': StopWordsChinese})
>>> article = g.extract(url=url)
>>> print article.cleaned_text[:150]
'''


nothing = "http://www.yuedu88.com/xiyoubashiyian/29655.html"
def get_newContent(nothing):
    g = Goose({'stopwords_class': StopWordsChinese})
    #g = Goose({'stopwords_class': StopWordsChinese, 'browser_user_agent': 'Version/5.1.2 Safari/534.52.7'})
    article = g.extract(url=nothing)

    wb_data = requests.get(nothing,allow_redirects=False)
    wb_data.encoding = 'utf-8'
    soup = BeautifulSoup(wb_data.text, 'lxml')
    nextlink = soup.find('a', rel='next', href=True)
    if nextlink is not None:
        nothing = nextlink['href']

    file = open("./xiyoubashiyian_datangniliyu.txt", "ab+")
    file.write((article.title).encode('utf-8'))
    file.write("\n".encode('utf-8'))
    file.write("\n".encode('utf-8'))
    file.write((article.cleaned_text).encode('utf-8'))
    file.write("\n".encode('utf-8'))
    file.write("\n".encode('utf-8'))
    file.close()

    return nothing

def get_nextLink(nothing):
    wb_data = requests.get(nothing,allow_redirects=False)
    wb_data.encoding = 'utf-8'
    soup = BeautifulSoup(wb_data.text, 'lxml')
    nextlink = soup.find('a', rel='next', href=True)
    if nextlink is not None:
        nothing = nextlink['href']
    return nothing

def get_content(nothing):
    sourceUrl = 'http://www.yuedu88.com/xiyoubashiyian/29655.html'

    #url = sourceUrl
    wb_data = requests.get(nothing,allow_redirects=False)
    wb_data.encoding = 'utf-8'
    soup = BeautifulSoup(wb_data.text, 'lxml')
    #soup = BeautifulSoup(wb_data.text, 'html.parser')
    #print soup.original_encoding

    title = soup.find({'h1'})
    #content = soup.find('div',{'id':'conWp','class':'article_con'})
    content = soup.find('div',{'id':'BookText'})
    print(content)
    print('---------------')
    content = findtext(content)
    print(content)
    for line in soup.select('#chapterNext'):
        next_url = line.get('data-url')
    #print "data-url: " + next_url
    nothing = next_url

    file = open("./bdishi.txt", "a")
    file.write((title.get_text("",strip=True)).encode('utf-8'))
    file.write((content.get_text()).encode('utf-8'))
    file.close()
    return nothing

def countchn(string):
    pattern = re.compile(u'[\u1100-\uFFFDh]+?')
    result = pattern.findall(string)
    chnnum = len(result)            #list的长度即是中文的字数
    possible = chnnum/len(str(string))         #possible = 中文字数/总字数
    return (chnnum, possible)

def findtext(part):    
    length = 50000000
    l = []
    for paragraph in part:
        chnstatus = countchn(str(paragraph))
        possible = chnstatus[1]
        if possible > 0.15:         
            l.append(paragraph)
    l_t = l[:]
    #这里需要复制一下表，在新表中再次筛选，要不然会出问题，跟Python的内存机制有关
    for elements in l_t:
        chnstatus = countchn(str(elements))
        chnnum2 = chnstatus[0]
        if chnnum2 < 100:    
        #最终测试结果表明300字是一个比较靠谱的标准
            l.remove(elements)
        elif len(str(elements))<length:
            length = len(str(elements))
            paragraph_f = elements

if __name__ == '__main__':
    theEndSkip = ""
    while True:
        nothing = get_newContent(nothing)
        time.sleep(10)
        if nothing is None:
            break
