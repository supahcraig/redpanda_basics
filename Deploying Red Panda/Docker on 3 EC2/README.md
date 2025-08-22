Usually this would be the domain of kubernetes or EKS, but if you want to use docker to spin up an instance on a single EC2, and then do multiples of those to form a cluster and you also don't want to use docker networking in favor of host networking.... well here you go.

This is also known as _HARD MODE_

## EC2 Setup

I used an m7gd.xlarge instance with Ubuntu 22.

### Security group rules

The firewall rules need to allow for the brokers to communicate among themselves on these ports:
* 9092 (the kafka api internal listener)
* 9644
* 8081
* 33145

The firewall rules from outside the cluster need to look more like this:
* 19092 (the kafka api advertised external listener)
* 9644
* 8081


## Install docker on each broker

https://docs.docker.com/engine/install/ubuntu/

### Uninstall all conflicting packages first

```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
```


### Set up apt repository

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

### Install Docker, etc

```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```


### Verify Docker

```bash
sudo docker run hello-world
```

## Spin up the container

You'll need to do this on each broker.

Export 2 environment variables to simplify the deployment variations across each host.

```bash
export PRIVATE_IP=$(hostname -I | awk '{print $1}')
export PUBLIC_IP=$(curl -s https://ifconfig.me)
```

```yaml
services:
  redpanda-broker-1:
    image: docker.redpanda.com/redpandadata/redpanda:latest
    network_mode: host
    environment:
      PRIVATE_IP: ${PRIVATE_IP}
      PUBLIC_IP: ${PUBLIC_IP}
    command:
      - redpanda
      - start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
      - --advertise-kafka-addr internal://${PRIVATE_IP}:9092,external://${PUBLIC_IP}:19092
      - --rpc-addr 0.0.0.0:33145
      - --advertise-rpc-addr ${PRIVATE_IP}:33145
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      - --default-log-level debug
      - --mode dev-container
      - --smp 1
```

And to spin it up, ensuring that the env vars are used:

```bash
sudo -E docker compose up -d
```

For the remaining brokers, you will need to add a line for the seed broker, so it knows to join an existing cluster.

Under the "command" section add `- --seeds <private IP of broker #1>:33145`


So for all subsequent brokers the compose looks like this:

```yaml
services:
  redpanda-broker-1:
    image: docker.redpanda.com/redpandadata/redpanda:latest
    network_mode: host
    environment:
      PRIVATE_IP: ${PRIVATE_IP}
      PUBLIC_IP: ${PUBLIC_IP}
    command:
      - redpanda
      - start
      - --kafka-addr internal://0.0.0.0:9092,external://0.0.0.0:19092
      - --advertise-kafka-addr internal://${PRIVATE_IP}:9092,external://${PUBLIC_IP}:19092
      - --rpc-addr 0.0.0.0:33145
      - --advertise-rpc-addr ${PRIVATE_IP}:33145
      - --schema-registry-addr internal://0.0.0.0:8081,external://0.0.0.0:18081
      - --default-log-level debug
      - --mode dev-container
      - --smp 1
```



