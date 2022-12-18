\c
\echo --- Day 18: Boiling Boulders ---

/*
 * Schema
 */

-- center of each droplet
create temp table droplet (
  id int primary key generated always as (x + y*100 + z*10000) stored,
  x int,
  y int,
  z int,
  unique(x, y, z)
);

-- center of each face
create temp table face (
  droplet int,
  x float,
  y float,
  z float,
  face_id int generated always as (100000000 + x*2 + y*2000 + z*2000000) stored
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day18.sample.txt' */
\copy raw_input(line) FROM '2022/day18.txt'

insert into droplet(x, y, z)
select arr[1]::int, arr[2]::int, arr[3]::int
from raw_input
cross join lateral string_to_array(line, ',') as _(arr)
;

create temp table face_offset(dx, dy, dz) as (
  values
  -- with x = horizontal, y = vertical, z = depth
  -- front face
  (0.0, 0.0, -0.5),
  -- rear face
  (0.0, 0.0, +0.5),
  -- top face
  (0.0, +0.5, 0.0),
  -- bottom face
  (0.0, -0.5, 0.0),
  -- left face
  (-0.5, 0.0, 0.0),
  -- right face
  (+0.5, 0.0, 0.0)
);

insert into face(droplet, x, y, z)
select id, x + dx, y + dy, z + dz
from droplet, face_offset
;


/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: number of exposed faces in total

with overlapping_face(x, y, z, n) as (
  select x, y, z, count(*)
  from face
  group by 1, 2, 3
)
insert into answer
select 'part1', count(*) from overlapping_face where n = 1
;

-- Part 2: number of _external_ exposed faces
-- I think this is a graph problem? Let's make a network (with centers
-- connected to each of the 6 faces), and subtract the droplet centers. Then
-- see which faces are reachable from the outside.

-- Note that we need ids for every node, and in particular, we need shared
-- faces to have the _same_ node id so that the graph is actually connected.
-- That results in some awkward id creation code here (and in the droplet +
-- face tables at the start), which doesn't necessarily generalize to larger
-- graphs, but works fine in this case where coordinates are all between 0-20.

create temp table graph_center as (
  with
  bounds(min_x, max_x, min_y, max_y, min_z, max_z) as (
    select min(x), max(x), min(y), max(y), min(z), max(z)
    from droplet
  )
  select x + y*100 + z*10000 as id, x, y, z
  from bounds
  -- extend the bounds by 1 to make sure there are squares outside the droplet
  cross join lateral generate_series(min_x - 1, max_x + 1) as x(x)
  cross join lateral generate_series(min_y - 1, max_y + 1) as y(y)
  cross join lateral generate_series(min_z - 1, max_z + 1) as z(z)
);

create temp table graph_face as (
  select
    (100000000 + face.x*2 + face.y*2000 + face.z*2000000)::int as face_id,
    graph_center.id as center_id,
    face.x,
    face.y,
    face.z
  from graph_center
  cross join face_offset
  cross join lateral (select x + dx, y + dy, z + dz) as face(x, y, z)
);

with connected as (
  select * from pgr_connectedComponents(
    'select
      row_number() over () as id,
      center_id as source,
      face_id as target,
      1 as cost,
      1 as reverse_cost
    from graph_face
    where center_id not in (select id from droplet)
    '
  )
),
-- a point guaranteed to be outside the droplet (the one with the smallest x,
-- y, z coordinate, since we added -1 to the bounds)
outside_node as (
  select *
  from graph_center
  order by x, y, z
  limit 1
),
-- now figure out which section of the graph includes that node
outside_connected as (
  select *
  from connected
  where component = (
    select component
    from connected
    where node = (select id from outside_node)
  )
),
-- and finally, which droplet faces are part of this connected graph
connected_droplet_face as (
  select *
  from face
  where face_id in (select node from outside_connected)
)
insert into answer
select 'part2', count(distinct face_id) from connected_droplet_face
;

-- Answers

select * from answer;
