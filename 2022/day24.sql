\c
\echo --- Day 24: Blizzard Basin ---
\echo expect about 15 seconds

/*
 * Schema
 */

-- The query plans seem to work a lot better (and are more likely to use
-- indexes) when storing points as a single number. We only have to deal with
-- a max of 600 in any dimension (lcm of width 120 and height 25), so using
-- 1000 as the factor works well enough.
drop function if exists point_id;
create function point_id(x integer, y integer, z integer default 0) returns integer as $$
  select z * 1000000 + y * 1000 + x;
$$ language sql immutable;


create temp table blizzard (
  x int,
  y int,
  id int generated always as (point_id(x, y)) stored,
  dx int,
  dy int,
  unique(id)
);

create temp table grid_size (
  width int,
  height int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day24.sample.txt' */
\copy raw_input(line) FROM '2022/day24.txt'

with blizzard_tile(tile, dx, dy) as (
  values
    ('>',  1,  0),
    ('<', -1,  0),
    ('^',  0, -1),
    ('v',  0,  1)
)
insert into blizzard(x, y, dx, dy)
select x - 2, id - 2 as y, dx, dy -- -2 to remove the walls and start at 0
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as map(tile, x)
inner join blizzard_tile on map.tile = blizzard_tile.tile
;

insert into grid_size
select
  -- -2 to remove the wall, only the playable area
  (select length(line) - 2 from raw_input limit 1) as width,
  (select count(*)::int - 2 from raw_input) as height
;


/*
 * The problem
 */

-- The main idea is to use time as the 3rd dimension. You can only move forward
-- in time, and x/y by 0 or 1 squares, so (directed) edges connect between
-- "levels" of time. Time repeats every lcm(width, height), so the last time
-- grid also connects back to the first time grid.

create temp table node (
  id int,
  kind text, -- start/end
  unique(id)
);

-- First build up a graph of all the nodes that can be visited (x, y) at any
-- given time (z).

with recursive
grid as (
  select x, y
  from grid_size
  cross join generate_series(0, width - 1) as x(x)
  cross join generate_series(0, height - 1) as y(y)
),
max_layer(max_layer) as (
  select lcm(width, height)
  from grid_size
),
open_space(i, id) as (
  select -1, 0 -- fake row, will remove
  union all
  (
    with
    next_i as (
      select i + 1 as next_i
      from open_space
      limit 1
    ),
    next_blizzard(id) as (
      select
        next_i,
        -- The extra + width % width bit gets us a positive number
        point_id(
          ((x + next_i * dx) % width + width) % width,
          ((y + next_i * dy) % height + height) % height,
          next_i
        )
      from blizzard, next_i, grid_size
    )
    select next_i, point_id(x, y, next_i)
    from grid, next_i, max_layer
    where next_i < max_layer
    except
    select * from next_blizzard
  )
)
insert into node(id, kind)
(
  select id, null from open_space where i > -1
  union all
  -- also include the start...
  select distinct on (i) point_id(0, -1, i), 'start' from open_space where i > -1
  union all
  -- ...and end points
  select distinct on (i) point_id(width - 1, height, i), 'end' from open_space, grid_size where i > -1
);

-- Edges are 1 level up (wrapping back from last to 0)
create temp table edge as (
  (
    -- connect each node to the neighbors in the next level up
    select node.id as source, other.id as target
    from node
    inner join node as other
      on other.id in (
        node.id + point_id( 0,  0, 1), -- wait
        node.id + point_id( 1,  0, 1), -- e
        node.id + point_id(-1,  0, 1), -- w
        node.id + point_id( 0,  1, 1), -- s
        node.id + point_id( 0, -1, 1)  -- n
      )
  )
  union all
  -- also connect the top layer to the bottom layer
  (
    select node.id as source, other.id as target
    from node
    cross join (
      select lcm(width, height) - 1
      from grid_size
    ) as _(max_layer)
    inner join node as other
      on other.id in (
        node.id + point_id( 0,  0, -max_layer),
        node.id + point_id( 1,  0, -max_layer),
        node.id + point_id(-1,  0, -max_layer),
        node.id + point_id( 0,  1, -max_layer),
        node.id + point_id( 0, -1, -max_layer)
      )
    where node.id >= point_id(-1, -1, max_layer)
  )
);


-- Finally we get to traverse this graph!

-- Add pseudo-exit and entrances that connect to the exit/entrance on each time
-- level.
with
pseudo(entrance, exit) as (
  values (point_id(-1, -1, -1), point_id(-1, -2, -2))
)
insert into edge(source, target)
(
  select node.id, pseudo.entrance
  from node, pseudo
  where node.kind = 'start'
)
union all
(
  select node.id, pseudo.exit
  from node, pseudo
  where node.kind = 'end'
);

-- Part 1: shortest distance to the exit

with
pseudo(entrance, exit) as (
  values (point_id(-1, -1, -1), point_id(-1, -2, -2))
),
path1 as (
  select *
  from pgr_dijkstra(
    'select row_number() over () as id, source, target, 1 as cost
    from edge',
    -- start at the entrance at the first level
    (select min(id) from node where kind = 'start'),
    -- end at the pseudo exit
    (select exit from pseudo),
    true
  )
),
-- find the exit we actually took, not the pseudo exit
exit1 as (
  select node, agg_cost
  from path1
  where node != (select exit from pseudo)
  order by agg_cost desc
  limit 1
),
part1(part, answer) as (
  select 'part1', agg_cost
  from exit1
),

-- Part 2: go back to the beginning to get snacks, then back to the end again

path2 as (
  select *
  from pgr_dijkstra(
    'select row_number() over () as id, source, target, 1 as cost
    from edge',
    (select node from exit1),
    (select entrance from pseudo),
    true
  )
),
-- again, find the actual entrance node
entrance2 as (
  select node, agg_cost
  from path2
  where node != (select entrance from pseudo)
  order by agg_cost desc
  limit 1
),
-- Finally, back to the end again
path3 as (
  select *
  from pgr_dijkstra(
    'select row_number() over () as id, source, target, 1 as cost
    from edge',
    (select node from entrance2),
    (select exit from pseudo),
    true
  )
),
exit3 as (
  select node, agg_cost
  from path3
  where node != (select exit from pseudo)
  order by agg_cost desc
  limit 1
),
part2(part, answer) as (
  select 'part2', exit1.agg_cost + entrance2.agg_cost + exit3.agg_cost
  from exit1, entrance2, exit3
)

-- Answers

select * from part1
union all
select * from part2
;
