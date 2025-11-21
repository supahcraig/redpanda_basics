# Using OMB

_NOTE:  instructions in the redpanda-data repo are now much more complete, but don't yet detail how to connect it to an existing BYOC._
https://github.com/redpanda-data/openmessaging-benchmark/tree/main/driver-redpanda



## Clone the Repo


```bash
git clone https://github.com/redpanda-data/openmessaging-benchmark.git
cd openmessaging-benchmark
```

---

## Run the build


```bash
mvn clean install -Dlicense.skip=true
```

---

## Create SSH key

Create an ssh key for the benchmark using the following.  If you have a keypair you'd rather use, you'll have to update `terraform.tfvars` to point to it instead.

```
ssh-keygen -f ~/.ssh/redpanda_aws
```

Set the password to blank.


## Initialize Terraform

```bash
cd driver-redpanda/deploy/aws
cp terraform.tfvars.example terraform.tfvars
```


### Spin up the resources

If you need to make any changes to the instance types or counts, update `terraform.tfvars` now.
* If you want to point to an existing BYOC or Dedicated cluster, set the Redpanda instances to 0
* Set the client machine count to whatever you need.   4, 8, 20....higher client counts are not out of the question


The `terraform.tfvars` config for typical BYOC perf test might look like this:

TODO:  how to make it deploy in a different region.
2 references to "west" in `provision-redpanda-aws.tf':  availability zone and then in the `aws_ami` section


```ini
public_key_path = "~/.ssh/redpanda_aws.pub"

owner           = "redpanda"
region          = "us-west-2"
# arm64 ubuntu focal
machine_architecture = "arm64"

instance_types = {
  "redpanda"      = "is4gen.4xlarge"
  "client"        = "c6g.8xlarge"
  "prometheus"    = "c6g.2xlarge"
}

# client instances may need to be larger than redpanda broker count
# to provide enough message volume for testing
num_instances = {
  "client"     = 4
  "redpanda"   = 0
  "prometheus" = 1
}
```

Then actually run terraform apply.

First move back to the deploy folder.

```bash
terraform -chdir=aws init
terraform -chdir=aws apply --auto-approve
```

OR.....

```bash
terraform init
terraform apply --auto-approve
```



## Set up Ansible

### Install the ansible requirements.

```bash
ansible-galaxy install -r requirements.yaml
if [ "$(uname)" = "Darwin" ]; then export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES; fi
```


## Deploy Ansible

Set an environment variable to so ansible will know about your BYOC cluster.

```bash
export REDPANDA_BOOTSTRAP_SERVER="<seed-endpoint-from-BYOC-console.com:9092>"
```

*Deploy the ansible playbook*

Note that this depends on the environment variable being set for the kafka api endpoint, and also a user created in your cluster with a sasl-scram-256 password (cnelson/cnelson in this example), and give it full ACLs.

```
ansible-playbook --inventory hosts.ini \
--ask-become-pass \
-e "tls_enabled=true sasl_enabled=true sasl_username=cnelson sasl_password=cnelson" \
-e bootstrapServers=${REDPANDA_BOOTSTRAP_SERVER} \
deploy.yaml
```

It will prompt you for the admin password for your local machine.  If running from EC2, simply sudo prior to running ansible.

Specifying the bootstrap server & SASL user/pass simply injects that info into each workload file.   So if you build a new cluster or change sasl info, you can simply replace it in your workload file without needing to re-deploy the workers.

```yaml
driverClass: io.openmessaging.benchmark.driver.redpanda.RedpandaBenchmarkDriver
# Kafka client-specific configuration
replicationFactor: 3
reset: true

topicConfig: |
commonConfig: |
  bootstrap.servers=seed-2df89778.yourClusterID.byoc.prd.cloud.redpanda.com:9092
  sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username='cnelson' password='cnelson';
  security.protocol=SASL_SSL
  sasl.mechanism=SCRAM-SHA-256
  request.timeout.ms=120000
producerConfig: |
  acks=all
  linger.ms=1
consumerConfig: |
  group.id=benchGroup
  auto.offset.reset=earliest
  enable.auto.commit=false
  fetch.max.wait.ms=50
  fetch.min.bytes=1
  max.partition.fetch.bytes=10485760
```



---

## Set up the workload test

### SSH into one of the client machines

```bash
ssh -i ~/.ssh/redpanda_aws ubuntu@$(terraform -chdir=aws output --raw client_ssh_host)
```

OR

```bash
ssh -i ~/.ssh/redpanda_aws ubuntu@$(terraform output --raw client_ssh_host)
```


### Become root

```bash
sudo su -
cd /opt/benchmark
```

### Pick your workload yaml

These are found in `/opt/benchmark/workload` but what I tend to do is create a new workload yaml under that path.  Here is an examples using 8k producers writing to a single topic.


*8k-producers.yaml*
```yaml
topics: 1
partitionsPerTopic: 60
keyDistributor: "RANDOM_NANO"
messageSize: 1024
payloadFile: "payload/payload-1Kb.data"
subscriptionsPerTopic: 2
consumerPerSubscription: 1
producersPerTopic: 8000
producerRate: 1000
consumerBacklogSizeGB: 0
warmupDurationMinutes: 5
testDurationMinutes: 5
```

`keyDistributor: "RANDOM_NANO"` will give a more uniform distribution of connections, since the publishing will be to more random partitions.   It will also give an actual connection count closer to the target producer count.

### Different Message Sizes

Run this to generate a new payload file for your desired message size.

```bash
dd if=/dev/urandom of=payload/payload-250Kb.data bs=1024 count=250
```

or this:

```bash
head -c 75 /dev/urandom > payload/payload-75b.data
```

## Run the workload

```bash
bin/benchmark --drivers driver-redpanda/redpanda-ack-all-group-linger-10ms.yaml workloads/8k-producers.yaml
```


To run the benchmark in the backkground:

```
nohup sudo bin/benchmark -d driver-redpanda/redpanda-ack-all-group-linger-10ms.yaml \
     workloads/8k-producers.yaml &
```


then you can `tail -f ~/nohup.out` to continue watching the progress and not worry if your terminal window closes.


## Quick Looks at E2E Latency

This will scan your output json file for the E2E latency for whataver Pxx you want

```bash
jq '.endToEndLatency999pct | max' <results>.json
```

Show min/max/avg of the p99.9 series

```bash
jq -r '
  .endToEndLatency999pct as $a |
  "p999_e2e: min=\($a|min) max=\($a|max) avg=\($a|add/length)"
' <results>.json
```

---


## Destroy Everthing

From where you ran the terraform apply:

```bash
terraform destroy --auto-approve
```



---


# fixes?

`deploy.yaml`

Near line 432

```yaml

- name: Install Node Exporter
  hosts: redpanda, client
  gather_facts: true
  vars:
    node_exporter_enabled_collectors: [ntp]
    dist_architecture:
      aarch64: arm64
      x86_64: amd64
    node_exporter_arch: "{{ dist_architecture[ansible_architecture] | string }}"
#  tasks:
#    - name: Debug node_exporter_arch
#      debug:
#        var: node_exporter_arch
```

```
ansible-playbook --inventory  ${REDPANDA_CLOUD_PROVIDER}/hosts.ini \
--ask-become-pass \
-e "tls_enabled=true sasl_enabled=true sasl_username=cnelson sasl_password=cnelson" \
-e bootstrapServers=${REDPANDA_BOOTSTRAP_SERVER} \
deploy.yaml
```


## Large Workloads

This should be good for ~4GB/sec in and 16GB/sec out

```yaml
name: 100-partitions-500K-rate-4-producer

topics: 5
partitionsPerTopic: 600
messageSize: 4096
payloadFile: "payload/payload-4Kb.data"
subscriptionsPerTopic: 4
consumerPerSubscription: 16
producersPerTopic: 50
producerRate: 100000
consumerBacklogSizeGB: 0
testDurationMinutes: 10
warmupDurationMinutes: 4
```


## Peering OMB to the BYOC VPC

The easiest way to do the peering is to use the `peer_vpcs.sh` shell script (found under Benchmarking in this repo).   Set the values in `vpcs.env` and then execute the shell script and the peering & all routes will be created for you.


If you need to do it more manually, these are the steps.

Create a peering request from Redpanda to OMB, using the OMB cidr
accept the request

```bash
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id pcx-04fd789aaae878884
```


Add a route to the peering connection & Redpanda CIDR to the OMB route table(s)
* route table is the OMB route table
* destination CIDR is the CIDR of the Redpanda VPC
```bash
aws ec2 create-route \
    --route-table-id rtb-0eda7389a22072519 \
    --destination-cidr-block 10.203.0.0/16 \
    --vpc-peering-connection-id pcx-04fd789aaae878884
```

Add a route to the peering connection & OMB CIDR to the Redpanda route table(s)
* VPC_ID is the Repdanda VPC ID
* DEST_CIDR is the CIDR of the Redpanda VPC

```bash
REGION=us-east-2 VPC_ID=vpc-06029858c0205cf0b PCX_ID=pcx-04fd789aaae878884 DEST_CIDR=10.90.0.0/16; \
for rt in $(aws ec2 describe-route-tables --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'RouteTables[].RouteTableId' --output text); do
  aws ec2 create-route  --region "$REGION" --route-table-id "$rt" \
    --destination-cidr-block "$DEST_CIDR" --vpc-peering-connection-id "$PCX_ID" \
  || \
  aws ec2 replace-route --region "$REGION" --route-table-id "$rt" \
    --destination-cidr-block "$DEST_CIDR" --vpc-peering-connection-id "$PCX_ID";
done
```


# Validate Peering / Install rpk

Once ssh'd into a worker:

```bash
sudo su -

apt install unzip

curl -LO https://github.com/redpanda-data/redpanda/releases/latest/download/rpk-linux-arm64.zip &&
  mkdir -p ~/.local/bin &&
  export PATH="~/.local/bin:$PATH" &&
  unzip rpk-linux-arm64.zip -d ~/.local/bin/
```

## Create rpk profile

```bash
rpk profile create bench
rpk profile edit bench
```

Your actual profile, change the seed URL & your sasl user/pass

```yaml
name: bench
description: ""
prompt: ""
from_cloud: false
kafka_api:
    brokers:
        - seed-2d035973.d36pp0m3t7fl88r58lm0.byoc.prd.cloud.redpanda.com:9092
    tls: {}
    sasl:
        user: cnelson
        password: '[REDACTED]'
        mechanism: SCRAM-SHA-256
admin_api: {}
schema_registry: {}
```

Then do an `rpk cluster info` to verify connectivity to the cluster.



