\c
\echo --- Day 4: Camp Cleanup ---

/*
 * Schema
 */

create temp table assignment (
  pair int,
  elf1_range int4range,
  elf2_range int4range
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day04.sample.txt' */
\copy raw_input(line) FROM '2022/day04.txt'

insert into assignment
select
  id,
  int4range(numbers[1]::int, numbers[2]::int, '[]'),
  int4range(numbers[3]::int, numbers[4]::int, '[]')
from raw_input
cross join lateral regexp_split_to_array(line, ',|-') as _(numbers)
;

/*
 * The problem
 */

-- Part 1: number of pairs with a fully-contained elf

with
part1(part, answer) as (
  select 'part1', count(*) from assignment
  where elf1_range @> elf2_range or elf2_range @> elf1_range
),

-- Part 2: number of pairs with any overlap
part2(part, answer) as (
  select 'part2', count(*) from assignment
  where elf1_range && elf2_range
)

-- Answers

select * from part1
union all
select * from part2
;
