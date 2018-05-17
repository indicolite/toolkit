# -*- coding: utf-8 -*-

# Define here the models for your scraped items
#
# See documentation in:
# https://doc.scrapy.org/en/latest/topics/items.html

import scrapy


class NewsItem(scrapy.Item):
    # define the fields for your item here like:
    site_id = scrapy.Field()
    news_url = scrapy.Field()
    news_title = scrapy.Field()
    news_content = scrapy.Field()
    news_img = scrapy.Field()
    news_pics = scrapy.Field()

    my_news_img = scrapy.Field()
    my_news_content = scrapy.Field()
    my_news_pics = scrapy.Field()


class WbItem(scrapy.Item):
    site_id = scrapy.Field()
    user_id = scrapy.Field()
    content = scrapy.Field()
    pics = scrapy.Field()
    wb_id = scrapy.Field()
    my_content = scrapy.Field()
    my_pics = scrapy.Field()



