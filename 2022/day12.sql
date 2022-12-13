\c
\echo --- Day 12: Hill Climbing Algorithm ---

-- This uses pgrouting
-- I also did this in vanilla sql, see day12.rawsql.sql

/*
 * Schema
 */

create temp table map (
  id int primary key,
  x int,
  y int,
  elevation int,
  is_start boolean,
  is_end boolean,
  unique(x, y)
);

create temp table map_edge (
  id int primary key generated always as identity,
  source int,
  target int,
  cost int,
  rcost int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day12.sample.txt' */
\copy raw_input(line) FROM '2022/day12.txt'

insert into map(id, x, y, elevation, is_start, is_end)
select
  col * 100000 + id,
  col,
  id,
  case
    when ltr = 'S' then ascii('a')
    when ltr = 'E' then ascii('z')
    else ascii(ltr)
  end,
  ltr = 'S',
  ltr = 'E'
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as _(ltr, col)
;

insert into map_edge(source, target, cost, rcost)
select
  map.id,
  other.id,
  case when other.elevation <= map.elevation + 1
    then 1
    else null
  end as cost,
  case when map.elevation <= other.elevation + 1
    then 1
    else null
  end as rcost
from map
inner join map as other
  on (map.x = other.x + 1 and map.y = other.y)
  or (map.x = other.x - 1 and map.y = other.y)
  or (map.x = other.x and map.y = other.y + 1)
  or (map.x = other.x and map.y = other.y - 1)
;

/*
 * The problem
 */

-- Part 1: shortest path from S to E

with
part1(part, answer) as (
  select 'part1', agg_cost
  from pgr_dijkstraCost(
    'select id, source, target, cost
    from map_edge
    where cost is not null',
    (select id from map where is_start),
    (select id from map where is_end)
  )
),

-- Part 1: shortest path E to any a

part2(part, answer) as (
  select 'part2', min(agg_cost)
  from pgr_dijkstraCost(
    'select id, source, target, rcost as cost
    from map_edge
    where rcost is not null',
    (select id from map where is_end),
    (select array_agg(id) from map where elevation = ascii('a'))
  )
)

-- Answers

select * from part1
union all
select * from part2
;
