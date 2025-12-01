# Advent of SQL

## Quickstart

```sh
# Start postgres in docker
# I used pgrouting in 2022 b/c I got tired of writing slow dijkstra in sql
docker run --rm -e POSTGRES_PASSWORD=friend -p5432:5432 corpusops/pgrouting-bare:17-3-3.4

# Run a day via psql
psql postgresql://postgres:friend@localhost:5432/postgres < 2021/day04.sql

# Run all days
cat 2021/day??.sql | psql postgresql://postgres:friend@localhost:5432/postgres -q
```
