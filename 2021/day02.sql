\c
\echo --- Day 2: Dive! ---

/*
 * Schema
 */

create temp table instruction (
  id int primary key,
  direction text,
  amount int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day02.sample.txt' */
\copy raw_input(line) FROM '2021/day02.txt'

insert into instruction(id, direction, amount)
select id, split[1], split[2]::int
from
  raw_input,
  lateral string_to_array(line, ' ') as split;

/*
 * The problem
 */

-- Part 1: forward = horizontal; down/up = vertical

with
parsed as (
  select
    id,
    amount * (direction = 'forward')::int as forward_amount,
    case
      when direction = 'down' then amount
      when direction = 'up' then -amount
      else 0
    end as vertical_amount
  from instruction
),
part1(part, answer) as (
  select 'part1', sum(forward_amount) * sum(vertical_amount)
  from parsed
),

-- Part 2: forward = move; down/up = aim

cumulative as (
  select
    id,
    forward_amount,
    sum(vertical_amount) over (order by id rows between unbounded preceding and current row) as aim
  from parsed
),
part2(part, answer) as (
  select 'part2', sum(forward_amount) * sum(forward_amount * aim)
  from cumulative
)

-- Answers

select * from part1
union all
select * from part2
;
