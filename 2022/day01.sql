\c
\echo --- Day 1: Calorie Counting ---

/*
 * Schema
 */

create temp table provisions (
  elf int,
  calories int
);

/*
 * Parse input
 */

create temp table raw_lines (
  id int primary key generated always as identity,
  line text
);

create temp table raw_input (
  input text
);

/* \copy raw_lines(line) FROM '2022/day01.sample.txt' */
\copy raw_lines(line) FROM '2022/day01.txt'

insert into raw_input
select array_to_string(array(select line from raw_lines order by id), e'\n');

insert into provisions
select elf, calories::int
from raw_input
cross join lateral regexp_split_to_table(input, e'\n\n') with ordinality as _a(meal_lines, elf)
cross join lateral regexp_split_to_table(meal_lines, e'\n') as _b(calories);

/*
 * The problem
 */

-- Part 1: max calories

with
elf_calories as (
  select elf, sum(calories) as calories
  from provisions
  group by elf
),
part1(part, answer) as (
  select 'part1', calories
  from elf_calories
  order by calories desc
  limit 1
),

-- Part 2: sum of top 3 calories

top3_elves as (
  select calories
  from elf_calories
  order by calories desc
  limit 3
),
part2(part, answer) as (
  select 'part2', sum(calories)
  from top3_elves
)

-- Answers

select * from part1
union all
select * from part2
;
