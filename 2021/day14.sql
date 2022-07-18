\c
\echo --- Day 14: Extended Polymerization ---

/*
 * Schema
 */

create temp table pair (
  id bigint,
  a char,
  b char
);

create temp table insertion_rule (
  a char,
  b char,
  middle char
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

\copy raw_input(line) FROM '2021/day14.sample.txt'
/* \copy raw_input(line) FROM '2021/day14.txt' */

with blank_line as (
  select id
  from raw_input
  where line = ''
  limit 1
),
_pair as (
  insert into pair(id, a, b)
  select i, substr(line, i, 1), substr(line, i + 1, 1)
  from
    raw_input,
    lateral generate_series(1, length(line) - 1) as i
  where id < (select id from blank_line)
)
insert into insertion_rule(a, b, middle)
select m[1], m[2], m[3]
from
  raw_input,
  lateral regexp_match(line, '(.)(.) -> (.)') as m
where id > (select id from blank_line)
;

/*
 * The problem
 */

-- Part 1: description

with recursive generation(gen, id, a, b) as (
  select 0, id, a, b
  from pair

  union all

  (
    with prev as (
      select *
      from generation
      where gen < 10
    ),
    joined as (
      select
        prev.gen as gen,
        prev.id as id,
        prev.a as a,
        insertion_rule.middle as middle,
        prev.b as b
      from prev
      left join insertion_rule
        on prev.a = insertion_rule.a
        and prev.b = insertion_rule.b
    )
    -- Given the template AB and rule AB -> M
    -- (1) create pair AM
    select gen + 1, id * 3 + 1, a, middle
    from joined
    where middle is not null
    union all
    -- (2) create pair MB
    select gen + 1, id * 3 + 2, middle, b
    from joined
    where middle is not null
    union all
    -- (3) if there is no rule for AB, keep AB
    select gen + 1, id * 3, a, b
    from joined
    where middle is null
  )
),
first_char as (
  select a as ch
  from pair
  order by pair.id
  limit 1
)
select
  generation.gen,
  first_char.ch || string_agg(generation.b, '' order by generation.id) as polymer
from generation
cross join first_char
group by generation.gen, first_char.ch

/* last_gen_count as ( */
/*   select ch, count(*) as count */
/*   from last_gen_char */
/*   group by ch */
/* ), */
/* min_count as ( */
/*   select count */
/*   from last_gen_count */
/*   order by count asc */
/*   limit 1 */
/* ), */
/* max_count as ( */
/*   select count */
/*   from last_gen_count */
/*   order by count desc */
/*   limit 1 */
/* ) */
/* select max_count.count - min_count.count */
/* from max_count, min_count */


/* select * from last_gen order by id */

;

select * from pair
order by id
;

with
part1(part, answer) as (
  select 'part1', 123
),

-- Part 2: description

part2(part, answer) as (
  select 'part2', 456
)

-- Answers

select * from part1
union all
select * from part2
;
