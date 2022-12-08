\c
\echo --- Day 6: Tuning Trouble ---

/*
 * Schema
 */

create temp table datastream (
  idx int primary key,
  ch char
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day06.sample.txt' */
\copy raw_input(line) FROM '2022/day06.txt'

-- postgres does not support backrefs in lookaheads, so this obvious solution
-- does not work :(

/* select regexp_instr(line, '(.)((?!\1).)((?!\2)(?!\1).)((?!\3)(?!\2)(?!\1).)') */
/* from raw_input; */

-- that said, doing this manually for part 2 would have been a pain :)

insert into datastream(idx, ch)
select idx, c
from raw_input
cross join lateral regexp_split_to_table(line, '') with ordinality as _(c, idx)
;

/*
 * The problem
 */

-- Part 1: distinct runs of 4

with
packet_marker as (
  select self.idx, count(distinct run.ch)
  from datastream as self
  inner join datastream as run
    on run.idx >= self.idx - 3
    and run.idx <= self.idx
  group by 1
  having count(distinct run.ch) = 4
  order by 1
  limit 1
),
part1(part, answer) as (
  select 'part1', idx
  from packet_marker
),

-- Part 2: distinct runs of 14

message_marker as (
  select self.idx, count(distinct run.ch)
  from datastream as self
  inner join datastream as run
    on run.idx >= self.idx - 13
    and run.idx <= self.idx
  group by 1
  having count(distinct run.ch) = 14
  order by 1
  limit 1
),
part2(part, answer) as (
  select 'part2', idx
  from message_marker
)

select * from part1
union all
select * from part2
;
