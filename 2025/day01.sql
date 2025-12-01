\c
\echo --- Day 1: Secret Entrance ---

/*
 * Schema
 */

create temp table instructions (
  id int,
  val int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day01.sample.txt'
\copy raw_input(line) FROM '2025/day01.txt'

insert into instructions
select
  id,
  substr(line, 2)::int * case left(line, 1) when 'L' then -1 when 'R' then 1 end as val
from raw_input;

-- start at 50
insert into instructions(id, val) values (0, 50);


/*
 * The problem
 */

-- Part 1: number of times we land on 0

with

end_positions as (
  select
    id,
    val,
    mod(mod(sum(val) over (order by id), 100) + 100, 100) as end_pos
  from instructions
),

positions as (
  select
    *,
    lag(end_pos) over (order by id) as start_pos
  from end_positions
),

part1(part, answer) as (
  select 'part1', count(*)
  from positions
  where end_pos = 0
),

-- Part 2: number of times we cross or land on 0

stats as (
  select
    *,
    -- do we land on or cross 0 at all?
    case
      when end_pos = 0 then 1
      when start_pos = 0 then 0
      when start_pos + mod(val, 100) < 0 then 1
      when start_pos + mod(val, 100) > 99 then 1
      else 0
    end as crosses,
    -- additional full 100 rotations
    abs(val / 100)::int as rotations
  from positions
),


part2(part, answer) as (
  select 'part2', sum(rotations + crosses)
  from stats
)

-- Answers

select * from part1
union all
select * from part2
;
