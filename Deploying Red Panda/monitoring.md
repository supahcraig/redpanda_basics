

Random notes...






Monitoring:
I don't think we've set this up yet in your environment and normally I install this via ansible. I have done this manually though before and it's pretty straightforward, here are the general steps:
Install and configure prometheus via rpm/yum
- edit the prometheus yaml file to scrape `http://redpandahost:9644/public_metrics`
- start prometheus
Install grafana via rpm/yum
- Add a datasource of "prometheus" listening on its port (default 9000)
- import a dashboard I will provide you
