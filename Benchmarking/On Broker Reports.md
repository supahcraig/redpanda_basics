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
