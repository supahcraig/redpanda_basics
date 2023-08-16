Beginning with version 23.2 rpk now supports the concept of a profile, which makes it easier to deal with rpk configurations on the client side.  


There are lots of things you can do, but these seem to be the most helpful.

`rpk profile list`
`rpk profile print`
`rpk profile clear`
`rpk profile edit`

If you have a BYOC or Dedicated cluster you can generate the profile using `rpk profile create --from-cloud` which will give you a list of cloud clusters that it will generate the config from.

This eliminates the need to use env vars or a local copy of `redpanda.yaml` which always felt weird since `redpanda.yaml` is also the name of the broker-side config.
