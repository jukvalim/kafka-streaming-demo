import json
import re
from urllib.parse import urlparse

import scrapy
from bs4 import BeautifulSoup
from kafka import KafkaProducer


class PageTextSpider(scrapy.Spider):
    name = "pagetexts"
    DOMAIN = None

    def __init__(self, url=None, kafka_broker=None, *args, **kwargs):
        super().__init__(*args, **kwargs)
        kafka_broker = kafka_broker if kafka_broker else "localhost:32000"
        self.producer = KafkaProducer(bootstrap_servers=kafka_broker)

        self.url = url
        domain = urlparse(url).netloc
        self.allowed_domains = [domain]
        self.DOMAIN = domain

    def start_requests(self):
        # refresh cached allowed domains
        for mw in self.crawler.engine.scraper.spidermw.middlewares:
            if isinstance(mw, scrapy.spidermiddlewares.offsite.OffsiteMiddleware):
                mw.spider_opened(self)
        yield scrapy.Request(url=self.url, callback=self.parse)

    def parse(self, response):
        url = response.url.split("://")[-1]
        url = url.rstrip("/").replace("/", "-")

        soup = BeautifulSoup(response.body)
        text = soup.get_text()
        # remove extra whitespace
        text = re.sub(' +', ' ', text)
        text = re.sub('\n+', ' ', text)
        #filename = f'{url}.file'
        #with open(filename, 'wb') as f:
        #    f.write(text.encode('utf-8'))

        message = json.dumps({"domain": self.DOMAIN, "url": response.url, "text": text})
        self.producer.send('scrapedpages', message.encode("utf-8"))
        self.log(f'Sent page {response.url} to kafka topic scrapedpages')

        links = response.xpath('//a/@href').extract()

        for link in links:
            url = response.urljoin(link)
            yield scrapy.Request(url)
