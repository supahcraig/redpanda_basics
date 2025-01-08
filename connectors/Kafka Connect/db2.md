

## Setting up DB2 for CDC

Mainly followed these guides:
https://sairajsalve.medium.com/debezium-db2-connector-with-apache-kafka-739624095e5e


With some help from this:  https://debezium.io/documentation/reference/connectors/db2.html#_putting_tables_into_capture_mode


### Clone the repo

git clone https://github.com/debezium/debezium-connector-db2


### Build the Docker image

```bash
cd /src/test/docker/db2-cdc-doccker

docker build -t db2test:0.1
```

### Spin up the container 

The image contains several scripts that initializes the db and runs the required scripts to start the `asncap` service which helps capture database changes.

```bash
docker run — name testdb2 — privileged=true -p 50000:50000 -e LICENSE=accept -e DB2INST1_PASSWORD=password -e DBNAME=testdb -v <your-dir>/db2inst1:/database db2tester:0.1
```

Wait for "Setup is complete" message.

Username will be `db2inst1` by default


### Get to the DB2 shell

```bash
docker exec -ti mydb2 bash -c "su - db2inst1"
```


# NOTE:  this will not run on an M2 mac....

probably need to try on EC2.  Need to find the motivation for that.
