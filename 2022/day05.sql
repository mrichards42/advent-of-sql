\c
\echo --- Day 5: Supply Stacks ---

/*
 * Schema
 */

create temp table stack (
  idx int,
  crates char[]
);

create temp table instruction (
  id int primary key generated always as identity,
  from_stack int,
  to_stack int,
  number int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day05.sample.txt' */
\copy raw_input(line) FROM '2022/day05.txt'

with section as (
  select block[1] as top, block[2] as bottom
  from (select string_agg(line, e'\n') from raw_input) as input(input)
  cross join lateral regexp_split_to_array(input, e'\n\n') as _(block)
),
top_split as (
  select idx, pos, match[1] as crate
  from section
  cross join lateral regexp_split_to_table(top, e'\n') with ordinality as _a(line, pos)
  cross join lateral regexp_matches(line, '.(.).\s?', 'g') with ordinality as _b(match, idx)
),
_stack_insert as (
  insert into stack(idx, crates)
  select idx, array_agg(crate order by pos)
  from top_split
  where crate ~ '[A-Z]'
  group by idx
)
insert into instruction(number, from_stack, to_stack)
select match[1]::int, match[2]::int, match[3]::int
from section
cross join lateral regexp_split_to_table(bottom, e'\n') with ordinality as _a(line, id)
cross join lateral regexp_match(line, 'move (\d+) from (\d+) to (\d+)') as _b(match)
;

/*
 * The problem
 */

create temp table exploded_instruction (
  id int primary key generated always as identity,
  from_stack int,
  to_stack int,
  number int
);

insert into exploded_instruction (number, from_stack, to_stack)
select 1, from_stack, to_stack
from instruction
-- explode the instructions so that each one is a single move
cross join lateral generate_series(1, number) as _
order by id;

-- Part 1: moving crates one-by-one

with recursive
part1_it(i, stack_idx, crates) as (
  select 1, idx, crates
  from stack

  union all

  (
    with prev as (
      select * from part1_it
    ),
    popped as (
      select crates[1:1] as popped
      from prev
      inner join exploded_instruction on i = exploded_instruction.id
        and exploded_instruction.from_stack = prev.stack_idx
    )
    select
      i + 1,
      stack_idx,
      (case
        when exploded_instruction.from_stack = stack_idx
          then crates[2:] -- pop
        when exploded_instruction.to_stack = stack_idx
          then popped || crates -- push
        else crates
      end)::char[]
    from prev
    inner join exploded_instruction on i = exploded_instruction.id
    cross join popped
  )
),
part1(part, answer) as (
  select 'part1', string_agg(crates[1], '' order by stack_idx)
  from part1_it
  where i = (select max(id) from exploded_instruction) + 1
),

-- Part 2: moving crates all at once

part2_it(i, stack_idx, crates) as (
  select 1, idx, crates
  from stack

  union all

  (
    with prev as (
      select * from part2_it
    ),
    popped as (
      select crates[1:number] as popped
      from prev
      inner join instruction on i = instruction.id
        and instruction.from_stack = prev.stack_idx
    )
    select
      i + 1,
      stack_idx,
      (case
        when instruction.from_stack = stack_idx
          then crates[number + 1:] -- pop
        when instruction.to_stack = stack_idx
          then popped || crates -- push
        else crates
      end)::char[]
    from prev
    inner join instruction on i = instruction.id
    cross join popped
  )
),
part2(part, answer) as (
  select 'part2', string_agg(crates[1], '' order by stack_idx)
  from part2_it
  where i = (select max(id) from instruction) + 1
)

-- Answers

select * from part1
union all
select * from part2
;
