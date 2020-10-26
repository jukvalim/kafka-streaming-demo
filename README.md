Demo of Kafka, using Scrapy and Phoenix Liveview
================================================

Quick-and-dirty demo of event/data streaming architecture with Apache Kafka.
I made the demo to go together with a presentation about event-driven systems using
Apache Kafka. It's (entirely unserious) dashboard for developers who want to
see how popular certain "good" or "bad" words are on the web page of a prospective
employer.

The way it works: a web scraper scrapes web sites, and pushes the text from each scraped page to `scrapedpages` Kafka topic. This topic is read by a consumer running under
a separate supervisor in `dashboard` project. The consumer counts the number of "good"
and "bad" words in each page, and sums them up for domains. Then it pushes fresh word counts for each domain to `wordcounts` topic. This topic is read by Phoenix Liveview dashboard, and fresh, automatically updating numbers for each domain shown.

Requirements
------------
To run this demo, you need to have Kafka installed. This demo only uses one broker.

Running the scraper
-------------------
The scraper is implemented using [Scrapy framework](https://scrapy.org/). It scrapes a web page (up to depth of three, staying in the same domain), extracts text from each page, and pushes it to `scrapedpages` topic. The scraper is run from command line, like this:

```
scrapy crawl pagetexts -a url=http://quotes.toscrape.com/ -a kafka_broker=<broker host>:<broker port>
```
Before running the scraper, go to `scraper` directory and install the Python dependencies using Poetry.

Running the PageConsumer and the Liveview dashboard
---------------------------------------------------
The consumer and the dashboard run in the same Elixir instance. Start them up
by going to `dashboard` directory and running the command:
```
KAFKA_HOST=<broker host> KAFKA_PORT=<broker port> mix phx.server
```
For this, Elixir needs to be installed on your computer, and dependencies from mix.exs installed.

Now you can open browser at `localhost:5000` and see the dashboard there.