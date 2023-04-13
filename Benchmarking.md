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


or deploy an ec2 instance with my OMB image in us-west-2

install git?

clone repo
apply omb.patch
rename tcampbell to cnelson. (or remove completely?)
ansible-galaxy install -r requirements.yaml.  >> might need to change this to include geerlingguy.node_exporter instead
 - also make change on line ~377 of deploy.yaml, change cloudalchemy.node_exporter to geerlingguy.node_exporter

mvn clean install -Dlicence.skip=true

terraform init
terraform apply -auto-approve

ansible-playbook deploy.yaml

_then remove references to args: warn_ 
one may have been in an external file; not one that is part of this repo.   TODO:  need to find that reference and understand if it was a cloudalchemy file or if geerlingguy resolves it.

---


