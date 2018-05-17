#coding=utf-8
 
from spider.db import Connection

import sys 
import scrapy
from scrapy.spiders import CrawlSpider, Rule
from scrapy.linkextractors import LinkExtractor
from spider.items import NewsItem
from scrapy.http import Request


import json
from spider.items import WbItem



class WbSp(scrapy.Spider):
    name = "hf_wb"
    def __init__(self, user_id='', *args, **kwargs):
        super(WbSp, self).__init__(*args, **kwargs)
        self.start_urls = map(lambda x:"https://m.weibo.cn/api/container/getIndex?type=uid&value=%s&containerid=107603%s&page=%s" %(user_id,user_id,x),range(1, 10))


    def  parse(self,response):
        content = json.loads(response.body)
        cards = content.get("data",{}).get("cards",[])
        for card in cards:
            card_type = card.get("card_type",0)
            if card_type == 11:
                continue
            mblog = card.get("mblog",{})
            item_id = card.get("itemid","")

            text = mblog.get("text", "")
            created_at = mblog.get("created_at", "")
            pics = ",".join(map (lambda x: x.get("url",""),mblog.get("pics",[])))

            self.logger.info("text %s" %(text))
            self.logger.info("pics %s" %(pics))
                                                
            self.logger.info("created_at %s" %(created_at))
            item = WbItem()
            item['site_id'] = 10
            item['user_id'] = ''
            item['content'] = text
            item['pics'] = pics
            item['my_content'] = ''
            item['my_pics'] = ''
            item['wb_id'] = item_id
            yield item

class HFSpider(CrawlSpider):
    
    name = "sp"

    def __init__(self, id=0, *args, **kwargs):

        conn = Connection(using="bd")     
        tasks = conn.query("select * from task_cnf  where id =%s",id)

        conn.close()   

        for task in tasks:
            page_allow = () if task['page_allow'] ==''  else (task['page_allow'])
            page_xpath = () if task['page_xpath'] ==''  else (task['page_xpath'])
            next_allow = () if task['next_allow'] ==''  else (task['next_allow'])
            next_xpath = () if task['next_xpath'] ==''  else (task['next_xpath'])
            
            rule1 = Rule(LinkExtractor(allow=page_allow,restrict_xpaths=page_xpath), callback='parse_item')
            rule2 = Rule(LinkExtractor(allow=next_allow,restrict_xpaths=next_xpath),follow=True,callback='parse_list')
            
            if next_allow ==() and next_xpath ==():
                self.rules =(rule1,)
            else:
                self.rules =(rule1,rule2,) 
            
            self.start_urls = [task['start_url']]
            self.task = task
        
        super(HFSpider, self).__init__(*args, **kwargs)
      
    def parse_list(self,response):
        self.logger.info("parse_list  url [%s]" %(response.url))
        

    def parse_item(self, response):
    
        self.logger.info("parse_item url [%s]" %(response.url))
        item = NewsItem()
        item['site_id'] = self.task['site_id']

        item['news_img'] = response.meta.get("imgs","")
        item['news_url'] =  response.url
        item['news_title'] = response.xpath(self.task['title_xpath']).extract()[0]
        content = response.xpath(self.task['content_xpath'])

        item['news_content'] = content.extract()[0]
        item['news_pics'] =",".join(content.xpath("//img/@src").extract())



        item['my_news_img'] = ''
        item['my_news_content'] = ''
        item['my_news_pics'] = ''
        return item

class HFImgSpider(scrapy.Spider):
    name = "img_sp"   
    
    def __init__(self, id=0, *args, **kwargs):   
 

        conn = Connection(using="bd")     
        tasks = conn.query("select * from task_cnf  where id =%s",id)
        conn.close()   

        for task in tasks:
           
            self.start_urls = [task['start_url']]            
            self.task = task
        
        super(HFImgSpider, self).__init__(*args, **kwargs)      


    def parse(self,response):

        self.logger.info("parse url [%s]" %(response.url))
        item_list = response.xpath(self.task['item_xpath'])
        for item in item_list:
            url = item.xpath(self.task['item_a']).extract()[0]
            img = ",".join(item.xpath(self.task['item_img']).extract())

            yield Request(url,callback=self.parse_item,meta={'imgs': img})
                
        page_next = response.xpath(self.task['next_href']).extract()        
        
        for  page_url in page_next:
            yield Request(page_url,callback=self.parse)
    
        
    def parse_item(self, response):
    
        self.logger.info("parse_item url [%s]" %(response.url))


        item = NewsItem()
        item['site_id'] = self.task['site_id']
        item['news_img'] = response.meta.get("imgs","")
        item['news_url'] =  response.url
        item['news_title'] = response.xpath(self.task['title_xpath']).extract()[0]
        content = response.xpath(self.task['content_xpath'])

        item['news_content'] = content.extract()[0]
        item['news_pics'] =",".join(content.xpath("//img/@src").extract())



        item['my_news_img'] = ''
        item['my_news_content'] = ''
        item['my_news_pics'] = ''
        return item


