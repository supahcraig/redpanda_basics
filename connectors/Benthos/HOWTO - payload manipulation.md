# How to manipulate payloads with mappings

## Modifying fields


### Via mapping

```yaml
pipeline:
  processors:
    - mapping: |
        root = this
        root.name = this.name.uppercase()
```

### Via mutation

_unclear what the difference is between mapping & mutation_

```yaml
pipeline:
  processors:
    - mutation: |
        root.name = this.name.uppercase()
```



## Adding a field


```yaml
pipeline:
  processors:
    - mutation: |
        root.status = if this.assignment_score >= 50 { "passed" } else { "failed" }
```



## Conditionally dropping an entire row


```yaml
pipeline:
  processors:
    - mutation: |
        root = if this.class == "FORTRAN" { deleted() }
```

## Restructuing a document

this takes the inbound payload and pushes it down into a sub-document.

i.e. if your incoming payload is 

```json
{foo: bar, biz: zip}
```

but you need it to look more like this: 

```json
{raw_json: {{oo: bar, biz: zip}`
```

### Pipeline mutation

```yaml
pipeline:
  processors:
    - mapping: |
        root = {
          "raw_json": this
        }
```

### Mapping within a processor

```yaml

