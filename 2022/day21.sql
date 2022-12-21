\c
\echo --- Day 21: Monkey Math ---

/*
 * Schema
 */

create temp table monkey (
  id text primary key,
  val float,
  op char,
  monkey1 text,
  monkey2 text
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day21.sample.txt' */
\copy raw_input(line) FROM '2022/day21.txt'

insert into monkey(id, val, monkey1, op, monkey2)
select split[1], match[1]::float, match[2], match[3], match[4]
from raw_input
cross join lateral string_to_array(line, ': ') as _1(split)
cross join lateral regexp_matches(split[2], '(\d+)?(?:(\w+) ([*/+-]) (\w+))?') as _2(match)
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer bigint
);

-- Part 1: solve all the monkeys until we hit root

with recursive
tick as (
  select 0 as i, * from monkey
  union all
  (
    with prev_ as (
      select * from tick
    ),
    -- optimization: keep only rows that are used in unknown calculations (this
    -- speeds things up by an order of magnitude)
    prev as (
      select * from prev_
      where id in (
        select unnest(array[id, monkey1, monkey2]) from prev_ where val is null
      )
    )
    select
      i+1,
      id,
      coalesce(
        val,
        case
          when monkey1_val is null and monkey2_val is null then null
          when op = '+' then monkey1_val + monkey2_val
          when op = '-' then monkey1_val - monkey2_val
          when op = '*' then monkey1_val * monkey2_val
          when op = '/' then monkey1_val / monkey2_val
        end
      ),
      op,
      monkey1,
      monkey2
    from prev as subj
    left join lateral (select val from prev as m1 where m1.id = subj.monkey1) as _1(monkey1_val) on true
    left join lateral (select val from prev as m2 where m2.id = subj.monkey2) as _2(monkey2_val) on true
    where i < 100
      and (select val from prev where id='root') is null
  )
)
insert into answer
select 'part1', val
from tick
where id='root'
  and val is not null
;


-- Part 2: update: 'root' is actually =, and the goal is to find the input for
-- 'humn' that solves this equation. This version simplifies _first_ so that
-- the term 'humn' only appears once in the resulting equation.

update monkey
set val = null
where id = 'humn';

update monkey
set op = '='
where id = 'root';

with recursive
-- first do a reducing pass to simplify everything as much as possible (this
-- part is the same as part1, except we'll never solve root, so we don't
-- bother with that end condition)
tick as (
  select 0 as i, * from monkey
  union all
  (
    with prev_ as (
      select * from tick
    ),
    -- optimization: keep only rows that are used in unknown calculations (this
    -- speeds things up by an order of magnitude)
    prev as (
      select * from prev_
      where id in (
        select unnest(array[id, monkey1, monkey2]) from prev_ where val is null
      )
    )
    select
      i+1,
      id,
      coalesce(
        val,
        case
          when monkey1_val is null and monkey2_val is null then null
          when op = '+' then monkey1_val + monkey2_val
          when op = '-' then monkey1_val - monkey2_val
          when op = '*' then monkey1_val * monkey2_val
          when op = '/' then monkey1_val / monkey2_val
        end
      ),
      op,
      monkey1,
      monkey2
    from prev as subj
    left join lateral (select val from prev as m1 where m1.id = subj.monkey1) as _1(monkey1_val) on true
    left join lateral (select val from prev as m2 where m2.id = subj.monkey2) as _2(monkey2_val) on true
    where i < 100
  )
),
simplified as (
  select distinct on (id) *
  from tick
  order by id, val nulls last
),
-- now build up an equation in terms of humn
rewrite_tick as (
  select
    0 as i,
    id,
    case
      when id = 'humn' then array['h']
      when val is null then null
      else array[val]::text[]
    end as val,
    op,
    monkey1,
    monkey2
  from simplified
  union all
  (
    with prev_ as (
      select * from rewrite_tick
    ),
    prev as (
      select * from prev_
      where not (
        -- optimization: prune rows that we have already solved that do not
        -- participate directly in any unsolved rows (this is also about a 10x
        -- speed up)
        val is not null
        and id not in (
          select unnest(array[id, monkey1, monkey2]) from prev_ where val is null
        )
      )
    )
    select
      i+1,
      id,
      coalesce(
        val,
        case
          when monkey1_val is null or monkey2_val is null then null
          -- prefix notation, but in a flat array
          else array['('] || op || monkey1_val || monkey2_val || array[')']
        end
      ),
      op,
      monkey1,
      monkey2
    from prev as subj
    left join lateral (select val from prev as m1 where m1.id = subj.monkey1) as _1(monkey1_val) on true
    left join lateral (select val from prev as m2 where m2.id = subj.monkey2) as _2(monkey2_val) on true
    where i < 100
      and (select val from prev where id='root') is null
  )
),
rewrite as (
  select *
  from rewrite_tick
  where id='root'
  and val is not null
),
-- finally, solve this equation, inverting step by step until we wind up with
-- just `h` on the left side.
reduced as (
  select
    val[3:array_length(val, 1)-2] as equation,
    val[array_length(val, 1)-1]::bigint as target
  from rewrite
  union all
  select
    case when operand_first
      then equation[4:len-1] -- ( + 1 ( ... ) ) -> ( ... )
      else equation[3:len-2] -- ( + ( ... ) 1 ) => ( ... )
    end as equation,
    case
      -- 10 * x = y  ->  y / 10 = x, same if it's x * 10
      when op = '*' then target / operand::bigint
      -- 10 + x = y  ->  y - 10 = x, same if it's x + 10
      when op = '+' then target - operand::bigint
      -- 10 / x = y  ->  10 / y = x
      when operand_first and op = '/' then operand::bigint / target
      -- 10 - x = y  ->  10 - y = x
      when operand_first and op = '-' then operand::bigint - target
      -- x / 10 = y  ->  10 * y = x
      when op = '/' then operand::bigint * target
      -- x - 10 = y  ->  10 + y = x
      when op = '-' then operand::bigint + target
    end as target
  from reduced
  cross join lateral (select array_length(equation, 1)) as _1(len)
  cross join lateral (
    select
      -- is the other operand first or last?
      equation[len-1] = ')' as operand_first,
      equation[2] as op
  ) as _2
  cross join lateral (
    select case when operand_first
      then equation[3]
      else equation[len-1]
    end as operand
  ) as _3
  where len > 2
)
insert into answer
select 'part2', target from reduced
where array_length(equation, 1) = 1
;

-- Answers

select * from answer;
