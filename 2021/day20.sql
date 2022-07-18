\c
\echo --- Day 20: Trench Map ---
\echo -- expect about 30 seconds

/*
 * Schema
 */

create temp table grid (
  x int,
  y int,
  val bit,
  primary key (x, y)
);

create temp table rule (
  id bit(9) primary key,
  output bit
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day20.sample.txt' */
\copy raw_input(line) FROM '2021/day20.txt'

with bit_input as (
  select
    id,
    replace(replace(line, '#', '1'), '.', '0') as line
  from raw_input
),
_rule as (
  insert into rule(id, output)
  select
    (idx - 1)::bit(9), -- postgres indexes start at 1 :)
    output::bit
  from
    bit_input,
    lateral regexp_split_to_table(line, '') with ordinality as _(output, idx)
  where id = 1
)
insert into grid(x, y, val)
select x, id, val::bit
from
  bit_input,
  lateral regexp_split_to_table(line, '') with ordinality as _(val, x)
where id > 2
;

-- Add a nice big border
with bound as (
  select
    min(x) as x_min,
    max(x) as x_max,
    min(y) as y_min,
    max(y) as y_max
  from grid
)
insert into grid(x, y, val)
select x, y, 0::bit
from bound
cross join lateral (select 50 as border_size) as _
cross join lateral generate_series(x_min - border_size, x_max + border_size) as x
cross join lateral generate_series(y_min - border_size, y_max + border_size) as y
on conflict
do nothing
;


-- Grid viz

/* select y, string_agg(case when val = B'1' then '#' else '.' end, '' order by x) */
/* from grid */
/* group by y; */

/*
 * The problem
 */

with recursive generation(gen, x, y, val) as (
  select 0, x, y, val
  from grid

  union all

  (
    with prev as (
      select * from generation
      where gen < 50
    )
    select
      prev.gen + 1,
      prev.x,
      prev.y,
      rule.output
    from prev
    -- top row
    left join prev as tl on tl.x = prev.x - 1 and tl.y = prev.y - 1
    left join prev as tc on tc.x = prev.x + 0 and tc.y = prev.y - 1
    left join prev as tr on tr.x = prev.x + 1 and tr.y = prev.y - 1
    -- middle row (no central square since that's `prev`)
    left join prev as ml on ml.x = prev.x - 1 and ml.y = prev.y + 0
    left join prev as mr on mr.x = prev.x + 1 and mr.y = prev.y + 0
    -- bottom row
    left join prev as bl on bl.x = prev.x - 1 and bl.y = prev.y + 1
    left join prev as bc on bc.x = prev.x + 0 and bc.y = prev.y + 1
    left join prev as br on br.x = prev.x + 1 and br.y = prev.y + 1
    cross join lateral (
      select
        coalesce(tl.val, prev.val)
        || coalesce(tc.val, prev.val)
        || coalesce(tr.val, prev.val)
        || coalesce(ml.val, prev.val)
        || prev.val
        || coalesce(mr.val, prev.val)
        || coalesce(bl.val, prev.val)
        || coalesce(bc.val, prev.val)
        || coalesce(br.val, prev.val)
        as rule_id
    ) as surrounding
    inner join rule on surrounding.rule_id = rule.id
  )
),
final_gen as (
  select * from generation
  where gen = (select max(gen) from generation)
),

/* select gen, y, string_agg(case when val = B'1' then '#' else '.' end, '' order by x) */
/* from generation */
/* group by gen, y */
/* order by gen, y */

final_count as (
  select gen, count(*) as count
  from generation
  where val = B'1'
  group by gen
  order by gen
)

select 'part1' as part, count as answer
from final_count
where gen = 2
union all
select 'part2' as part, count as answer
from final_count
where gen = 50
;
