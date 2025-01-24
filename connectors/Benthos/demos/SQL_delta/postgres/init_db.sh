#!/bin/bash

psql -U admin -d postgres -c "CREATE DATABASE inventory;"

psql -U admin -d inventory -f /inventory.sql
