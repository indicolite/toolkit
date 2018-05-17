# -*- coding: utf-8 -*-

# Define your item pipelines here
#
# Don't forget to add your pipeline to the ITEM_PIPELINES setting
# See: https://doc.scrapy.org/en/latest/topics/item-pipeline.html

from db import Connection
from items import NewsItem,WbItem

class SpiderPipeline(object):

    def __init__(self):
        
        self.conn = None 
        

    def process_item(self, item, spider):
         
        if isinstance(item,NewsItem):

            sql = "insert into bd_action.spider_news (site_id, news_url, news_title, news_img, news_content, news_pics, my_news_img, my_news_content, my_news_pics) values(%s,%s,%s,%s,%s,%s,%s,%s,%s)";
            self.conn.execute(sql,item['site_id'],item['news_url'],item['news_title'],item['news_img'],item['news_content'],item['news_pics'],item['my_news_img'],item['my_news_content'],item['my_news_pics'])

        elif isinstance(item,WbItem):

            sql = "insert into bd_action.spider_wb (user_id, content, my_content, pics, my_pics, site_id,wb_id) values (%s,%s, %s, %s, %s, %s, %s);"
            self.conn.execute(sql,item['user_id'],item['content'],item['my_content'],item['pics'],item['my_pics'],item['site_id'],item['wb_id'])
        else:
            spider.logger.info(item)   

        return item

    def open_spider(self, spider):
        self.conn = Connection(using="bd")
        

    def close_spider(self,spider):
        self.conn.close()

    
