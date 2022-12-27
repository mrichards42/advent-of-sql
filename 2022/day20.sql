\c
\echo --- Day 20: Grove Positioning System ---
\echo expect around 30 seconds

/*
 * Schema
 */

create temp table file (
  id int primary key generated always as identity,
  val bigint
);

/*
 * Parse input
 */

-- No parsing needed today!

/* \copy file(val) FROM '2022/day20.sample.txt' */
\copy file(val) FROM '2022/day20.txt'

select max(val), min(val) from file;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer bigint
);


-- Part 1: a single mix

-- This is kind of slow (1-3 seconds), but I think a single array per iteration
-- is about as fast as I can get. I also tried an hstore linked-list approach
-- which was miserably slow since you have to traverse the list to get to the
-- end point of the move, which takes a nested recursive cte, and unlike an
-- imperative approach, both the hstore list and this array approach end up
-- creating new copies for every iteration, so fewer iterations with the array
-- is a big win.

with recursive
vars as (
  select
    (select count(*) from file) as count,
    (select count(*) from file) as iterations
),
mixed(i, ids) as (
  -- There are duplicate values! Instead of mixing the values, we need to mix
  -- the _ids_ and then come back at the end and fill in the values.
  select 0, array_agg(id order by id)
  from file
  union all
  select
    i + 1,
    -- move the value to the correct position
    case when end_pos > start_pos
      then ids[:start_pos-1] || ids[start_pos+1:end_pos] || target.id || ids[end_pos+1:]
      else ids[:end_pos-1] || target.id || ids[end_pos:start_pos-1] || ids[start_pos+1:]
    end
  from mixed
  cross join vars
  left join file as target on (mixed.i % count + 1) = target.id
  -- find the current position of this element and move it (note that shifting
  -- by count - 1 is a no-op, so we use that as the modulus)
  cross join lateral (select array_position(ids, target.id)) as _1(start_pos)
  cross join lateral (select (start_pos + target.val) % (count - 1)) as _2(end_pos1)
  -- Make sure we're dealing with an actual array index; by default pg arrays
  -- are 1-indexed.
  cross join lateral (select
    case when end_pos1 < 1 then end_pos1 + count - 1 else end_pos1 end
  ) as _3(end_pos)
  where i < iterations
),
-- Now translate from ids back to values
final_mix as (
  select array_agg(file.val order by unnested.idx) as vals
  from mixed, vars
  cross join lateral unnest(ids) with ordinality as unnested(id, idx)
  inner join file on unnested.id = file.id
  where i = iterations
),
-- And pivot so that 0 is first
result as (
  select vals[zero_pos:] || vals[:zero_pos-1] as pivoted
  from final_mix
  cross join lateral (select array_position(vals, 0)) as _(zero_pos)
)
insert into answer
select
  'part1',
  -- +1 since arrays are 1-indexed
  pivoted[1000 % count + 1]
  + pivoted[2000 % count + 1]
  + pivoted[3000 % count + 1]
from result, vars
;


-- Part 2: huge numbers and more iterations

-- Code is identical, except `vars`. This is unfortunately quite slow (like 20
-- seconds).

update file set val = val * 811589153;

with recursive
vars as (
  select
    (select count(*) from file) as count,
    (select count(*) from file) * 10 as iterations
),
mixed(i, ids) as (
  -- There are duplicate values! Instead of mixing the values, we need to mix
  -- the _ids_ and then come back at the end and fill in the values.
  select 0, array_agg(id order by id)
  from file
  union all
  select
    i + 1,
    -- move the value to the correct position
    case when end_pos > start_pos
      then ids[:start_pos-1] || ids[start_pos+1:end_pos] || target.id || ids[end_pos+1:]
      else ids[:end_pos-1] || target.id || ids[end_pos:start_pos-1] || ids[start_pos+1:]
    end
  from mixed
  cross join vars
  left join file as target on (mixed.i % count + 1) = target.id
  -- find the current position of this element and move it (note that shifting
  -- by count - 1 is a no-op, so we use that as the modulus)
  cross join lateral (select array_position(ids, target.id)) as _1(start_pos)
  cross join lateral (select (start_pos + target.val) % (count - 1)) as _2(end_pos1)
  -- Make sure we're dealing with an actual array index; by default pg arrays
  -- are 1-indexed.
  cross join lateral (select
    case when end_pos1 < 1 then end_pos1 + count - 1 else end_pos1 end
  ) as _3(end_pos)
  where i < iterations
),
-- Now translate from ids back to values
final_mix as (
  select array_agg(file.val order by unnested.idx) as vals
  from mixed, vars
  cross join lateral unnest(ids) with ordinality as unnested(id, idx)
  inner join file on unnested.id = file.id
  where i = iterations
),
-- And pivot so that 0 is first
result as (
  select vals[zero_pos:] || vals[:zero_pos-1] as pivoted
  from final_mix
  cross join lateral (select array_position(vals, 0)) as _(zero_pos)
)
insert into answer
select
  'part2',
  -- +1 since arrays are 1-indexed
  pivoted[1000 % count + 1]
  + pivoted[2000 % count + 1]
  + pivoted[3000 % count + 1]
from result, vars
;


-- Answers

select * from answer;
