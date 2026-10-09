#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE DATABASE tytrip_catalog;
  CREATE DATABASE tytrip_shard_one;
  CREATE DATABASE tytrip_shard_two;
  CREATE DATABASE tytrip_back_queue;
  CREATE DATABASE tytrip_back_cache;
  CREATE DATABASE tytrip_back_cable;
EOSQL