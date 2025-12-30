\echo --- Day 11: Reactor ---

/*
 * Schema
 */

create temp table edges (
  from_id text,
  to_id text
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

-- \copy raw_input(line) FROM '2025/day11.sample.txt'
\copy raw_input(line) FROM '2025/day11.txt'

insert into edges
select split1[1] as from_id, to_id
from raw_input
cross join lateral string_to_array(line, ': ') as _split1(split1)
cross join lateral string_to_table(split1[2], ' ') as _split2(to_id);

/*
 * The problem
 */

-- Part 1: number of distinct paths from 'you' to 'out'

with recursive

frontier1 as (
  select 'you' as node_id, 1::bigint as n

  union all

  (
    with prev as (
      select * from frontier1
    )
    select edges.to_id, sum(prev.n)::bigint
    from prev
    inner join edges on prev.node_id = edges.from_id
    group by 1
  )
),

part1(part, answer) as (
  select 'part1', sum(n) from frontier1 where node_id = 'out'
),

-- Part 2: number of paths from 'svr' to 'out' that also pass through 'dac' and 'fft'

frontier2 as (
  select 'svr' as node_id, false as dac, false as fft, 1::bigint as n

  union all

  (
    with prev as (
      select * from frontier2
    )
    select
      edges.to_id,
      dac or edges.to_id = 'dac' as dac,
      fft or edges.to_id = 'fft' as fft,
      sum(prev.n)::bigint
    from prev
    inner join edges on prev.node_id = edges.from_id
    group by 1, 2, 3
  )
),

part2(part, answer) as (
  select 'part2', sum(n) from frontier2 where node_id = 'out' and dac and fft
)

-- Answers

select * from part1
union all
select * from part2
;
