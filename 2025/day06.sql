\echo --- Day 6: Trash Compactor ---

/*
 * Schema
 */

create temp table problems (
  problem_id int,
  op char
);

create temp table numbers (
  problem_id int,
  number bigint
);

-- https://stackoverflow.com/a/71840581
create or replace function mul_sfunc(anyelement, anyelement) returns anyelement
   language sql as 'select $1 * coalesce($2, 1)';

create or replace aggregate product(anyelement) (
   stype = anyelement,
   initcond = 1,
   sfunc = mul_sfunc,
   combinefunc = mul_sfunc,
   parallel = safe
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day06.sample.txt'
\copy raw_input(line) FROM '2025/day06.txt'

/*
 * The problem
 */

create temp table answer (
  part text,
  answer bigint
);

-- Part 1: calculate the cephalopod math worksheet

insert into numbers
select idx, number::bigint
from raw_input
cross join lateral regexp_split_to_table(trim(line, ' '), '\s+') with ordinality as _(number, idx)
where pg_input_is_valid(number, 'int');

insert into problems
select idx, op
from raw_input
cross join lateral regexp_split_to_table(trim(line, ' '), '\s+') with ordinality as _(op, idx)
where op in ('*', '+');


with
results as (
  select problem_id, case when op = '+' then sum(number) else product(number) end as result
  from numbers
  inner join problems using (problem_id)
  group by problem_id, op
)
insert into answer
select 'part1', sum(result)
from results
;

-- Part 1: transpose the numbers first

-- Reparse these numbers, ops are still the same
truncate numbers;

insert into numbers
with
transposed as (
  select idx, id, ch
  from raw_input
  cross join lateral string_to_table(line, null) with ordinality as _(ch, idx)
  where id < (select max(id) from raw_input)
  order by idx, id
),
nums as (
  select idx, string_agg(ch, '' order by id)::bigint as number
  from transposed
  where ch != ' '
  group by 1
)
select
  idx - row_number() over (order by idx) + 1 as problem_id,
  number
from nums;

-- same thing as above
with
results as (
  select problem_id, case when op = '+' then sum(number) else product(number) end as result
  from numbers
  inner join problems using (problem_id)
  group by problem_id, op
)
insert into answer
select 'part2', sum(result)
from results
;

-- Answers

select * from answer;
