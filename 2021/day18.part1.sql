\c
\echo --- Day 18: Snailfish ---

-- This is sort of ridiculous, but it does work, and only takes a second or so
-- for part 1. This representation works reasonably well for iteratively adding
-- up a single number, but it completely falls apart for part 2 when we need to
-- add almost 10k pairs of numbers separately. See the part 2 file for an
-- array-based approach that's both shorter and a lot faster.


/*

-- Here's how we can represent these numbers in tabular form

[[3,[2,[1,[7,3]]]],[6,[5,[4,[3,2]]]]]
  x 1 2 3 4 5 6 7 8 9 0
y |
1 | 3         6
2 |   2         5
3 |     1        4
4 |       7 3      3 2

Because numbers are in pairs, x/y does uniquely identify the hierarchy.

*/


/*
 * Schema
 */

create temp table snail (
  id int,       -- line number
  x decimal,    -- index within the flattened array
  y int,        -- depth
  val int       -- the actual number
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day18.sample.txt' */
\copy raw_input(line) FROM '2021/day18.txt'

with recursive stack(id, x, y, val, line) as (
  select id, 0.1, -1, null::int, replace(line, ',', '')
  from raw_input

  union all

  select
    id,
    case
      when ch = '[' or ch = ']' then x
      else x + 1
    end as x,
    case
      when ch = '[' then y + 1
      when ch = ']' then y - 1
      else y
    end as y,
    case
      when ch similar to '[0123456789]' then ch::int
      else null
    end as val,
    substr(line, 2) as line
  from stack
  cross join lateral substr(line, 1, 1) as ch
  where ch != ''
)
insert into snail(id, x, y, val)
select id, x, y, val
from stack
where val is not null
order by id, x, y
;

-- visualizing these numbers just as a flat sequence
/* select id, string_agg(val::text, ' ' order by x) */
/* from snail */
/* group by id */
/* order by id; */

/*
 * The problem
 */

-- Part 1: add up all the 'numbers' and determine their final 'magnitude'

with recursive iteration(i, id, x, y, val) as (
  select 0, id, x, y, val
  from snail

  union all

  (
    with recursive prev_iteration as (
      select * from iteration
      where i < 100
    ),
    ids as (
      select distinct id from prev_iteration
      where (select count(distinct id) from prev_iteration) > 1
    ),
    add1 as (
      select *
      from prev_iteration
      where id = (select id from ids order by id limit 1)
    ),
    add2 as (
      select *
      from prev_iteration
      where id = (select id from ids order by id limit 1 offset 1)
    ),
    addition(j, id, x, y, val) as (
      select 0, 1, x, y + 1, val
      from add1

      union all

      select
        0,
        1,
        x + (select max(x) from add1),
        y + 1,
        val
      from add2

      union all

      -- reduce!
      (
        with prev as (
          select * from addition
          where j < 2000 -- just to make sure this doesn't go off the rails
        ),
        -- Each step of this reduction is either 'explode' or 'split', where
        -- explode is prioritzed above split.
        op_type as (
          select
            case
              when bool_or(y = 4) then 'explode'
              when bool_or(val >= 10) then 'split'
            end as op
          from prev
        ),
        -- (1) explode!
        -- explode means take a pair nested 4 spots deep and push the numbers
        -- "outward", i.e. the left number is added to the number left of the pair;
        -- the right number is added to the number right of the pair.
        explode_left as (
          select *
          from prev
          where prev.y = 4
          order by x
          limit 1
        ),
        explode_right as (
          select *
          from prev
          where prev.y = 4
          order by x
          limit 1
          offset 1
        ),
        explode_left_target as (
          select
            prev.x,
            prev.y,
            prev.val + explode_left.val
          from explode_left
          inner join prev on prev.x = (select max(x) from prev where x < explode_left.x)
        ),
        explode_right_target as (
          select
            prev.x,
            prev.y,
            prev.val + explode_right.val
          from explode_right
          inner join prev on prev.x = (select min(x) from prev where x > explode_right.x)
        ),
        explode_new_row(x, y, val) as (
          select * from explode_left_target

          union all

          select * from explode_right_target

          union all

          select x, y - 1, 0
          from explode_left
        ),
        explode_output as (
          select
            prev.j + 1,
            prev.id,
            prev.x,
            coalesce(explode_new_row.y, prev.y),
            coalesce(explode_new_row.val, prev.val)
          from prev
          cross join op_type
          left join explode_new_row on prev.x = explode_new_row.x
          where
            op_type.op = 'explode'
            -- the right pair is dropped
            and prev.x != (select x from explode_right)
        ),
        -- (2) split!
        -- split means take a big number and split it into a pair, where the left
        -- number is n / 2 rounded down, and the right number is n / 2 rounded up.
        split as (
          select prev.*
          from prev
          cross join op_type
          where
            prev.val >= 10
            and op_type.op = 'split'
          order by x
          limit 1
        ),
        split_new_row as (
          select
            j + 1,
            id,
            -- We need to keep x values in order, even after splitting, so we
            -- just tack on another decimal place to each. The left target gets
            -- a 1, and the right target gets a 2.
            (x::text || '1')::decimal,
            y + 1,
            val / 2 -- half, round down
          from split

          union all

          select
            j + 1,
            id,
            (x::text || '2')::decimal,
            y + 1,
            ((val + 0.5) / 2)::int -- half, round up
          from split
        ),
        split_output as (
          select * from split_new_row

          union all

          select prev.j + 1, prev.id, prev.x, prev.y, prev.val
          from prev
          cross join op_type
          where
            op_type.op = 'split'
            -- replace the original number
            and prev.x != (select x from split)
        )
        -- Result of this reduction step. We're guaranteed that only one of
        -- explode_output and split_output has rows. If there are no more
        -- reductions left, both will be empty.
        select * from explode_output
        union all
        select * from split_output
      )
    )
    -- Just the last iteration
    select (select i + 1 from prev_iteration limit 1), id, x, y, val
    from addition
    where j = (select max(j) from addition)

    union all

    -- the rest
    select i + 1, id, x, y, val
    from prev_iteration
    where id in (select id from ids order by id offset 2)
  )
),
final_number as (
  select x, y, val
  from iteration
  where i = (select max(i) from iteration)
),

-- finally, add everything up!
magnitude(x, y, val) as (
  select * from final_number

  union all

  (
    with raw_prev as (
      select * from magnitude
    ),
    prev as (
      select * from raw_prev
      where (select count(*) from raw_prev) > 1
    ),
    -- collapse the next most deeply nested pair
    to_collapse as (
      select *
      from prev
      where y = (select max(y) from prev)
      order by x
      limit 2
    ),
    collapsed as (
      select
        avg(x) as x,
        min(y) as y, -- y vals are always the same, so min is arbitrary
        array_agg(val order by x) as vals
      from to_collapse
    )
    select x, y - 1, 3 * vals[1] + 2 * vals[2]
    from collapsed
    where array_length(vals, 1) = 2

    union all

    select x, y, val
    from prev
    where x not in (select x from to_collapse)
  )
)

select
  'part1' as part,
  max(val) as answer
from magnitude
;
