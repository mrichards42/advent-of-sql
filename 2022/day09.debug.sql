-- Run this command to debug
-- psql postgresql://postgres:friend@localhost:5432/postgres -q -f 2022/day09.debug.sql

/*
 * Schema
 */

create temp table instruction (
  id int primary key generated always as identity,
  dir char
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day09.sample.txt' */
\copy raw_input(line) FROM '2022/day09.sample2.txt'
/* \copy raw_input(line) FROM '2022/day09.txt' */

insert into instruction(dir)
select split[1]
from raw_input
cross join lateral string_to_array(line, ' ') as _a(split)
cross join lateral generate_series(1, split[2]::int) as _b
order by id
;

-- need to move
-- .......
-- .TTTTT.
-- .T...T.
-- .T.H.T.
-- .T...T.
-- .TTTTT.
-- .......
create temp table tail_move(tail_offset, diff) as (
  values
  -- above
  (point(-2, -2), point( 1,  1)),
  (point(-1, -2), point( 1,  1)),
  (point( 0, -2), point( 0,  1)),
  (point( 1, -2), point(-1,  1)),
  (point( 2, -2), point(-1,  1)),
  -- to the right
  (point( 2, -1), point(-1,  1)),
  (point( 2,  0), point(-1,  0)),
  (point( 2,  1), point(-1, -1)),
  -- below
  (point(-2,  2), point( 1, -1)),
  (point(-1,  2), point( 1, -1)),
  (point( 0,  2), point( 0, -1)),
  (point( 1,  2), point(-1, -1)),
  (point( 2,  2), point(-1, -1)),
  -- to the left
  (point(-2, -1), point( 1,  1)),
  (point(-2,  0), point( 1,  0)),
  (point(-2,  1), point( 1, -1))
);

/*
 * The problem
 */

-- Part 1: description

-- separate table to make debugging easier
create temp table rope (
  i int,
  knot_idx int,
  knots point[]
);

with recursive
rope_it(i, knot_idx, knots) as (
  select 1, 1, array_fill(point(0, 0), array[10])
  union all
  select
    -- wrap around to the next instructions once we've hit the actual tail
    case when knot_idx = 10 then i + 1 else i end,
    case when knot_idx = 10 then 1 else knot_idx + 1 end,
    knots[:(knot_idx - 1)] || array[new_knot] || knots[(knot_idx + 1):]
  from rope_it
  inner join instruction on rope_it.i = instruction.id
  -- move knots one at a time
  cross join lateral (
    select case
      when knot_idx = 1 then
        -- we're at the head knot, move it based on the instruction
        case
          when instruction.dir = 'R' then knots[1] + point(1, 0)
          when instruction.dir = 'L' then knots[1] + point(-1, 0)
          when instruction.dir = 'U' then knots[1] + point(0, -1)
          when instruction.dir = 'D' then knots[1] + point(0, 1)
        end
      -- we're further down the line, calculate based on the movement table
      else knots[knot_idx] + coalesce((
        select diff
        from tail_move
        where tail_offset ~= (knots[knot_idx] - knots[knot_idx - 1])
      ), point(0, 0))
    end
  ) as _(new_knot)
)
insert into rope
select * from rope_it
;

-- debugging
create temp table debug as (
  with
  bounds(min_x, max_x, min_y, max_y) as (
    select -20, 20, -20, 20
  ),
  grid(x, y) as (
    select x, y
    from bounds
    cross join generate_series(min_x, max_x) as x(x)
    cross join generate_series(min_y, max_y) as y(y)
  )
  select
    rope.i,
    rope.knot_idx,
    regexp_replace(string_agg(
      case
        when point(x, y) ~= rope.knots[1] then 'H'
        when point(x, y) ~= rope.knots[2] then '1'
        when point(x, y) ~= rope.knots[3] then '2'
        when point(x, y) ~= rope.knots[4] then '3'
        when point(x, y) ~= rope.knots[5] then '4'
        when point(x, y) ~= rope.knots[6] then '5'
        when point(x, y) ~= rope.knots[7] then '6'
        when point(x, y) ~= rope.knots[8] then '7'
        when point(x, y) ~= rope.knots[9] then '8'
        when point(x, y) ~= rope.knots[10] then '9'
        when point(x, y) ~= point(0, 0) then 's'
        else '.'
      end,
    ''), '(.{' || (select max_x - min_x + 1 from bounds) || '})', '\1' || e'\n', 'g') as grid
  from grid
  cross join rope
  group by 1, 2
);

do $$
declare display varchar;
begin
  for loop_i in 1..(select max(i) from debug) loop
    for loop_j in 1..10 loop
      select grid
      into display
      from debug where i = loop_i and knot_idx = loop_j;

      raise notice e'\nstep % knot %\n%', loop_i, loop_j, display;

      perform pg_sleep(0.03);
    end loop;
  end loop;
end $$
