\c
\echo --- Day 15: Chiton ---
\echo -- expect about 15 seconds for part 1
\echo -- skipping part 2 since it took 35 minutes :)


-- This took 35 minutes on the big grid (part 2), but it did get the right
-- answer! I think it's pretty well optimized for the single-row-per-square
-- approach, buy it's very possible there's a better way to do this without
-- resorting to functions. In particular, the recursive CTE only tracks nodes
-- that it might visit again (i.e. just the edge of the frontier, and one layer
-- before it) instead of including all visited nodes, which would be a bit more
-- straightforward.

/*
 * Schema
 */

create temp table chiton (
  id int primary key generated always as identity,
  x int,
  y int,
  risk int
);

create temp table edge (
  from_id int,
  to_id int,
  primary key (from_id, to_id)
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day15.sample.txt' */
\copy raw_input(line) FROM '2021/day15.txt'

insert into chiton(x, y, risk)
select
  x + length(line) * (repeat_x - 1) as x,
  id + length(line) * (repeat_y - 1) as y,
  (risk::int + (repeat_x + repeat_y - 2) - 1) % 9 + 1 as risk
from
  raw_input,
  -- part 1 is 1 repeat, part 2 is 5 repeats
  lateral generate_series(1, 1 /* 5 */) as repeat_x,
  lateral generate_series(1, 1 /* 5 */) as repeat_y,
  lateral regexp_split_to_table(line, '') with ordinality as _(risk, x)
order by x, y
;

-- speeds up neighbors a bit
create index if not exists chiton_xy on chiton(x, y);

insert into edge(from_id, to_id)
select chiton.id, neighbor.id
from chiton
inner join chiton as neighbor
  on (chiton.x, chiton.y) in (
    (neighbor.x - 1, neighbor.y    ),
    (neighbor.x + 1, neighbor.y    ),
    (neighbor.x    , neighbor.y + 1),
    (neighbor.x    , neighbor.y - 1)
  )
on conflict
do nothing;

/*
 * The problem
 */

with recursive start_chiton as (
  select *
  from chiton
  order by id asc
  limit 1
),
end_chiton as (
  select *
  from chiton
  order by id desc
  limit 1
),
node(i, id, visited, total_risk, risk) as (
  select 0, id, false, 0, 0
  from start_chiton

  union all

  (
    with prev as (
      select *
      from node
      where i < 1000000
    ),
    -- least cost unvisited node
    best as (
      select *
      from prev
      where not visited
      order by total_risk, id asc
      limit 1
    ),
    -- neighbors that have not already been visited
    immediate_neighbor as (
      select
        best.i,
        neighbor.id,
        prev.total_risk,
        neighbor.risk
      from best
      inner join edge on best.id = edge.from_id
      inner join chiton as neighbor on edge.to_id = neighbor.id
      left join prev on neighbor.id = prev.id
      where not coalesce(prev.visited, false)
    ),
    -- Visited nodes with only visited neighbors can be dropped since we'll
    -- never look at them again. This is about the only optimization I could
    -- come up with.
    droppable_node as (
      select prev.id
      from prev
      left join edge on prev.id = edge.from_id
      -- we're only checking neighbors of already visited nodes, so by
      -- definition those neighbors must be in `prev`, and we don't have to go
      -- back to the main `chiton` table
      left join prev as neighbor
        on edge.to_id = neighbor.id
        and not neighbor.visited
      where prev.visited
      group by prev.id
      having count(neighbor.id) = 0
    )
    -- visited node
    select i + 1, id, true, total_risk, risk
    from best

    union all

    -- neighbors
    select
      immediate_neighbor.i + 1,
      immediate_neighbor.id,
      false as visisted,
      -- if this is a brand new neighbor, total_risk is null, which is ignored
      least(
        best.total_risk + immediate_neighbor.risk,
        immediate_neighbor.total_risk
      ) as total_risk,
      immediate_neighbor.risk
    from immediate_neighbor
    cross join best
    where (select id from best) != (select id from end_chiton)

    union all

    -- everything else
    select i + 1, id, visited, total_risk, risk
    from prev
    where
      -- best and immediate_neighbor handled already
      id != (select id from best)
      and id not in (select id from immediate_neighbor)
      -- nodes that will never be seen again
      and id not in (select id from droppable_node)
      and (select id from best) != (select id from end_chiton)
  )
)

select max(i), max(total_risk) from node
where id = (select id from end_chiton)

union all

select max(i), max(total_risk) from node

union all

select 1, count(*) from node

/* select count(*) from node */

/* visualize it */

/*
select idx, string_agg(line, E'\n' order by y)
from (
  select
    idx,
    chiton.y,
    string_agg(case
      when node.id is null then ' ' || chiton.risk || ' '
      when node.visited then '[' || chiton.risk || ']'
      else '(' || chiton.risk || ')'
    end, '' order by x) as line
  from chiton
  cross join generate_series(0, (select max(i) from node)) as idx
  left join node on chiton.id = node.id and idx = node.i
  group by idx, chiton.y
) t
group by idx
order by idx

*/

;
