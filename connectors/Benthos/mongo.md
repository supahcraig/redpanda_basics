# Setting up the RPCN Mongo Input

https://www.mongodb.com/docs/manual/tutorial/install-mongodb-community-with-docker/


```bash
docker pull mongodb/mongodb-community-server:latest

docker run --name mongodb -p 27017:27017 -d mongodb/mongodb-community-server:latest

```





---

## Other potentially useful links


This link talks about setting up a change stream, but it involves running some java to "create the change stream" before Kafka Connect can make use of it?

https://medium.com/@azmi.ahmad/real-time-data-streaming-with-mongodb-change-streams-and-kafka-connector-c88e051c47e4


---

Mongo docs on setting up for KC

https://www.mongodb.com/docs/kafka-connector/current/tutorials/tutorial-setup/
