The only interesting thing in this example is in the output section:

`topic: '${! json("Name")}-${! json("Gooeyness") * 100}'`

Where the output topic is determined by inspecting some values within the message.  In this case the topic name will be the `Name` and `Gooeyness` multipled by 100, separated by a `-`


```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 5)

output:
  kafka:
    addresses: [localhost:19092]
    topic: '${! json("Name")}-${! json("Gooeyness") * 100}'
```
