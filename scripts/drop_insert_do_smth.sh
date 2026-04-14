#!/bin/bash

psql -f scheme.sql postgres
psql -f inserts.sql postgres
psql -f triggers.sql postgres
