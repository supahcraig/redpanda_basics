If you want to see a static version of the output from your OMB run, you can do it directly on the broker without too much effort.


While sudo'd & from the /opt/benchmark directory (which you probably are already in...), run these commands.   It will handle the python setup, which you only need to run once.   Then for each run of OMB, you can run the generate script which will turn the output json into an index.html file.   Lastly it will spin up a simple http server on port 8888 so you can view the charts.   

NOTE:  you will need to open up port 8888 in the security group for your OMB worker.



```bash
apt install -y python3-pip

pip install -r bin/requirements.txt
pip install "pygal==2.4.0"

mkdir results
mkdir results/report
```

Then copy your json to the results folder.

Then run the generate script:

```bash
python3 bin/generate_charts.py   --results ./results --output ./results/report/
python3 -m http.server 8888
```

Navigate your browser to the public IP of your worker:  `http://public.ip:8888`



Copying multiple json outputs into the results folder and then re-running the chart generator will give you a nice overlaid set of charts for multiple runs.


---

# Quick Look at percentile results without hassling with the charts

You probably just want a quick look at the final results broken down by percentile, but also probably don't always want to take the time to move the files and generate the charts.  This shell script will take a results json file and calculate the results into a table like this:

```text
=== Latency (milliseconds) ===
Percentile  Min    Max  Avg
p50         2.176  ms   2.232    ms  2.199   ms
p95         3.143  ms   3.257    ms  3.177   ms
p99         3.595  ms   7.151    ms  3.807   ms
p99.9       4.739  ms   204.107  ms  11.708  ms
p99.99      5.767  ms   229.719  ms  14.331  ms

=== Throughput (messages/sec) ===
Type     Min                 Max                 Avg
publish  499674.66251596157  510762.9416454764   500360.4015304407
consume  499640.74537333904  510827.25542777375  500361.428917911
```

Save this script as `/opt/benchmark/agg_results.sh`

```bash
#!/usr/bin/env bash
#
# Usage: ./omb-summary.sh <results.json>
# Example: ./omb-summary.sh workload.json

FILE="$1"

if [[ -z "$FILE" ]]; then
  echo "Usage: $0 <json-file>"
  exit 1
fi

echo "=== e2e Latency (milliseconds) ==="
jq -r '
  def round3: ((.*1000 | round) / 1000);   # 👈 define jq function here

  {
    "p50":     .endToEndLatency50pct,
    "p95":     .endToEndLatency95pct,
    "p99":     .endToEndLatency99pct,
    "p99.5":   .endToEndLatency99_5pct,
    "p99.9":   .endToEndLatency999pct,
    "p99.99":  .endToEndLatency9999pct,
    "p99.999": .endToEndLatency99999pct
  }
  | to_entries[]
  | select(.value != null and (.value|length > 0))
  | [
      .key,
      ((.value|min)|round3|tostring + " ms"),
      ((.value|max)|round3|tostring + " ms"),
      (((.value|add) / (.value|length))|round3|tostring + " ms")
    ]
  | @tsv
' "$FILE" \
| (echo -e "Percentile\tMin\tMax\tAvg"; cat) \
| column -t

echo ""
echo "=== Throughput (messages/sec) ==="
jq -r '
  {
    "publish": .publishRate,
    "consume": .consumeRate,
    "agg_pub": .aggregatedPublishRate
  }
  | to_entries[]
  | select(.value != null and (.value|length > 0))
  | [
      .key,
      (.value|min|tostring),
      (.value|max|tostring),
      (((.value|add) / (.value|length))|tostring)
    ]
  | @tsv
' "$FILE" \
| (echo -e "Type\tMin\tMax\tAvg"; cat) \
| column -t
```
