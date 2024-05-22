

Certs are not my superpower.  This is was done via chatGPT.   No idea how this is going to go.


## 1.  Generate Certificates

### 1a.  Create Certificate Authority (CA)

From local machine...

```
openssl req -x509 -new -nodes -keyout ca.key -out ca.crt -days 365 \
-subj "/C=US/ST=State/L=Locality/O=Organization/OU=Unit/CN=example.com"
```


### 1b.  Create a Server Certificate


#### 1b-1.  Generate a private key for the server

From same place where the ca.crt lives

```
openssl genpkey -algorithm RSA -out server.key
```

#### 1b-2.  Create a certificate signing request (CSR)

From the same place where the server.key lives

```
openssl req -new -key server.key -out server.csr -subj "/C=US/ST=State/L=Locality/O=Organization/OU=Unit/CN=server.example.com"
```

#### 1b-3.  Sign the CSR with the CA:

```
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365
```


### 1c.  Create a Client Certificate

From local machine...

#### 1c-1.  Generate a private key for the client

```
openssl genpkey -algorithm RSA -out client.key
```

#### 1c-2.  Create a CSR

```
openssl req -new -key client.key -out client.csr \
-subj "/C=US/ST=State/L=Locality/O=Organization/OU=Unit/CN=client.example.com"
```


#### 1c-3.  Sign the CSR with the CA

```
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out client.crt -days 365
```

### 1d.  Transfer the Certficiates

_On the broker_, you'll need a folder for the certs:

```
sudo mkdir /etc/redpanda/certs
sudo chown redpanda:redpanda /etc/redpanda/certs
sudo chmod 777 /etc/redpanda/certs
```

The 777 permission is to allow ubuntu to write to the directory when the scp command is issued.


```
scp -i ~/pem/cnelson-kp.pem ca.crt server.key server.crt ubuntu@3.17.174.176:/etc/redpanda/certs
```


---






