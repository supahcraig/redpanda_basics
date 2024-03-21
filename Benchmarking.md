# Using OMB

For the most part, the instructions found here are correct.   Maybe not quite so if you have trouble, or if you want to benchmark against an existing cluster.


## Clone the Repo

You can use the Redpanda fork of OMB, which wishes it were up to date but often times we have to fix stuff & submit PRs but in the meanwhile you may have to roll your own.


### Redpanda Fork


### My Current Fork


I have forked this repo here to add some logging messages & also increase a timeout that you'll hit when you try to test with lots of producers. 

```
git clone https://github.com/supahcraig/openmessaging-benchmark.git
```

### Dave V's Current Fork

Dave Voutila has put some additional tuning in to help with large numbers of producers.  

```
git clone https://github.com/voutilad/openmessaging-benchmark.git
```

---

## Run the build


```
cd openmessaging-benchmark
mvn clean install -Dlicense.skip=true
```

---

## Set up Terraform


```
cd driver-redpanda/deploy
cp terraform.tfvars.example terraform.tfvars
```

If you need to make any changes to the instance types or counts, update `terraform.tfvars` now.
* If you want to point to an existing BYOC or Dedicated cluster, set the Redpanda instances to 0, and set the client machine count to whatever you need.   4, 8, 20....higher client counts are not out of the question
* If you want to create VMs for a _new_ redpanda self-hosted cluster, set redpanda instances to the number of brokers you want in the cluster
* If you want to point to an existing self-hosted cluster....._I don't know how to set it just yet_


## Set up Ansible

### Install the ansible requirements.

```
ansible-galaxy install -r requirements.yml
if [ "$(uname)" = "Darwin" ]; then export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES; fi
```

### _Are you running against an existing BYOC cluster?_


#### Yes?
Set this environment variable to so ansible will know what to do

```
export REDPANDA_BOOTSTRAP_SERVER="<seed-endpoint-from-BYOC-console.com:9092>"
```

*Deploy the ansible playbook*


```
ansible-playbook --inventory  hosts.ini \
--ask-become-pass \
-e "tls_enabled=true sasl_enabled=true sasl_username=cnelson sasl_password=cnelson" \
-e bootstrapServers=${REDPANDA_BOOTSTRAP_SERVER} \
deploy.yaml
```



#### No?

*Deploy the ansible playbook*

```
  if [ "$(uname)" = "Darwin" ]; then export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES; fi
        ansible-galaxy install -r requirements.yml
        ansible-playbook --ask-become-pass deploy.yaml
```


---

## Set up the workload test

### SSH into one of the client machines

```
ssh -i ~/.ssh/redpanda_aws ubuntu@$(terraform output --raw client_ssh_host)
```

### Become root

```
sudo su -
cd /opt/benchmark
```

### Pick your workload yaml

These are found in `/opt/benchmark/workload` but what I tend to do is create a new workload yaml under that path.  Here are some examples.


*8k producers*
```
topics: 1
partitionsPerTopic: 30
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

*Randomized payloads*
```
name: Test config

topics: 1
partitionsPerTopic: 30

messageSize: 1024
useRandomizedPayloads: true
randomBytesRatio: 0.5
randomizedPayloadPoolSize: 1000

subscriptionsPerTopic: 1
consumerPerSubscription: 2
producersPerTopic: 100

# Discover max-sustainable rate
producerRate: 200

consumerBacklogSizeGB: 0
warmupDurationMinutes: 5
testDurationMinutes: 5
```

## Run thw workload

```
bin/benchmark --drivers driver-redpanda/redpanda-ack-all-group-linger-1ms.yaml workloads/test.yaml
```

You may want to add the `-t swarm` option, but it's not clear what that does and only Wes seems to recommend it.


## Grafana

### BYOC?

If this was running against a BYOC cluster, you can use the dashboards we all know & love, plugging in your redpanda ID.

https://vectorizedio.grafana.net/d/fc1c587b-fcd6-41ad-8161-4f9b06b429fe/cluster-stats-sre-cs?orgId=1&var-datasource=VtFd5GIVz&var-redpanda_id=cnthrbjiuvqvkcfi4acg&from=now-30m&to=now&refresh=5s

https://vectorizedio.grafana.net/d/mnYfLYsnz/data-cluster-health-slos-and-slis?orgId=1&refresh=30s

### Self-hosted

Navigate to the IP of the prometheus host (found in `hosts.ini` under `driver-redpanda/deploy` where you ran terraform, on port 3000 (I'm pretty sure it's port 3000)


---
---
---



These instructions work pretty well.  Notable change is that the ansible-playbook step may need `--ask-become-pass` or else you may see some sudo errors.

```
  if [ "$(uname)" = "Darwin" ]; then export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES; fi
        ansible-galaxy install -r requirements.yml
        ansible-playbook --ask-become-pass deploy.yaml
```

Then ssh & run the workload





Pizza Hut Workload yaml example

```
topics: 1
partitionsPerTopic: 30
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

*Randomized payloads*
```
name: Test config

topics: 1
partitionsPerTopic: 30

messageSize: 1024
useRandomizedPayloads: true
randomBytesRatio: 0.5
randomizedPayloadPoolSize: 1000

subscriptionsPerTopic: 1
consumerPerSubscription: 2
producersPerTopic: 100

# Discover max-sustainable rate
producerRate: 200

consumerBacklogSizeGB: 0
warmupDurationMinutes: 5
testDurationMinutes: 5
```





## Pointing OMB at a BYOC Cluster

https://redpandadata.atlassian.net/wiki/spaces/CS/pages/325025793/Benchmarking+Redpanda+Cloud+for+Customers

This is the highly distilled version of Tristan's document.  If anything doesn't work, go back to his version, or the deployment-automation instructions.

```
git clone https://github.com/redpanda-data/openmessaging-benchmark
cd openmessaging-benchmark
mvn clean install -Dlicense.skip=true
```

You may want to tweak tfvars before you continue.
```
cd driver-redpanda
terraform init
```

### Spin up the resources

```
terraform apply --auto-approve --var=owner=cnelson
```

Set your BYOC cluster endpoint as an env variable to make the ansible deploy a little easier to tweak

```
export REDPANDA_BOOTSTRAP_SERVER="seed-17627eef.cnplkb3olu5rkpe5aqng.byoc.prd.cloud.redpanda.com:9092"
```

### Deploy Redpanda stuff

```
ansible-playbook --inventory  hosts.ini \
--ask-become-pass \
-e "tls_enabled=true sasl_enabled=true sasl_username=cnelson sasl_password=cnelson" \
-e bootstrapServers=${REDPANDA_BOOTSTRAP_SERVER} \
deploy.yaml
```


### Set up the workload test

####SSH into one of the client machines

```
ssh -i ~/.ssh/redpanda_aws ubuntu@$(terraform output --raw client_ssh_host)
```

#### Become root

```
sudo su -
cd /opt/benchmark
```



#### Configure Workload

This is an example workload configuration yaml, found in `driver-redpanda/deploy/workload

```
name:  pizzahut-8k-producers

topics: 1
partitionsPerTopic: 30
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

Base workload I've been testing with"
```
name: Test config

topics: 1
partitionsPerTopic: 30

messageSize: 1024
useRandomizedPayloads: true
randomBytesRatio: 0.5
randomizedPayloadPoolSize: 1000

subscriptionsPerTopic: 1
consumerPerSubscription: 2
producersPerTopic: 100

# Discover max-sustainable rate
producerRate: 200

consumerBacklogSizeGB: 0
warmupDurationMinutes: 5
testDurationMinutes: 5
```



TODO:  build a table of how these parameters actually work


### Run the test

Per Wes,  `-t swarm` is swarmensemble in OMB, instead of splitting the client machines in half it runs all threads on all servers and co-mingles them.

```
sudo bin/benchmark -t swarm -d driver-redpanda/pizzahut.yaml  driver-redpanda/deploy/workloads/pizzahutworkload.yaml
```

Or from Tristan's doc

```
bin/benchmark --drivers driver-redpanda/redpanda-ack-all-group-linger-1ms.yaml workloads/1-topic-100-partitions-1kb-4p-4c-200k.yaml
```


```
bin/benchmark --drivers driver-redpanda/redpanda-ack-all-group-linger-1ms.yaml workloads/test.yaml
```


### Troubleshooting



Adding this to line ~175 of `openmessaging-benchmark/benchmark-framework/src/main/java/io/openmessaging/benchmark/WorkloadGenerator.java` will allow you to see what's going on during the section where it tends to timeout.

`log.info("Messages received/expected...{} / {}", String.valueOf(stats.messagesReceived), String.valueOf(expectedMessages));`

And then add this to `openmessaging-benchmark/benchmark-framework/src/main/java/io/openmessaging/benchmark/worker
/SwarmWorker.java` around lines 306 & 310 (there are two functions that need similiar log messages to help see where this is breaking down).

```
 log.info("Beginning (void) sendPost to  {}", path);
```

### Note from Wes:

https://redpandadata.slack.com/archives/C05KTNT405R/p1710270297768269

```
1. you need to create your SASL acl user with a _audit* explicit deny because OMB is doing some bad mojo now and
2. if you built it private, make your clients in their own VPC and peer it .. trying to peer the default vpc would be not cool
```

```
ansible-playbook deploy.yaml \
-e "tls_enabled=True" \
--ask-become-pass \
--limit "client" \
-e "bootstrapServers=sseed-2b5bd9bd.cn7o04bpimm8ftui7adg.byoc.prd.cloud.redpanda.com:9092" \
-e "sasl_enabled=true sasl_username=cnelson sasl_password=cnelson"
```

```
ansible-playbook \
--inventory  hosts.ini \
--limit "client" \
-e "bootstrapServers=seed-2b5bd9bd.cn7o04bpimm8ftui7adg.byoc.prd.cloud.redpanda.com:9092" \
-e "tls_enabled=true" \
-e "sasl_enabled=true sasl_username=cnelson sasl_password=cnelson \
deploy.yaml
```

Then comment out this section of `deploy.yaml` to get around a dumb certs problem that shouldn't even exist.

```
#- name: Install certs
#  ansible.builtin.import_playbook: tls/install-certs.yml
#  when: tls_enabled| default(False)|bool == True
#  tags: tls
```


### Grafana for your OMB run

Open a brower window for the prometheus instance on port 3000.  User/pass is `admin` / `enter_your_secure_password` if you've taken the defaults.

If you want to generate the grafana dashboard config you can use rpk:  `rpk generate grafana > grafana.json` and then import that into grafana.  TODO:  need to double check that command

----

Surprise, nothing works.

Ran into an error related to hashicorp random not working on my mac's architecture.   Travis has a workaround, Tristan wrote an article about how to benchmark in Redpanda cloud (see below)

seems like the core of his fix was to comment out the version key/value under `provider "aws" {` and then to change the version of "random" to 3.4.3


Full diff from Travis:

```
diff --git a/driver-redpanda/deploy/provision-redpanda-aws.tf b/driver-redpanda/deploy/provision-redpanda-aws.tf
index e762f61..57c4d1d 100644
--- a/driver-redpanda/deploy/provision-redpanda-aws.tf
+++ b/driver-redpanda/deploy/provision-redpanda-aws.tf
@@ -1,11 +1,20 @@
+terraform {
+  required_providers {
+    aws = {
+      version = "~> 2.7"
+    }
+    random = {
+      version = "~> 3.4.3"
+    }
+  }
+}
 provider "aws" {
   region  = var.region
-  version = "~> 2.7"
+  #version = "~> 2.7"
   profile = var.profile
 }

 provider "random" {
-  version = "~> 2.1"
 }

 variable "public_key_path" {
 
```

Then you'll find that SSO doesn't work here, you'll need to export the AWS keys.

If you're missing the cloudalchemy node exporter piece, you probably missed the `ansible-galaxy install -r requirements.yaml` step.

Then you'll hit this, but I don't know how big a deal it is just yet.

```
TASK [add the redpanda repo] ************************************************************************************************************************************************************************************
fatal: [54.203.135.152]: FAILED! => {"changed": false, "msg": "Unsupported parameters for (ansible.legacy.command) module: warn. Supported parameters include: _raw_params, _uses_shell, argv, chdir, creates, executable, removes, stdin, stdin_add_newline, strip_empty_ends."}
fatal: [35.161.19.42]: FAILED! => {"changed": false, "msg": "Unsupported parameters for (ansible.legacy.command) module: warn. Supported parameters include: _raw_params, _uses_shell, argv, chdir, creates, executable, removes, stdin, stdin_add_newline, strip_empty_ends."}
fatal: [52.88.133.204]: FAILED! => {"changed": false, "msg": "Unsupported parameters for (ansible.legacy.command) module: warn. Supported parameters include: _raw_params, _uses_shell, argv, chdir, creates, executable, removes, stdin, stdin_add_newline, strip_empty_ends."}
```

If node_exporter gives you fits you can possibly determine if it's an ARM version or x86 version.   To force the arm version, under Install Node exporter add another var.  note also chnaged from cloudalchemy to geerlingguy.node exporter.  Had to add this to the requirements.yaml as well & re-run ansible-galaxy install -r requirements.yaml to pick it uppwd


*BASICALLY ANY TIME YOU SEE AN EXCEPTION INVOLVING module: warn YOU'LL NEED TO REMOVE THOSE WARN ENTRIES IN TYE YAML*

```
# Install the monitoring stack
- name: Install Node Exporter
  hosts: redpanda, client
  roles:
  - geerlingguy.node_exporter
  vars:
  - node_exporter_arch: arm64
  - node_exporter_enabled_collectors: [ntp]
  tags:
    - node_exporter
```


---

Benchmarking with Docker

Then I tried to build the docker image and do it that way.   Ran into some weird errors about stuff (licensing?) being missing from the head of some files.
https://github.com/redpanda-data/openmessaging-benchmark/tree/main/docker

If you modify `Dockerfile.build` line 19 to change from

`RUN mvn install`

to this:

`RUN mvn install -Dlicense.skip=true`

Then the dockerfile will build successfully.   How to get it to work from there remains to be seen.


---

## Benchmarking in Redpanda Cloud

https://vectorizedio.atlassian.net/wiki/spaces/CS/pages/325025793/Benchmarking+Redpanda+Cloud+for+Customers


Following those instructions give me this error:

`unable to login into Redpanda Cloud: unable to retrieve a cloud token: invalid_request: Invalid domain 'auth.prd.cloud.redpanda.com' for client_id 'MYag3daT6gtieYkHwiNUmoKtfxRiLSCr'`




---


or deploy an ec2 instance with my OMB image in us-west-2.  My fork of the repo puts it in us-east-2 (ohio).

install git?

clone repo
apply omb.patch
rename tcampbell to cnelson. (or remove completely?)
ansible-galaxy install -r requirements.yaml.  >> might need to change this to include geerlingguy.node_exporter instead
 - also make change on line ~377 of deploy.yaml, change cloudalchemy.node_exporter to geerlingguy.node_exporter
 - I forked the repo and applied these changes, need to test.

mvn clean install -Dlicence.skip=true

terraform init
terraform apply -auto-approve -var="public_key_path=~/.ssh/redpanda_aws.pub"

ansible-playbook deploy.yaml

_then remove references to args: warn_ 
 * one warn was found in ~/.ansible/roles/cloudalchemy.grafana/tasks/dashboards.yml

If running on x86, should just work.  If running on ARM (i.e. your M2 macbook) you'll need to further modify around line ~377 to tell it the required architecture for node_exporter.

```
# Install the monitoring stack
- name: Install Node Exporter
  hosts: redpanda, client
  roles:
  - geerlingguy.node_exporter
  vars:
  - node_exporter_arch: arm64
  - node_exporter_enabled_collectors: [ntp]
  tags:
    - node_exporter
```


Then once the bnechmark completes (or before you even start it) you need to install pip
`sudo apt install pip`
or possibly
`sudo apt-get install python3-pip`

To run the benchmark in the backkground:

```
nohup sudo bin/benchmark -d driver-redpanda/redpanda-ack-all-group-linger-10ms.yaml \
     driver-redpanda/deploy/workloads/1-topic-100-partitions-1kb-4-producers-500k-rate.yaml &
```

```
nohup sudo bin/benchmark -d driver-redpanda/redpanda-ack-all-group-linger-1ms.yaml \
     driver-redpanda/deploy/workloads/1-topic-100-partitions-1kb-4-producers-500k-rate.yaml &
```



then you can `tail -f ~/nohup.out` to continue watching the progress and not worry if your terminal window closes.

---


