\c
\echo --- Day 8: Seven Segment Search ---

/*
 * Schema
 */

create temp table display (
  entry_id int,        -- input row
  idx int,             -- order of this display in the input
  entry_type text,     -- 'sample' or 'output'
  display text,        -- textual representation of the display
  segment_mask bit(7), -- bitmask of which segments are lit up
  segment_count int,   -- number of segments lit up
  digit int            -- 0-9, the resolved digit for this display
);

-- this speeds up the final digit calculation quite a bit
create index if not exists entry_type_idx
  on display(entry_type, entry_id);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

\copy raw_input(line) FROM '2021/day08.sample.txt'
/* \copy raw_input(line) FROM '2021/day08.txt' */

insert into display
select
  id as entry_id,
  display_idx as idx,
  case
    when section_idx = 1 then 'sample'
    else 'output'
  end as entry_type,
  display,
  segment_mask,
  length(display) as segment_count,
  null as digit
from
  raw_input,
  -- split into sample and output sections by '|'
  lateral unnest(string_to_array(line, ' | '))
    with ordinality as _section(section, section_idx),
  -- split into display segments
  lateral unnest(string_to_array(section, ' '))
    with ordinality as _display(display, display_idx),
  -- convert each display into a bitset
  lateral (
    select
      sum(set_bit(b'0000000', ascii(c) - ascii('a'), 1)::int)::bit(7)
      as segment_mask
    from regexp_split_to_table(display, '') as c
  ) as _bits
;

/*
 * The problem
 */

create temp table answer (
  part text,
  answer int
);

-- Part 1: assign digits to all unambiguous displays

update display set digit = 1 where segment_count = 2;
update display set digit = 7 where segment_count = 3;
update display set digit = 4 where segment_count = 4;
update display set digit = 8 where segment_count = 7;

insert into answer
select 'part1', count(*)
from display
where
  entry_type = 'output'
  and digit is not null
;

-- Part 2: figure out the rest of the digits

with digit_calc as (
  select
    entry_id,
    segment_mask,
    case
      when segment_count = 5 and overlap1 = 2 then 3
      when segment_count = 5 and overlap4 = 2 then 2
      when segment_count = 5                  then 5
      when segment_count = 6 and overlap1 = 1 then 6
      when segment_count = 6 and overlap4 = 4 then 9
      when segment_count = 6                  then 0
      else null -- should never get here
    end as digit
  from display
  -- number of segments that overlap with digit 1
  cross join lateral (
    select bit_count(display.segment_mask & ones.segment_mask) as overlap1
    from display as ones
    where
      ones.digit = 1
      and ones.entry_type = 'sample'
      and display.entry_id = ones.entry_id
  ) as overlap1
  -- number of segments that overlap with digit 4
  cross join lateral (
    select bit_count(display.segment_mask & fours.segment_mask) as overlap4
    from display as fours
    where
      fours.digit = 4
      and fours.entry_type = 'sample'
      and display.entry_id = fours.entry_id
  ) as verlap4
  where digit is null
  order by entry_id, segment_mask
)
update display set digit = digit_calc.digit
from digit_calc
where
  display.entry_id = digit_calc.entry_id
  and display.segment_mask = digit_calc.segment_mask
;

with output_display as (
  select
    entry_id,
    string_agg(digit::text, '' order by idx)::int as output
  from display
  where
    entry_type = 'output'
    and digit is not null
  group by entry_id
  order by entry_id
)
insert into answer
select 'part2', sum(output)
from output_display
;

-- Answers

select * from answer;
