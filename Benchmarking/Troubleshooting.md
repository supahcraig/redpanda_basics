# Redpanda Benchmarks

This is a fork of the redpanda/openmessaging-benchmark repo which contains some necessary modifications to make it deploy, and also some other helpful commands to make the latter stages work more easily.

## Requirements

- Terraform

- Ansible

- Python 3 set as default.

- The [terraform inventory plugin](https://github.com/adammck/terraform-inventory)

In AWS, us-east-2, an AMI is available which has these dependencies already installed.

## Setup

0. Clone this repo to wherever you are going to deploy from.   EC2, local machine, docker container...

1. In the top level directory run the maven build.  This will build the benchmark client needed during deployment.
	`mvn clean install -Dlicense.skip=true`

2. Create an ssh key for the benchmark, set the password to blank (just hit enter twice)
	`ssh-keygen -f ~/.ssh/redpanda_aws`. Set the password to blank.

3. cd to the deployment directory:
	`cd driver-redpanda/deploy`

3. Install the node exporter, grafana, & prometheus components
	`ansible-galaxy install -r requirements.yaml`

4. In the `driver-redpanda/deploy` directory.  Run the following to spin up the cloud resources.

        terraform init
        terraform apply -auto-approve -var="public_key_path=~/.ssh/redpanda_aws.pub"

5. To setup the deployed nodes. Run:

        ansible-playbook deploy.yaml
	
* If you're using ansible-core >= 2.14.x, then you may run into trouble if `args: warn` is in use.   Just remove the `warn` line from the yaml.
 * Those references have been removed from this fork of the repo
 * The node_exporter tasks may still have references to `args: warn`
 * Specifically the cloudalchemy.node_exporter uses a `warn`, I don't recall if `geerlingguy.node_exporter` does.   
* If you're deploying on arm64 architecture (unclear if I'm talking about where you are deploying _from_ or where you are deploying _to_) then you'll need to add this to the vars section of the Install Node Exporter task (line ~377).   See Troubleshooting below for more info.

	`- node_exporter_arch: arm64`

---

## Running the benchmark

1. SSH to the client machine. 

        ssh -i ~/.ssh/redpanda_aws ubuntu@$(terraform output --raw client_ssh_host)

2. Change into the benchmark directory 

        cd /opt/benchmark

3. Run a benchmark using a specific driver and workload, for example: 

        sudo bin/benchmark -d driver-redpanda/redpanda-ack-all-group-linger-10ms.yaml \
            driver-redpanda/deploy/workloads/1-topic-100-partitions-1kb-4-producers-500k-rate.yaml

---

## Generating charts

Once you have ran a benchmark, a json file will be generated in the data directory. You can use `bin/generate_charts.py` to generate a a visual representation of this data.

First install the python script's prerequisites & create the necessary directories:

```bash
sudo mkdir ./bin/data
sudo mkdir ./output
sudo apt install pip
sudo python3 -m pip install numpy jinja2 pygal
```

The script has a few flags to say where the benchmark output file is, where the output will be stored, etc. Run the script with the help flag for more details (from the project's root directory):

```bash
./bin/generate_charts.py -h
```

Then run the script. The following example looks for benchmark files in `bin/data` and sends output to the folder created above:

```bash
cp ./*.json ./bin/data/.
./bin/generate_charts.py --results ./bin/data --output ./output
```

The output of this command is web page with charts for throughput, publish latency, end-to-end latency, publish rate, and consume rate (open in your favorite browser).

---

## Cleanup

Once you are done. Tear down the cluster with the following command: 

	terraform destroy -auto-approve -var="public_key_path=~/.ssh/redpanda_aws.pub"


---
# Troubleshooting

## args: warn

Later versions of ansible will throw fatal exceptions if if finds cases where `args:` is used with the `warn` keyword, similar to this: 

```
fatal: [54.203.135.152]: FAILED! => {"changed": false, "msg": "Unsupported parameters for (ansible.legacy.command) module: warn. Supported parameters include: _raw_params, _uses_shell, argv, chdir, creates, executable, removes, stdin, stdin_add_newline, strip_empty_ends."}
```

It may also manifest itself like this:

```
TASK [cloudalchemy.grafana : download grafana dashboard from grafana.net to local directory] *****************************************************************************************************************************************************************************************
FAILED - RETRYING: [3.15.6.253 -> localhost]: download grafana dashboard from grafana.net to local directory (5 retries left).
FAILED - RETRYING: [3.15.6.253 -> localhost]: download grafana dashboard from grafana.net to local directory (4 retries left).
FAILED - RETRYING: [3.15.6.253 -> localhost]: download grafana dashboard from grafana.net to local directory (3 retries left).
FAILED - RETRYING: [3.15.6.253 -> localhost]: download grafana dashboard from grafana.net to local directory (2 retries left).
FAILED - RETRYING: [3.15.6.253 -> localhost]: download grafana dashboard from grafana.net to local directory (1 retries left).
failed: [3.15.6.253 -> localhost] (item={'dashboard_id': 1860, 'revision_id': 21, 'datasource': 'prometheus'}) => {"ansible_loop_var": "item", "attempts": 5, "changed": false, "item": {"dashboard_id": 1860, "datasource": "prometheus", "revision_id": 21}, "msg": "Unsupported parameters for (ansible.legacy.command) module: warn. Supported parameters include: _raw_params, _uses_shell, argv, chdir, creates, executable, removes, stdin, stdin_add_newline, strip_empty_ends."}
```

The resolution is to remove the `warn: false` line from (or near) line 21 of `~/.ansible/roles/cloudalchemy.grafana/tasks/dashboards.yml`


Simply removing the `warn` references will resolve this issue.   _Allegedly_ using ansible-core 2.13.x will also resolve this, but I have not confirmed.


## amd64 vs x86

You may encounter an error when the node exporter is verifying it can respond to requests, with an exception that looks like this:

```
TASK [geerlingguy.node_exporter : Verify node_exporter is responding to requests.] ***************************************************************************************************************************************************************************************************
fatal: [3.133.108.145]: FAILED! => {"changed": false, "content": "", "elapsed": 0, "failed_when_result": true, "msg": "Status code was -1 and not [200]: Request failed: <urlopen error [Errno 111] Connection refused>", "redirected": false, "status": -1, "url": "http://localhost:9100/"}
```

SSH to the node and verify if the node exporter service is running.   Most likely it isn't.

	`systemctl type==service`
	
Then check the status of the node_exporter service:

	`systemctl status node_exporter`
	
will probably result in something like this:

```
ubuntu@ip-10-0-0-163:~$ systemctl status node_exporter
● node_exporter.service - NodeExporter
     Loaded: loaded (/etc/systemd/system/node_exporter.service; enabled; vendor preset: enabled)
     Active: failed (Result: exit-code) since Mon 2023-04-17 16:21:56 UTC; 2h 24min ago
    Process: 19866 ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100 (code=exited, status=203/EXEC)
   Main PID: 19866 (code=exited, status=203/EXEC)

Apr 17 16:21:56 ip-10-0-0-163 systemd[1]: Started NodeExporter.
Apr 17 16:21:56 ip-10-0-0-163 systemd[19866]: node_exporter.service: Failed to execute command: Exec format error
Apr 17 16:21:56 ip-10-0-0-163 systemd[19866]: node_exporter.service: Failed at step EXEC spawning /usr/local/bin/node_exporter: Exec format error
Apr 17 16:21:56 ip-10-0-0-163 systemd[1]: node_exporter.service: Main process exited, code=exited, status=203/EXEC
Apr 17 16:21:56 ip-10-0-0-163 systemd[1]: node_exporter.service: Failed with result 'exit-code'.
```

The `Exec format error` is your smoking gun, but _exactly_ WHY remains a mystery.   You'll need to determine the architecture of your EC2 instances using

	`uname -a`
	
and then check the archiecture of the node exporder file:

	`file /usr/local/bin/node_exporter`
	
Very likely you will see that your node exporter file is x86-64, which conflicts with the aarch64 of the is4gen EC2 instance class.
	
The is4gen instance types (which are what our terraform spec deploys by detault) are ARMs, so we need to tell Ansible to use the arm64 flavor of the node exporter.  If no architecture is specified it will deploy the x86 flavor  Inside the `deploy.yaml`, near line ~377 you'll need to add an entry under `vars` for `node_exporter_arch: arm64`


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

_NOTE_ this only appears to be an issue if I run from my M2 macbook.   If I run all this from an EC2 instance (even an x86 instance) it appears to work w/o the addition var line.  Per Travis Campbell, something about geerlingguy.node_exporter looks at the architecture of the deploying machine (that is, where ansible is running) to determine the correct architecture for the node exporter.   See line ~15 of `/Users/cnelson/.ansible/roles/geerlingguy.node_exporter/tasks/main.yml` to further debug this.   For the time being, adding the node exporter arch variable seems to resolve it throughout.





## AWS credentials/session

For some reason, terraform with OMB will not use the aws profile (unlike how it works in deployment-automation).  Instead you need to copy temporary access & secret keys into environment variables.   This is most likely to appear during the terraform apply/destroy steps.

```
│ Error: error configuring Terraform AWS Provider: error validating provider credentials: error calling sts:GetCallerIdentity: operation error STS: GetCallerIdentity, https response error StatusCode: 403, RequestID: 76ce0a10-f79e-44c9-85fb-4eefb20d6d7b, api error ExpiredToken: The security token included in the request is expired
│
│   with provider["registry.terraform.io/hashicorp/aws"],
│   on provision-redpanda-aws.tf line 11, in provider "aws":
│   11: provider "aws" {
```

