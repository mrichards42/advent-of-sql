\c
\echo --- Day 16: Packet Decoder ---

/*
 * Schema
 */

create temp table packet (
  id int primary key,
  version_number int not null,
  type_id int not null,
  type_text text not null,
  start_idx int,
  length int not null,
  -- different depending on the type
  val bigint,       -- only for literal
  child_length int, -- for operators with length type 0
  child_count  int  -- for operators with length type 1
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day16.sample.txt' */
\copy raw_input(line) FROM '2021/day16.txt'

-- Almost all of the hard part of this problem is in the parsing, so this is a
-- longer section :)

with recursive input_bits as (
  select id, ('x' || line)::bit varying as bits
  from raw_input
),

-- (1) parse into header and payload
parsed(id, version_number, type_id, parse_type, payload, rest) as (
  select
    -1,
    null::int as version_number,
    null::int as type_id,
    null::text as parse_type,
    null::bit varying as payload,
    bits as rest
  from input_bits

  union all

  (
    with prev as (
      select * from parsed
      where bit_count(rest) > 0 -- done when everything that's left is a 0
    ),
    packet as (
      select
        id,
        substring(rest, 1, 3)::bit(3)::int as version_number,
        substring(rest, 4, 3)::bit(3)::int as type_id,
        substring(rest, 7) as rest
      from prev
    ),
    parse_type as(
      select
        case
          when type_id = 4 then 'literal'
          when substring(rest, 1, 1) = '0' then 'op0'
          when substring(rest, 1, 1) = '1' then 'op1'
        end as parse_type
      from packet
    ),
    payload as (
      select
        case
          when parse_type = 'literal' then (regexp_match(rest::text, '^(?:1....)*(?:0....)'))[1]::bit varying
          when parse_type = 'op0' then substring(rest, 1, 1 + 15) -- length type + 15 bits
          when parse_type = 'op1' then substring(rest, 1, 1 + 11) -- length type + 11 bits
        end as payload
      from packet
      cross join parse_type
    )
    select
      packet.id + 1,
      packet.version_number,
      packet.type_id,
      parse_type.parse_type,
      payload.payload,
      substring(packet.rest, length(payload.payload) + 1) as rest
    from packet
    cross join parse_type
    cross join payload
  )
),

-- (2) parse literal values and insert
_packet_literal as (
  insert into packet(id, version_number, type_id, type_text, length, val)
  select
    id,
    version_number,
    type_id,
    'literal',
    length(payload) + 6, -- 6 for the header
    -- bigint max is 64-bits
    lpad(payload_bits, 64, '0')::bit(64)::bigint as val
  from parsed
  cross join lateral array_to_string(array(
      select regexp_matches(payload::text, '.(....)', 'g')
  ), '') as payload_bits
  where parse_type = 'literal'
)

-- (3) parse operator lengths and types and insert
insert into packet(id, version_number, type_id, type_text, length, child_length, child_count)
select
  id,
  version_number,
  type_id,
  case
    when type_id = 0 then 'sum'
    when type_id = 1 then 'prod'
    when type_id = 2 then 'min'
    when type_id = 3 then 'max'
    when type_id = 5 then 'gt'
    when type_id = 6 then 'lt'
    when type_id = 7 then 'eq'
  end as type_text,
  length(payload) + 6, -- 6 for the header
  case when parse_type = 'op0' then payload_val end as child_length,
  case when parse_type = 'op1' then payload_val end as child_count
from parsed
cross join lateral substring(payload::text, 2) as payload_bits
cross join lateral (select lpad(payload_bits, 64, '0')::bit(64)::bigint as payload_val) _
where parse_type != 'literal'
;

-- (4) add start_idx, based on preceding lengths

with pos as (
  select
    id,
    sum(length) over (
      order by id
      rows between unbounded preceding and 1 preceding
    ) as start_idx
  from packet
)
update packet
set start_idx = coalesce(pos.start_idx, 0)
from pos
where packet.id = pos.id
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer bigint
);

-- Part 1: add up all the version numbers

insert into answer
select 'part1', sum(version_number)
from packet;

-- Part 2: evaluate, from inner to outer

with recursive solution as (
  select
    0 as i,
    id,
    type_text,
    start_idx,
    length,
    child_length,
    child_count,
    val::numeric as val
  from packet

  union all

  (
    with prev as (
      select
        i,
        -- re-number each time so child_count works
        (row_number() over (order by id))::int as id,
        type_text,
        start_idx,
        length,
        child_length,
        child_count,
        val
      from solution
    ),
    -- we don't have to care about the tree structure if we just evaluate
    -- operators from back to front
    oper as (
      select * from prev
      where type_text != 'literal'
      order by id desc
      limit 1
    ),
    args as (
      select prev.*
      from oper
      inner join prev
        on prev.id > oper.id
        and (
          -- length id 0 = the next n children
          prev.id <= (oper.id + oper.child_count)
          -- length id 1 = all values up to child_length
          or prev.start_idx < (oper.start_idx + oper.length + oper.child_length)
        )
    ),
    -- calculate the operator
    result as (
      select
        i + 1,
        id,
        'literal' as type_text,
        start_idx,
        null::int as length,
        null::int as child_length,
        null::int as child_count,
        -- the fun part! evaluate each operator type
        case type_text
          when 'sum' then (
            select sum(val) from args
          )
          when 'prod' then (
            case
              -- avoiding logarithm of 0 :(
              when (select bool_or(val = 0) from args) then 0
              else (
                -- https://www.postgresql.org/message-id/gtmhfi%24u26%242%40reversiblemaps.ath.cx
                select exp(sum(ln(val)))::bigint
                from args
                where val != 0
              )
            end
          )
          when 'min' then (
            select min(val) from args
          )
          when 'max' then (
            select max(val) from args
          )
          when 'gt' then (
            select (vals[1] > vals[2])::int
            from (select array_agg(val order by id) as vals from args) _
          )
          when 'lt' then (
            select (vals[1] < vals[2])::int
            from (select array_agg(val order by id) as vals from args) _
          )
          when 'eq' then (
            select (vals[1] = vals[2])::int
            from (select array_agg(val order by id) as vals from args) _
          )
        end as val
      from oper
    )
    select * from result

    union all

    select
      prev.i + 1,
      prev.id,
      prev.type_text,
      prev.start_idx,
      prev.length,
      prev.child_length,
      prev.child_count,
      prev.val
    from prev
    cross join oper
    where
      -- we're done if there's no operator
      oper.id is not null
      -- otherwise return everything but the current operation
      and prev.id != (select id from oper)
      and prev.id not in (select id from args)
  )
)

insert into answer
select 'part2', val
from solution
where i = (select max(i) from solution)
order by i, id
;

-- Answers

select * from answer;
