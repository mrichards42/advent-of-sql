\c
\echo --- Day 22: Monkey Map ---

-- This was a real marathon! But it runs relatively fast :)

/*
 * Schema
 */

create temp table map (
  id int primary key generated always as identity,
  x int,
  y int,
  tile char,
  -- This is all for part 1, I took a slightly different approach for part 2
  -- size of the map at this point
  width int,
  height int,
  -- coordinate ids available to move to in this direction (these are all empty
  -- spaces, no walls)
  east int[],
  east_max int,
  west int[],
  west_max int,
  north int[],
  north_max int,
  south int[],
  south_max int,
  unique(x, y)
);

create temp table instruction (
  id int primary key,
  distance int,
  turn int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day22.sample.txt' */
\copy raw_input(line) FROM '2022/day22.txt'

insert into map(x, y, tile)
select x, id as y, tile
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as _(tile, x)
where tile != ' ' and id < (select max(id) from raw_input) - 1
;

insert into instruction(id, distance, turn)
select
  idx,
  instruction[1]::int,
  case
    when instruction[2] = 'R' then 1
    when instruction[2] = 'L' then -1
    else 0
  end
from raw_input
cross join lateral regexp_matches(line, '(\d+)([L|R]?)', 'g') with ordinality as _(instruction, idx)
where id = (select max(id) from raw_input)
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: move around a flat map

-- Precompute the grid size

with
widths as (
  select y, count(*) as width from map group by 1
),
heights as (
  select x, count(*) as height from map group by 1
)
update map
set width = widths.width, height = heights.height
from widths, heights
where widths.y = map.y and heights.x = map.x
;

-- Precompute the possible places that you can move from each square

with
rows as (
  select
    y,
    array_agg(id order by x) as e_points,
    array_agg(tile order by x) as e_tiles,
    array_agg(id order by x desc) as w_points,
    array_agg(tile order by x desc) as w_tiles
  from map
  group by 1
),
cols as (
  select
    x,
    array_agg(id order by y) as s_points,
    array_agg(tile order by y) as s_tiles,
    array_agg(id order by y desc) as n_points,
    array_agg(tile order by y desc) as n_tiles
  from map
  group by 1
),
paths as (
  select
    map.id,
    -- all point ids in front of you
    e_points[e_pivot+1:] || e_points[:e_pivot] as e_points_wrap,
    w_points[w_pivot+1:] || w_points[:w_pivot] as w_points_wrap,
    s_points[s_pivot+1:] || s_points[:s_pivot] as s_points_wrap,
    n_points[n_pivot+1:] || n_points[:n_pivot] as n_points_wrap,
    -- all tiles in front of you
    e_tiles[e_pivot+1:]  || e_tiles[:e_pivot]  as e_tiles_wrap,
    w_tiles[w_pivot+1:]  || w_tiles[:w_pivot]  as w_tiles_wrap,
    s_tiles[s_pivot+1:]  || s_tiles[:s_pivot]  as s_tiles_wrap,
    n_tiles[n_pivot+1:]  || n_tiles[:n_pivot]  as n_tiles_wrap
  from map
  inner join rows on rows.y = map.y
  inner join cols on cols.x = map.x
  cross join lateral (
    select
      array_position(e_points, map.id) as e_pivot,
      array_position(w_points, map.id) as w_pivot,
      array_position(s_points, map.id) as s_pivot,
      array_position(n_points, map.id) as n_pivot
  ) as _
  -- you can't ever start from a wall, so no need to calculate walls
  where map.tile = '.'
)
update map
set
  -- all points in front of you
  east = e_points_wrap,
  west = w_points_wrap,
  south = s_points_wrap,
  north = n_points_wrap,
  -- the first wall in each direction
  east_max  = array_position(e_tiles_wrap, '#') - 1,
  west_max  = array_position(w_tiles_wrap, '#') - 1,
  south_max = array_position(s_tiles_wrap, '#') - 1,
  north_max = array_position(n_tiles_wrap, '#') - 1
from paths
where map.id = paths.id
;

create temp table path1 as (
  with recursive
  tick(i, id, facing) as (
    -- start on the first empty cell in the first row
    (
      select 0, id, 0
      from map
      where tile = '.'
      order by y, x
      limit 1
    )

    union all

    select
      i + 1,
      -- move
      coalesce(
        case
          when facing = 0 then map.east[least(map.east_max, instruction.distance) % width]
          when facing = 1 then map.south[least(map.south_max, instruction.distance) % height]
          when facing = 2 then map.west[least(map.west_max, instruction.distance) % width]
          when facing = 3 then map.north[least(map.north_max, instruction.distance) % height]
        end,
        tick.id
      ),
      -- turn
      (facing + turn + 4) % 4
    from tick
    inner join instruction on instruction.id = tick.i + 1
    inner join map on tick.id = map.id
  )
  select * from tick
)
;

insert into answer
select
  'part1',
  1000 * y
  + 4 * x
  + facing
from path1
inner join map on path1.id = map.id
order by i desc
limit 1;



-- Part 2: it's a cube!

-- This is basically the same, except the rules for where you go at the edge
-- are different, and you can change the direction you face when you move
-- across an edge, so we also need to track a turns array per point/direction.

-- The way I approached this is a bit more general than part 1. Instead of
-- precomputing where you can move from each square in the map, I instead
-- figure out the total set of "loops" that run around the cube -- there are 6
-- of them, one per axis, and a forward and reverse direction. Each of these
-- loops crosses a certain set of points, and when you unfold the cube, the
-- direction you end up at each point/loop depends on how you had to rotate the
-- face to participate in the loop. You could also do part 1 this way, where
-- each loop is just the flat x/y plane, and each of the 4 loops (x/y *
  -- forward/backward) directly corresponds to a cardinal direction, no need
-- for transformations, so the `turns` array is just all 0s for east, all 1s
-- for south, etc.


-- I'm not sure how to figure out how the faces fold together other than to
-- hard-code them :(

/*
 * Sample cube
 */

create temp table sample_side(face, x_range, y_range) as (
  values
    ('front',  '[9,12]'::int4range,  '[1,4]'::int4range),
    ('bottom', '[9,12]'::int4range,  '[5,8]'::int4range),
    ('back',   '[9,12]'::int4range,  '[9,12]'::int4range),
    ('left',   '[5,8]'::int4range,   '[5,8]'::int4range),
    ('top',    '[1,4]'::int4range,   '[5,8]'::int4range),
    ('right',  '[13,16]'::int4range, '[9,12]'::int4range)
);

-- this turns into a matrix (these might not be the right variable names)
-- a b tx
-- c d ty
-- 0 0  1
-- where the transformation ends up being (ax + by + tx, cx + dy + ty)
-- so the identity transform is 1, 0, 0, 1, 0, 0
-- turn is offset from east, south=1, west=2, north=3
create temp table sample_transform(loop_id, face, turn, a, b, c, d, tx, ty) as (
  values
    -- yz loop (moving south from the front face)
    ('yz', 'front',  /* turn */ 1, /* matrix */  1, 0, 0,  1,  0,  0),
    ('yz', 'bottom', /* turn */ 1, /* matrix */  1, 0, 0,  1,  0,  0),
    ('yz', 'back',   /* turn */ 1, /* matrix */  1, 0, 0,  1,  0,  0),
    -- we want (1, 5) to end up at (12, 16) with a 180 rotation, so that's
    -- (12 - -1, 16 - -5) = (13, 21)
    ('yz', 'top',    /* turn */ 3, /* matrix */ -1, 0, 0, -1, 13, 21),

    -- xz loop (moving east from the front face)
    ('xz', 'front', /* turn */ 0, /* matrix */  1, 0, 0,  1,  0,  0),
    -- (16, 12) -> (13, 1) with a 180 rotation, so that's
    -- (13 - -16, 12 - -1) = (29, 13)
    ('xz', 'right', /* turn */ 2, /* matrix */ -1, 0, 0, -1, 29, 13),
    ('xz', 'back',  /* turn */ 2, /* matrix */ -1, 0, 0, -1, 29, 13),
    -- (5, 8) -> (21, 1) with 90 rotation . . . 90 degrees is (-y, x)
    -- (21 - -8, 1 - 5) = (29, -4)
    ('xz', 'left',  /* turn */ 3, /* matrix */ 0, -1, 1,  0, 29, -4),

    -- xy loop (moving east from the top)
    -- the top is upside-down in the input :( so let's flip it first and I
    -- guess stick it at 1, 1 to make things easier?
    ('xy', 'top',    /* turn */ 2, /* matrix */ -1,  0, 0, -1,  5,   9), -- 180 (4,8) -> (1,1)
    ('xy', 'right',  /* turn */ 3, /* matrix */  0, -1, 1,  0, 17, -12), -- 90 (13,12) -> (5,1)
    ('xy', 'bottom', /* turn */ 2, /* matrix */ -1,  0, 0, -1, 21,   9), -- 180 (12,8) -> (9,1)
    ('xy', 'left',   /* turn */ 2, /* matrix */ -1,  0, 0, -1, 21,   9)  -- 180 (8,8) -> (13,1)
);


/*
 * My input cube
 */

create temp table input_side(face, x_range, y_range) as (
  values
    ('front',  '[51,100]'::int4range,  '[1,50]'::int4range),
    ('bottom', '[51,100]'::int4range,  '[51,100]'::int4range),
    ('back',   '[51,100]'::int4range,  '[101,150]'::int4range),
    ('left',   '[1,50]'::int4range,    '[101,150]'::int4range),
    ('top',    '[1,50]'::int4range,    '[151,200]'::int4range),
    ('right',  '[101,150]'::int4range, '[1,50]'::int4range)
);

create temp table input_transform(loop_id, face, turn, a, b, c, d, tx, ty) as (
  values
    -- yz loop (moving south from the front face)
    ('yz', 'front',  /* turn */ 1, /* matrix */ 1, 0,  0, 1,    0,   0),
    ('yz', 'bottom', /* turn */ 1, /* matrix */ 1, 0,  0, 1,    0,   0),
    ('yz', 'back',   /* turn */ 1, /* matrix */ 1, 0,  0, 1,    0,   0),
    ('yz', 'top',    /* turn */ 2, /* matrix */ 0, 1, -1, 0, -100, 201), -- 270 (50,151) -> (51,151)

    -- xz loop (moving east from the front face)
    ('xz', 'front', /* turn */ 0, /* matrix */  1, 0, 0,  1,   0,   0),
    ('xz', 'right', /* turn */ 0, /* matrix */  1, 0, 0,  1,   0,   0),
    ('xz', 'back',  /* turn */ 2, /* matrix */ -1, 0, 0, -1, 251, 151), -- 180 (100,101) -> (151,50)
    ('xz', 'left',  /* turn */ 2, /* matrix */ -1, 0, 0, -1, 251, 151), -- same

    -- xy loop (moving east from the top)
    -- we'll do the same thing here, shift the top so that it's upright at 1,1
    ('xy', 'top',    /* turn */ 1, /* matrix */  0, 1, -1,  0, -150,  51), -- 270 (50,151) -> (1,1)
    ('xy', 'right',  /* turn */ 1, /* matrix */  0, 1, -1,  0,   50, 151), -- 270 (150,1) -> (51,1)
    ('xy', 'bottom', /* turn */ 2, /* matrix */ -1, 0,  0, -1,  201, 101), -- 180 (100,51) -> (101,50)
    ('xy', 'left',   /* turn */ 1, /* matrix */  0, 1, -1,  0,   50,  51)  -- 270 (50,101) -> (151,1)
);




create temp table path2 as (
  with recursive
  side as (
    select * from sample_side where (select count(*) from map) = 96
    union all
    select * from input_side where (select count(*) from map) = 15000
  ),
  transform as (
    select * from sample_transform where (select count(*) from map) = 96
    union all
    select * from input_transform where (select count(*) from map) = 15000
  ),
  -- for each loop around the cube, we collect the points (map ids), tiles, and
  -- direction (turn) along the entire loop, both forward and backward. In
  -- order to get the right points, we apply the appropriate transform based on
  -- which face the point is on. Note that transforms are different for each
  -- loop, we're just trying to get all the points to align along either the x
  -- or y axis depending on the loop.
  yz_loop as (
    select
      'yz' as loop_id,
      transformed.x,
      count(*) as loop_len,
      array_agg(id order by transformed.y) as f_points,
      array_agg(tile order by transformed.y) as f_tiles,
      array_agg(transform.turn order by transformed.y) as f_turns,
      -- reverse direction
      array_agg(id order by transformed.y desc) as r_points,
      array_agg(tile order by transformed.y desc) as r_tiles,
      array_agg((2 + transform.turn) % 4 order by transformed.y desc) as r_turns
    from map
    inner join side on side.x_range @> map.x and side.y_range @> map.y
    inner join transform on side.face = transform.face
    cross join lateral (
      select
        transform.a * map.x + transform.b * map.y + transform.tx,
        transform.c * map.x + transform.d * map.y + transform.ty
    ) as transformed(x, y)
    where transform.loop_id = 'yz'
    group by 1, 2
  ),
  xz_loop as (
    select
      'xz' as loop_id,
      transformed.y,
      count(*) as loop_len,
      array_agg(id order by transformed.x) as f_points,
      array_agg(tile order by transformed.x) as f_tiles,
      array_agg(transform.turn order by transformed.x) as f_turns,
      array_agg(transformed.x order by transformed.x) as f_x,
      array_agg(id order by transformed.x desc) as r_points,
      array_agg(tile order by transformed.x desc) as r_tiles,
      array_agg((2 + transform.turn) % 4 order by transformed.x desc) as r_turns
    from map
    inner join side on side.x_range @> map.x and side.y_range @> map.y
    inner join transform on side.face = transform.face
    cross join lateral (
      select
        transform.a * map.x + transform.b * map.y + transform.tx,
        transform.c * map.x + transform.d * map.y + transform.ty
    ) as transformed(x, y)
    where transform.loop_id = 'xz'
    group by 1, 2
  ),
  xy_loop as (
    select
      'xy' as loop_id,
      transformed.y,
      count(*) as loop_len,
      array_agg(id order by transformed.x) as f_points,
      array_agg(tile order by transformed.x) as f_tiles,
      array_agg(transform.turn order by transformed.x) as f_turns,
      array_agg(id order by transformed.x desc) as r_points,
      array_agg(tile order by transformed.x desc) as r_tiles,
      array_agg((2 + transform.turn) % 4 order by transformed.x desc) as r_turns
    from map
    inner join side on side.x_range @> map.x and side.y_range @> map.y
    inner join transform on side.face = transform.face
    cross join lateral (
      select
        transform.a * map.x + transform.b * map.y + transform.tx,
        transform.c * map.x + transform.d * map.y + transform.ty
    ) as transformed(x, y)
    where transform.loop_id = 'xy'
    group by 1, 2
  ),
  -- collect all 6 loops into a single table. We'll use these loops to move
  -- around the grid.
  all_loops(loop_id, loop_len, points, tiles, turns) as (
    select loop_id, loop_len, f_points, f_tiles, f_turns from yz_loop
    union all
    select loop_id, loop_len, r_points, r_tiles, r_turns from yz_loop
    union all
    select loop_id, loop_len, f_points, f_tiles, f_turns from xz_loop
    union all
    select loop_id, loop_len, r_points, r_tiles, r_turns from xz_loop
    union all
    select loop_id, loop_len, f_points, f_tiles, f_turns from xy_loop
    union all
    select loop_id, loop_len, r_points, r_tiles, r_turns from xy_loop
  ),
  tick(i, id, facing) as (
    -- start on the first empty cell in the first row
    (
      select 0, id, 0
      from map
      where tile = '.'
      order by y, x
      limit 1
    )

    union all

    select
      i + 1,
      -- move
      wrapped_points[end_idx],
      -- turn
      (wrapped_turns[end_idx] + instruction.turn + 4) % 4
    from tick
    inner join instruction on instruction.id = tick.i + 1
    -- Find the loop that current map square participates in, given the
    -- direction we're facing.
    inner join all_loops
      on points @> array[tick.id]
      and turns[array_position(points, tick.id)] = tick.facing
    -- Pivot the arrays so that index 0 is the current square (or really, since
    -- arrays are 1-indexed by default, I'm sticking the current square at
    -- the end of the array)
    cross join lateral array_position(points, tick.id) as _1(pivot)
    cross join lateral (
      select
        points[pivot+1:] || points[:pivot] as wrapped_points,
        tiles[pivot+1:]  || tiles[:pivot]  as wrapped_tiles,
        turns[pivot+1:]  || turns[:pivot]  as wrapped_turns
    ) as _2
    -- Figure out how far we _actually_ move this turn ...
    cross join lateral least(
        -- either we hit a wall
        array_position(wrapped_tiles, '#') - 1,
        -- or we move the full distance
        instruction.distance
    ) as _3(distance_moved)
    -- ... and turn that distance into an array index (after wrapping)
    cross join lateral (
      select (distance_moved - 1 + loop_len) % loop_len + 1
    ) as _4(end_idx)
  )
  select * from tick
)
;


insert into answer
select
  'part2',
  1000 * y
  + 4 * x
  + facing
from path2
inner join map on path2.id = map.id
order by i desc
limit 1;


-- Answer

select * from answer;


/*

-- Viz

do $$
declare display varchar;
begin
  for loop_i in 0..(select max(i) from path2) loop

    with
    path as (
      select * from path2
    ),
    bounds(min_x, max_x, min_y, max_y) as (
      select min(x), max(x), min(y), max(y)
      from map
    ),
    grid(x, y) as (
      select x, y
      from bounds
      cross join generate_series(min_x, max_x) as x(x)
      cross join generate_series(min_y, max_y) as y(y)
    ),
    rows as (
      select
        grid.y,
        string_agg(case
          when path.facing = 0 then '>'
          when path.facing = 1 then 'v'
          when path.facing = 2 then '<'
          when path.facing = 3 then '^'
          when map.tile is null then ' '
          else map.tile
        end, '' order by grid.x) as row
      from grid
      left join map on (grid.x, grid.y) = (map.x, map.y)
      left join lateral (select * from path where map.id = path.id and path.i = loop_i) as path on true
      group by 1
      order by 1
    )
    select string_agg(row, e'\n' order by y)
    into display
    from rows
    ;
    raise notice e'\n%\n%', (select to_json(instruction) from instruction where id = loop_i), display;
  end loop;
end $$
;

*/
