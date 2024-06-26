# Airgapped Redpanda Install




## Add the Redpanda Repo
From an internet accessible machine, get & run the shell script to add the Redpanda repo.

```bash
curl -1sLf 'https://packages.vectorized.io/nzc4ZYQK3WRGd9sy/redpanda/cfg/setup/bash.rpm.sh' | sudo -E bash
```


## Download the Redpanda RPM

* Redpanda

```bash
sudo yum install --downloadonly --downloaddir=/tmp redpanda
```

* Console

```bash
sudo yum install redpanda-console --downloadonly --downloaddir=/tmp
```


_You may need to first install `yum-plugin-downloadonly` but this (a) isn't readily available and (b) on CentOS7 & Amazon Linux 2 isn't necessary._

Copy the redpanda rpm file to each broker through any means available, and copy the Console rpm to the machine that will host Console (simplest case:  Console runs on one of your brokers).


## Install the Redpanda package

* Redpanda

```bash
sudo rpm -i redpanda-23.1.8-1.x86_64.rpm
```

* Console

```bash
sudo rpm -i redpanda-console-2.2.4.x86_64.rpm
```

(Your version #'s will vary)


---

Once you have the packages installed, follow the other install/setup guides.
