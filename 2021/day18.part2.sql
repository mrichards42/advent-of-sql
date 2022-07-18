\c

-- Part 1 takes the approach of using a separate row for each number, which is
-- exceptionally verbose, and makes it very challenging to do addition or
-- magnitude calculations in parallel . . . which makes the query even more
-- verbose since it requires nested recursive CTEs :/  Plus I tried to run it
-- on the whole input and gave up after about 10 minutes.

-- The approach I'm taking for part 2 is one row per number, where the numbers
-- and depths are arrays. This is so much faster, and it lets me do all the
-- addition / magnitude calculations at once! IMO the result is a bit more
-- readable than part 1, but it's still pretty dense, especially the array
-- juggling in the addition and magnitude calculations.

-- This ends up taking on the order of 5 seconds.

/*
 * Schema
 */

create temp table snail (
  id int,
  vals int[],
  depths int[]
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
insert into snail(id, vals, depths)
select id, array_agg(val order by x), array_agg(y order by x)
from stack
where val is not null
group by id
;

/*
 * The problem
 */

-- Part 2: find the greatest magnitude from adding any single pair of numbers

with recursive combo as (
  select
    snail.id * 1000 + other.id as id,
    snail.vals || other.vals as vals,
    snail.depths || other.depths as depths
  from snail
  cross join snail as other
  where snail.id != other.id
),

-- (1) add and reduce everything
reduce(i, id, vals, depths) as (
  -- start by increasing the depth of everything by 1
  select 0, combo.id, combo.vals, array_agg(d + 1 order by x)
  from
    combo,
    lateral unnest(depths) with ordinality as _(d, x)
  group by 1, 2, 3

  union all

  (
    with prev as (
      select * from reduce
      where i < 1000
    ),
    explode_idx as (
      select id, array_position(depths, 4) as idx
      from prev
    ),
    split_idx as(
      select
        id, min(idx) as idx
      from prev
      cross join lateral unnest(vals) with ordinality as _(val, idx)
      where val > 9
      group by id
    )

    select
      prev.i + 1,
      prev.id,
      case
        when explode_idx.idx = 1
          -- leftmost explode has no left neighbor
          then array[0]
            || array[prev.vals[explode_idx.idx + 2] + explode_right]
            || prev.vals[explode_idx.idx + 3 :]
        when explode_idx.idx + 1 = array_length(prev.vals, 1)
          -- rightmost explode has no right neighbor
          then prev.vals[: explode_idx.idx - 2]
            || array[prev.vals[explode_idx.idx - 1] + explode_left]
            || array[0]
        when explode_idx.idx is not null
          then prev.vals[: explode_idx.idx - 2]
            || array[prev.vals[explode_idx.idx - 1] + explode_left]
            || array[0]
            || array[prev.vals[explode_idx.idx + 2] + explode_right]
            || prev.vals[explode_idx.idx + 3 :]
        when split_idx.idx is not null
          then prev.vals[: split_idx.idx - 1]
            || array[(split_val / 2)::int, ((split_val + 0.5) / 2)::int]
            || prev.vals[split_idx.idx + 1 :]
      end as vals,
      case
        when explode_idx.idx is not null
          then prev.depths[: explode_idx.idx - 1]
            || array[explode_depth - 1]
            || prev.depths[explode_idx.idx + 2 :]
        when split_idx.idx is not null
          then prev.depths[: split_idx.idx - 1]
            || array[split_depth + 1, split_depth + 1]
            || prev.depths[split_idx.idx + 1 :]
      end as depths
    from prev
    left join explode_idx on prev.id = explode_idx.id
    cross join lateral (select prev.vals[explode_idx.idx] as explode_left) as t1
    cross join lateral (select prev.vals[explode_idx.idx + 1] as explode_right) as t2
    cross join lateral (select prev.depths[explode_idx.idx] as explode_depth) as t3
    left join split_idx on prev.id = split_idx.id
    cross join lateral (select prev.vals[split_idx.idx] as split_val) as t4
    cross join lateral (select prev.depths[split_idx.idx] as split_depth) as t5
    where
      explode_idx.idx is not null
      or split_idx.idx is not null
  )
),
final_step as (
  select id, max(i) as i
  from reduce
  group by id
),
final_combo as (
  select reduce.id, reduce.vals, reduce.depths
  from reduce
  inner join final_step
    on reduce.id = final_step.id
    and reduce.i = final_step.i
),

-- (2) then calculate the magnitudes
magnitude(i, id, vals, depths) as (
  select 0, id, vals, depths
  from final_combo

  union all

  (
    with prev as (
      select * from magnitude
    ),
    max_depth as (
      select id, max(d) as max_depth
      from prev, lateral unnest(depths) as d
      group by id
    ),
    inner_idx as (
      select prev.id, array_position(depths, max_depth.max_depth) as idx
      from prev
      inner join max_depth on prev.id = max_depth.id
    )
    select
      prev.i + 1,
      prev.id,
      -- reduce the two vals to one
      prev.vals[: inner_idx.idx - 1]
      || array[ 3 * prev.vals[inner_idx.idx] + 2 * prev.vals[inner_idx.idx + 1] ]
      || prev.vals[inner_idx.idx + 2 :]
      as vals,
      -- remove one level of depth
      prev.depths[: inner_idx.idx - 1]
      || array[ prev.depths[inner_idx.idx] - 1 ]
      || prev.depths[inner_idx.idx + 2 :]
      as depths
    from prev
    inner join inner_idx on prev.id = inner_idx.id
    inner join max_depth on prev.id = max_depth.id
    where max_depth.max_depth >= 0
  )
),
final_mag_step as (
  select id, max(i) as i
  from magnitude
  group by id
),
final_magnitude as (
  select
    magnitude.id as id,
    magnitude.vals[1] as magnitude
  from magnitude
  inner join final_mag_step
    on magnitude.id = final_mag_step.id
    and magnitude.i = final_mag_step.i
)

select
  'part2' as part,
  max(magnitude) as answer
from final_magnitude
;
