# Setting up the OMB UI (tm)

Disclaimer:  This is currently slightly BYOC-centric.


## Step 1:  

### Spin up OMB using Terraform & Ansible 

(see "Benchmarking BYOC" here, or the actual OMB repo under redpanda-data)


## Step 2:  

### ssh to an OMB worker


## Step 3:  

### Install OMB UI

The actual repo:  https://github.com/supahcraig/omb_ui

From your local machine, run setup.sh via curl — this installs system prerequisites and clones the repo:

```bash
ssh -i ~/.ssh/redpanda_gcp ubuntu@<worker-ip> \
  "curl -fsSL https://raw.githubusercontent.com/supahcraig/omb_ui/main/setup.sh | bash"
```

Then SSH in and run deploy.sh interactively to configure .env:

```bash
ssh -i ~/.ssh/redpanda_gcp ubuntu@<worker-ip>
bash ~/omb_ui/deploy.sh
```

This will prompt you for several env variables that will be used to build the driver.yaml & inspect the cluster metrics. 

## Step 4:

Navigate to the public IP of the worker where you installed omb_ui, port 8888.   Note you may need to open up 8888 at the firewall.
TODO:  modify ansible to open this port

## Step 5:

Use the UI to configure a workload and run your benchmark.
