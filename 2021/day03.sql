\c
\echo --- Day 3: Binary Diagnostic ---

/*
 * Schema
 */

create temp table diagnostic (
  id int,
  bit int,
  bit_pos int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day03.sample.txt' */
\copy raw_input(line) FROM '2021/day03.txt'

insert into diagnostic
select id, bit::int, bit_pos
from
  raw_input,
  -- reverse so that bit_pos corresponds to significance
  lateral regexp_split_to_table(reverse(line), '')
    with ordinality _(bit, bit_pos)
;

/*
 * The problem
 */

-- Part 1: gamma rate and epsilon rate

with recursive
common_bit as (
  select bit_pos, (sum(bit) > count / 2.0)::int as bit
  from
    diagnostic,
    lateral (select count(distinct id) from diagnostic) as _(count)
  group by bit_pos, count
),
gamma as (
  select sum(bit << (bit_pos - 1)) as val
  from common_bit
),
epsilon as (
  select sum((1 - bit) << (bit_pos - 1)) as val
  from common_bit
),
part1(part, answer) as (
  select 'part1', gamma.val * epsilon.val
  from gamma, epsilon
),

-- Part 2: oxygen rate and carbon dioxide rate (iterative version)

oxygen_bit(pos, id, bit, bit_pos) as (
  select (select max(bit_pos) from diagnostic), *
  from diagnostic
  union all
  (
    with prev as (
      select * from oxygen_bit
    ),
    good_bit as (
      select (sum(bit) >= count / 2.0)::int as good_bit
      from
        prev,
        lateral (select count(distinct id) from prev) as count(count)
      where bit_pos = pos
      group by count
    ),
    good_id as (
      select id as good_id
      from prev, good_bit
      where bit_pos = pos and bit = good_bit
    )
    select pos - 1, id, bit, bit_pos
    from prev, good_id
    where id in (good_id)
  )
),
carbon_dioxide_bit(pos, id, bit, bit_pos) as (
  select (select max(bit_pos) from diagnostic), *
  from diagnostic
  union all
  (
    with prev as (
      select * from carbon_dioxide_bit
    ),
    good_bit as (
      -- the only difference between this and oxygen is the comparison
      select (sum(bit) < count / 2.0)::int as good_bit
      from
        prev,
        lateral (select count(distinct id) from prev) as _(count)
      where bit_pos = pos
      group by count
    ),
    good_id as (
      select id as good_id
      from prev, good_bit
      where bit_pos = pos and bit = good_bit
    )
    select pos - 1, id, bit, bit_pos
    from prev, good_id
    where id in (good_id)
  )
),
oxygen as (
  select sum(bit << (bit_pos - 1)) as val
  from oxygen_bit
  where pos = (select min(pos) from oxygen_bit)
),
carbon_dioxide as (
  select sum(bit << (bit_pos - 1)) as val
  from carbon_dioxide_bit
  where pos = (select min(pos) from carbon_dioxide_bit)
),
part2(part, answer) as (
  select 'part2', oxygen.val * carbon_dioxide.val
  from oxygen, carbon_dioxide
)

-- Answers

select * from part1
union all
select * from part2
;
