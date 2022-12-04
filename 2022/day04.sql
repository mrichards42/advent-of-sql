\c
\echo --- Day 4: Camp Cleanup ---

/*
 * Schema
 */

create temp table assignment (
  pair int,
  elf int,
  section int
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
select id, elf, section
from raw_input
cross join lateral regexp_split_to_table(line, ',') with ordinality as _a(assignment_range, elf)
cross join lateral regexp_split_to_array(assignment_range, '-') as _b(numbers)
cross join lateral generate_series(numbers[1]::int, numbers[2]::int) as _c(section)
;

/*
 * The problem
 */

-- Part 1: number of pairs with a fully-contained elf

with
overlap as (
  select
    assignment.*,
    other is not null as has_overlap
  from assignment
  left join assignment as other
    on assignment.pair = other.pair
    and assignment.section = other.section
    and assignment.elf <> other.elf
),
fully_contained_elf as (
  select distinct pair, elf
  from overlap
  group by pair, elf
  having count(*) filter (where has_overlap) = count(*)
),
-- There are some ranges that are exactly the same, so count(*) would
-- over-count since both elves appear in fully_contained_elf
part1(part, answer) as (
  select 'part1', count(distinct pair)
  from fully_contained_elf
),

-- Part 2: number of pairs with any overlap

part2(part, answer) as (
  select 'part2', count(distinct pair)
  from overlap
  where has_overlap
)

-- Answers

select * from part1
union all
select * from part2
;
