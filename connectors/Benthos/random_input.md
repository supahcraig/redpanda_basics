I nabbed this from https://youtu.be/HzuqbNw-vMo


```yaml
input:
  generate:
    interval: 1s
    mapping: |
      root.ID = uuid_v4()
      root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)
      root.Gooeyness = (random_int() % 100) / 100
```


## How does it work?

I have no idea of the depths of what can be done here, but here is how THIS piece works.


* `root.ID = uuid_v4()`
  Generates a unique value into the ID key of the output json
* `root.Name = ["frosty", "spot", "oodles"].index(random_int() % 3)`
  Picks a random int between 0-2 and selects the array element with that index, assigns it to the name key of the output json
* `root.Gooeyness = (random_int() % 100) / 100`
  Takes a random int between 0-99, divides by 100, and assigns it to the Gooeyness key of the output json


## Output

```json
{"gooeyness":"0.62", "id":"50cceeae-9c49-464f-a5cb-c39646975004", "name":"oodles"}
{"gooeyness":"0.64", "id":"7f051f9d-e1ed-4610-90e9-24fd8a5c6bde", "name":"frosty"}
{"gooeyness":"0.63", "id":"2c2b78a2-a024-43f5-9fa4-eacd4a8d0be4", "name":"spot"}
```
