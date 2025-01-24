#!/bin/bash

psql -h postgres -U admin -d postgres -c "CREATE DATABASE inventory;"

psql -h postgres -U admin -d inventory -f /inventory.sql
