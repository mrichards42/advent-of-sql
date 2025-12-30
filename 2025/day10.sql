\echo --- Day 10: Factory ---

/*
 * Schema
 */

create temp table lights (
  machine_id int,
  light_id int,
  state bool
);

create temp table buttons (
  machine_id int,
  button_id int,
  light_id int
);

create temp table joltages (
  machine_id int,
  light_id int,
  joltage int
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day10.sample.txt'
\copy raw_input(line) FROM '2025/day10.txt'

insert into lights
select id as machine_id, light_id, state = '#' as state
from raw_input
cross join lateral regexp_match(line, '\[(.*)\]') as _1(light)
cross join lateral string_to_table(light[1], null) with ordinality as _2(state, light_id);

insert into buttons
select id as machine_id, button_id, light_id::int + 1 -- we're 1-indexed
from raw_input
cross join lateral regexp_match(line, '\] (.*) \{') as _1(buttons)
cross join lateral regexp_matches(buttons[1], '\((.+?)\)', 'g') with ordinality as _2(button, button_id)
cross join lateral string_to_table(button[1], ',') as _3(light_id);

insert into joltages
select id as machine_id, light_id, joltage::int
from raw_input
cross join lateral regexp_match(line, '\{(.*)\}') as _1(joltages)
cross join lateral string_to_table(joltages[1], ',') with ordinality as _2(joltage, light_id);

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: push buttons until you get the pattern of indicator lights

-- Treat everything as binary and use xor for button pushes

create temp table lights_binary (
  machine_id int,
  target int
);

create temp table buttons_binary (
  machine_id int,
  button_id int,
  button int
);

insert into lights_binary
select machine_id, bit_or(set_bit(B'0000000000000000', light_id - 1, state::int))::int
from lights
group by 1;

insert into buttons_binary
select machine_id, button_id, bit_or(set_bit(B'0000000000000000', light_id - 1, 1))::int
from buttons
group by 1, 2;

with recursive

presses(machine_id, press_count, last_id, result, target) as (
  select machine_id, 1, button_id, button, target
  from buttons_binary
  inner join lights_binary using(machine_id)

  union all

  select
    presses.machine_id,
    presses.press_count + 1,
    buttons_binary.button_id as last_id,
    presses.result # buttons_binary.button as result,
    presses.target
  from presses, buttons_binary
  where presses.machine_id = buttons_binary.machine_id
    and presses.last_id < buttons_binary.button_id
    and presses.press_count < 10
    and presses.target != presses.result
),

results as (
  select distinct on (machine_id) *
  from presses
  where result = target
  order by machine_id, press_count
)

insert into answer
select 'part1', sum(press_count) from results
;

-- Part 2: push buttons until you get the correct voltage

-- I tried a few things first, but this is a linear programming problem, so
-- pretty hard to do without a solver. This writes out an smt2 file and then
-- runs z3 on it.

\pset format unaligned
\pset tuples_only
\o 2025/day10.smt2
(
  select '(declare-const b' || n || ' Int) (assert (<= 0 b' || n || '))' as smt
  from generate_series(1, 20) as _(n)
)
union all
(
  select '(minimize (+ ' || string_agg('b' || n, ' ') || '))' as smt
  from generate_series(1, 20) as _(n)
)
union all
(
  with button_asserts as (
    select machine_id, light_id, '(assert (= (+ ' || string_agg(distinct 'b' || button_id, ' ') || ') ' || any_value(joltage) || '))' as smt
    from buttons
    inner join joltages using (machine_id, light_id)
    group by 1, 2
  )
  select E'(push)\n' || string_agg(smt, E'\n' order by light_id) || E'\n(check-sat)\n(get-objectives)\n(pop)' as smt
  from button_asserts
  group by machine_id
)
;
\o
\pset tuples_only
\pset format aligned

-- run z3 and parse out the numbers from the result

create temp table z3_output (
  line text
);

\copy z3_output(line) from program 'z3 2025/day10.smt2';

with parsed as (
  select (regexp_match(line, '\m\d+'))[1]::int as number
  from z3_output
)
insert into answer
select 'part2', sum(number)
from parsed where number is not null;

-- Answers

select * from answer;
