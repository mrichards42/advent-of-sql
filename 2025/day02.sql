\echo --- Day 2: Gift Shop ---

/*
 * Schema
 */

create temp table ranges (
  lower bigint,
  upper bigint
);

create or replace function digit_count(double precision) returns int as $$
  select floor(log10($1)) + 1
$$ language sql immutable parallel safe;

create or replace function repeat_num(bigint, int) returns bigint as $$
  select repeat($1::text, $2)::bigint
$$ language sql immutable parallel safe;

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day02.sample.txt'
\copy raw_input(line) FROM '2025/day02.txt'

insert into ranges
select
  split_part(range, '-', 1)::bigint as lower,
  split_part(range, '-', 2)::bigint as upper
from raw_input
cross join lateral regexp_split_to_table(line, ',') as _(range);

/*
 * The problem
 */

-- Part 1: number of invalid ids between certain ranges, where invalid ids are
-- some number repeated twice

with

bounds as (
  select min(lower) as lower, max(upper) as upper
  from ranges
),

numbers as (
  select n::bigint
  from bounds
  cross join lateral generate_series(1, left(upper::text, digit_count(upper) / 2)::bigint) as n
),

invalid_ids_1 as (
  select repeat_num(n, 2) as id from numbers
),

part1(part, answer) as (
  select 'part1', sum(id)
  from invalid_ids_1
  where exists (select 1 from ranges where id between lower and upper)
),

-- Part 2: same thing, but invalid ids are those that are some number repeated
-- any number of times

invalid_ids_2 as (
  select distinct repeat_num(n, rep) as id
  from numbers
  cross join lateral generate_series(2, 10) as rep
  where digit_count(n) * rep <= (select digit_count(upper) from bounds)
),
part2(part, answer) as (
  select 'part2', sum(id)
  from invalid_ids_2
  where exists (select 1 from ranges where id between lower and upper)
)

-- Answers

select * from part1
union all
select * from part2
;
