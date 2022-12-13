\c
\echo --- Day 13: Distress Signal ---


-- So these are actually trees, but I bet I can get away with doing flat lists
-- and including [ ] in the list

/*
 * Schema
 */

create temp table signal (
  id int primary key generated always as identity,
  -- we only have to deal with numbers 0-10, so converting 10 to 'x' makes a
  -- simple string possible
  packet text
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2022/day13.sample.txt' */
\copy raw_input(line) FROM '2022/day13.txt'

insert into signal(packet)
select regexp_replace(regexp_replace(line, '10', 'x', 'g'), ',', '', 'g')
from raw_input
where length(line) > 0
order by id
;

/*
 * The problem
 */

-- Part 1: which packet pairs are in order?

with recursive
pair as (
  select pair as id, array_agg(packet order by id) as packets
  from signal
  cross join lateral (select floor((id + 1) / 2)) as _(pair)
  group by pair
),
cmp(id, packets) as (
  select * from pair
  union all
  select
    id,
    case
      -- same character means we just continue
      when fst[1] = fst[2] then rest
      -- one list has ended before the other, this means we can be done
      when fst[1] = ']' then array['right']
      when fst[2] = ']' then array['wrong']
      -- one list started before the other means we have to wrap the other one
      -- in [], but we can avoid one comparison by skipping the '[' and just
      -- adding the ']' after the first character
      when fst[1] = '[' then array[rest[1], fst[2] || ']' || rest[2]]
      when fst[2] = '[' then array[fst[1] || ']' || rest[1], rest[2]]
      -- otherwise one number has to be larger than the other
      when fst[1] < fst[2] then array['right']
      else array['wrong']
    end
  from cmp
  cross join lateral (
    select
      array[left(packets[1], 1), left(packets[2], 1)],
      array[right(packets[1], -1), right(packets[2], -1)]
  ) as _(fst, rest)
  -- < 2 means we have an answer
  where array_length(packets, 1) = 2
),
result as (
  select
    id,
    packets[1] = 'right' as correct_order
  from cmp
  where array_length(packets, 1) = 1
),
part1(part, answer) as (
  select 'part1', sum(id)
  from result
  where correct_order = true
),

-- Part 2 is sorting all the packets

-- It is possible to sort these lexicographically if you first normalize where
-- single numbers need to turn into lists (and then make ']' sort first). I did
-- this on the sample input, but I couldn't come up with an easy way to do this
-- programmatically. So instead it's just nested recursive CTEs :/

all_packets as (
  -- insert the two dividers
  select packet from signal
  union all
  values ('[[2]]'), ('[[6]]')
),
ordered(i, orig_id, idx, packet) as (
  select 0, row_number() over (), row_number() over (), packet from all_packets
  union all
  (
    with recursive
    prev as (
      select * from ordered
    ),
    pair as (
      select
        array_agg(idx order by idx) as idxs,
        array_agg(packet order by idx) as packets
      from prev
      -- Alternate sorting the even and odd pairs. Basically bubblesort but in
      -- parallel.
      cross join lateral (select floor((idx + (i % 2)) / 2)) as _(pair)
      group by pair
    ),
    -- the comparison logic is identical to part 1
    cmp(idxs, packets) as (
      select * from pair
      union all
      select
        idxs,
        case
          when fst[1] = fst[2] then rest
          when fst[1] = ']' then array['right']
          when fst[2] = ']' then array['wrong']
          when fst[1] = '[' then array[rest[1], fst[2] || ']' || rest[2]]
          when fst[2] = '[' then array[fst[1] || ']' || rest[1], rest[2]]
          when fst[1] < fst[2] then array['right']
          else array['wrong']
        end
      from cmp
      cross join lateral (
        select
          array[left(packets[1], 1), left(packets[2], 1)],
          array[right(packets[1], -1), right(packets[2], -1)]
      ) as _(fst, rest)
      where array_length(packets, 1) = 2
    ),
    -- Then we figure out which indexes need to be swapped
    wrong_pair(idx, diff) as (
      select idxs[1], 1 from cmp where packets[1] = 'wrong'
      union all
      select idxs[2], -1 from cmp where packets[1] = 'wrong'
    )
    select
      prev.i + 1,
      prev.orig_id,
      prev.idx + coalesce(wrong_pair.diff, 0),
      prev.packet
    from prev
    left join wrong_pair on wrong_pair.idx = prev.idx
    where i < 1000 and (select 1 from wrong_pair limit 1) = 1
  )
),
final as (
  select * from ordered
  where i = (select max(i) from ordered)
),
part2_slow(part, answer) as (
  select 'part2',
    (select idx from final where packet = '[[2]]')
    * (select idx from final where packet = '[[6]]')
),

-- OH DANG except since [[2]] and [[6]] only have one number, only the first
-- number actually matters, and it's very easy to normalize just the first
-- number (by making the number of opening brackets the same).

leading_brackets as (
  select max(length((regexp_match(packet, '^(\[+)[\dx]'))[1])) as count
  from all_packets
),
normalized_packets as (
  -- closing bracket needs to sort before numbers, x already sorts above 0-9,
  -- so this is the only thing we need to change
  select packet, norm_packet, regexp_replace(norm_packet, '\]', ')', 'g') as sort_packet
  from all_packets
  cross join lateral (select repeat('[', count) from leading_brackets) as _1(brackets)
  cross join lateral (
    select regexp_replace(packet, '^\[+([\dx])', brackets || '\1')
  ) as _2(norm_packet)
),
sorted as (
  -- collate "C", otherwise postgres tries to sort only by letters and numbers
  select row_number() over (order by sort_packet collate "C") as idx, packet
  from normalized_packets
  order by 1
),
part2_fast(part, answer) as (
  select 'part2',
    (select idx from sorted where packet = '[[2]]')
    * (select idx from sorted where packet = '[[6]]')
)

-- Answers

select * from part1
union all
/* select * from part2_slow */
/* union all */ 
select * from part2_fast
;
