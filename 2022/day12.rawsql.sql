\c
\echo --- Day 12: Hill Climbing Algorithm ---
\echo expect this to take about 30 seconds

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
  neighbors int[],
  rneighbors int[],
  unique(x, y)
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

with neighbor as (
  select map.id, array_agg(other.id) as neighbors
  from map
  inner join map as other
    on (map.x = other.x + 1 and map.y = other.y)
    or (map.x = other.x - 1 and map.y = other.y)
    or (map.x = other.x and map.y = other.y + 1)
    or (map.x = other.x and map.y = other.y - 1)
  where other.elevation <= map.elevation + 1
  group by 1
)
update map
set neighbors = neighbor.neighbors
from neighbor
where map.id = neighbor.id
;

with rneighbor as (
  select map.id, array_agg(other.id) as rneighbors
  from map
  inner join map as other
    on (map.x = other.x + 1 and map.y = other.y)
    or (map.x = other.x - 1 and map.y = other.y)
    or (map.x = other.x and map.y = other.y + 1)
    or (map.x = other.x and map.y = other.y - 1)
  where map.elevation <= other.elevation + 1
  group by 1
)
update map
set rneighbors = rneighbor.rneighbors
from rneighbor
where map.id = rneighbor.id
;

/*
 * The problem
 */

-- Part 1: shortest path

with recursive
start1 as (
  select id from map where is_start
),
end1 as (
  select id from map where is_end
),
dijkstra1 as (
  select
    0 as i,
    array[(select id from start1)]::int[] as queue,
    array[]::int[] as visited,
    '{}'::jsonb as distances
  union all
  select
    i + 1,
    new_queue,
    case when map.id is null then visited else visited || map.id end,
    new_distances
  from dijkstra1
  cross join lateral (select queue[1]) as _1(node)
  left join map on node = map.id and not (visited @> array[node])
  cross join lateral (
    select array_agg(neighbor)
    from (select unnest(map.neighbors)) _(neighbor)
    where not (visited @> array[neighbor])
  ) _2(unseen_neighbors)
  -- Update distances object
  cross join lateral (
    select jsonb_object_agg(
      neighbor,
      least(
        coalesce((distances->(node::text))::int, 0) + 1,
        coalesce((distances->(neighbor::text))::int, 999999999)
      )
    )
    from (select unnest(unseen_neighbors)) as _(neighbor)
  ) as _3(distance_updates)
  cross join lateral (
    select case
      when distance_updates is null then distances
      else distances || distance_updates
    end
  ) as _4(new_distances)
  -- update queue (not sorting the queue since this is really BFS since all the
  -- weights are the same, so the longest paths should always end up at the
  -- end of the queue anyways, and sorting takes forever)
  cross join lateral (select queue[2:] || unseen_neighbors) as _5(new_queue)
  where node is not null
    and not(visited @> (select array_agg(id) from end1))
),
part1(part, answer) as (
  select 'part1', (distances->(select id from end1)::text)::int
  from dijkstra1
  order by i desc
  limit 1
),

-- Part 2: shortest path from any 'a' to 'E'

-- going backwards from E until we find an a
start2 as (
  select id from map where is_end
  /* and false */
),
end2 as (
  select id from map where elevation = ascii('a')
),
dijkstra2 as (
  select
    0 as i,
    array[(select id from start2)]::int[] as queue,
    array[]::int[] as visited,
    '{}'::jsonb as distances
  union all
  select
    i + 1,
    new_queue,
    case when map.id is null then visited else visited || map.id end,
    new_distances
  from dijkstra2
  cross join lateral (select queue[1]) as _1(node)
  left join map on node = map.id and not (visited @> array[node])
  cross join lateral (
    select array_agg(neighbor)
    -- reverse neighbors since we're going backward
    from (select unnest(map.rneighbors)) _(neighbor)
    where not (visited @> array[neighbor])
  ) _2(unseen_neighbors)
  -- Update distances object
  cross join lateral (
    select jsonb_object_agg(
      neighbor,
      least(
        coalesce((distances->(node::text))::int, 0) + 1,
        coalesce((distances->(neighbor::text))::int, 999999999)
      )
    )
    from (select unnest(unseen_neighbors)) as _(neighbor)
  ) as _3(distance_updates)
  cross join lateral (
    select case
      when distance_updates is null then distances
      else distances || distance_updates
    end
  ) as _4(new_distances)
  cross join lateral (select queue[2:] || unseen_neighbors) as _5(new_queue)
  where node is not null
    and not(visited @> (select array_agg(id) from end2))
),
part2(part, answer) as (
  select 'part2', min(value::int)
  from dijkstra2
  cross join lateral (select * from jsonb_each(distances)) as _(key, value)
  where key in (select id::text from end2)
)

-- Answers

select * from part1
union all
select * from part2
;
