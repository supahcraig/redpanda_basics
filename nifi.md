# Connecting to Redpanda via Apache Nifi


## BYOC Cluster

* Kafka Brokers:  this is the bootstrap URL from the Overview/Kafka API tab in BYOC UI.   Should include the port, but does not need "http://"
* Transactions:  false
* Security Protocol:  SASL_SSL, this can be determined again from the Overview/Kafka API tab.
* SASL Mechanism:  SCRAM-SHA-256. _You would have chosen 256 or 512 when the user was created_
* Username: username you created under the Security tab in BYOC UI
* Password: password you created.  You can't get back to this after you create the user, so don't forget it.


You may need to set ACL's wide open to allow for stuff to happen, including consume.

---

## Redpanda Dedicated

Same exact setup as BYOC.

---

## EKS



---

## Standalone
