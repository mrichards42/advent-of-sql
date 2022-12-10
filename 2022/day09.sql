\c
\echo --- Day 9: Rope Bridge ---

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
/* \copy raw_input(line) FROM '2022/day09.sample2.txt' */
\copy raw_input(line) FROM '2022/day09.txt'

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

-- separate table to make debugging easier, see day09.debug.sql
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

with
-- Part 1: distinct locations of the first tail
part1(part, answer) as (
  select 'part1', count(distinct (coord[0], coord[1]))
  from (select knots[2] from rope) _(coord)
),
-- Part 2: distinct locations of the last tail
part2(part, answer) as (
  select 'part2', count(distinct (coord[0], coord[1]))
  from (select knots[10] from rope) _(coord)
)
select * from part1
union all
select * from part2
;
