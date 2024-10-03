

# Repdanda Connect bloblang/mapping examples


---

## Input json


```json
{
   "timestamp":"2024-10-01T16:01:21Z",
   "event_id":"1632a866-a6ab-4f6c-85a8-417bd4550a48",
   "source_system":"auth_service",
   "reference":"ZTJMKDMBNRLOYJRZGFLDQAPY",
   "machine_code":"82807888136045504903204305261984150575659914781168",
   "client_ip":"192.168.1.151",
   "log_level":"ERROR",
   "message":"Page not found.",
   "request_id":"req3630",
   "context":{
      "user_id":"user612",
      "path":"/profile",
      "method":"DELETE",
      "status_code":401
   },
   "errors":[
      {
         "code":"E404",
         "description":"Not Found",
         "details":"The requested resource was not found."
      },
      {
         "code":"E500",
         "description":"Server Error",
         "details":"Internal server error occurred."
      },
      {
         "code":"E505",
         "description":"HTTP Version Not Supported",
         "details":"The server does not support the HTTP version used."
      },
      {
         "code":"E502",
         "description":"Bad Gateway",
         "details":"Received an invalid response from the upstream server."
      },
      {
         "code":"E503",
         "description":"Service Unavailable",
         "details":"The server is temporarily unavailable."
      }
   ],
   "metadata":[
      {
         "key":"browser",
         "value":"Chrome"
      },
      {
         "key":"os",
         "value":"Linux"
      }
   ]
}
```

## Adding a field to an incoming document


### Simple field addition

```yaml
pipeline:
  processors:
    - mapping: |
        root = this
        root.new_field = "this is the value for your new field"
```

### Add field conditionally

This will add a field called `priority`, and the value of that field is set using the `match` function.   The `=>` operator is how the field assignment is performed.  `_ =>` is the default/unmatched case.

```yaml
pipeline:
  processors:
    - mapping: |
        root = this
        root.priority = match this {
            this.source_system == "payment_gateway" && this.message == "Server latency detected."   => 1 ,
            this.source_system == "payment_gateway" ||  this.source_system == "inventory_system" => 2 ,
            this.source_system == "auth_service"  => 3 ,
            _ => 4,
        }
```



## Removing a field from a document

NOTE:  `mapping` used to be called `bloblang`, you may find old references.

### using `mapping`

This will remove the timestamp field

```yaml
pipeline:
  processors:
    - mapping: |
        root = this
        root.timestamp = deleted()
```

But you might have elements from an array you want to remove.  This will remove the `description` key from the each `error` under the `errors` array.


```yaml
pipeline:
  processors:
    - mapping: |
        root = this
        root.errors = this.errors.map_each(e -> e.without("description"))
```

This same key removeal can also be done with a reusable mapping:

```yaml


map stuff {
  root.description = deleted()
}

root.errors = this.errors.map_each(e -> e.apply("stuff"))

```yaml
    - mapping: |
        root = this

        map remove_stuff {
          root.description = deleted()
        }

        root.errors = this.errors.map_each(e -> e.apply("remove_stuff"))
```



### using `jq`


```yaml
- jq:
        query: 'del(.reference, .machine_code, .request_id)'
        raw: false
```
