
The geo functions require an input "database" from Maxmind.  You can get a free trial to download the `mmdb` files.   


## Reponse payload

```json
{"client_ip":"137.230.83.61","country":{"Continent":{"Code":"NA","GeoNameID":6255149,"Names":{"de":"Nordamerika","en":"North America","es":"Norteamérica","fr":"Amérique du Nord","ja":"北アメリカ","pt-BR":"América do Norte","ru":"Северная Америка","zh-CN":"北美洲"}},"Country":{"GeoNameID":6252001,"IsInEuropeanUnion":false,"IsoCode":"US","Names":{"de":"USA","en":"United States","es":"Estados Unidos","fr":"États Unis","ja":"アメリカ","pt-BR":"EUA","ru":"США","zh-CN":"美国"}},"RegisteredCountry":{"GeoNameID":6252001,"IsInEuropeanUnion":false,"IsoCode":"US","Names":{"de":"USA","en":"United States","es":"Estados Unidos","fr":"États Unis","ja":"アメリカ","pt-BR":"EUA","ru":"США","zh-CN":"美国"}},"RepresentedCountry":{"GeoNameID":0,"IsInEuropeanUnion":false,"IsoCode":"","Names":null,"Type":""},"Traits":{"IsAnonymousProxy":false,"IsAnycast":false,"IsSatelliteProvider":false}}}
```




## RPCN Config

This config pulls out a few components from the payload.

TODO:  cache results
TODO:  error trap for missing locations

```yaml
input:
  generate:
    interval: 3s
    mapping: |
      root.client_ip =  random_int(seed:timestamp_unix_nano(), max:255).string() + "." + random_int(seed:timestamp_unix_nano(), max:255).string() + "." + random_int(seed:timestamp_unix_nano(), min:1, max:255).string() + "." + random_int(seed:timestamp_unix_nano(), max:255).string()


pipeline:
  processors:
    - mapping: |
        root = this
        root.country.continent.name = this.client_ip.geoip_country("./GeoLite2-Country.mmdb").Continent.Names.en
        root.country.name = this.client_ip.geoip_country("./GeoLite2-Country.mmdb").Country.Names.en
        root.country.IsoCode = this.client_ip.geoip_country("./GeoLite2-Country.mmdb").Country.IsoCode
        root.country.Traits = this.client_ip.geoip_country("./GeoLite2-Country.mmdb").Country.Traits

output:
  stdout: {}
```


### Routing based on output




--- 

## Using CSV

Ash gave me this example of using a CSV that has the data instead.  Not sure how this works exactly.

```
let db = file("foo.csv").parse_csv()

root.foo = $db.find(row -> row.ip == this.ip_address)
```
