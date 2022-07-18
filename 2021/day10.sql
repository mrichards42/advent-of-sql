\c
\echo --- Day 10: Syntax Scoring ---

/*
 * Schema
 */

create temp table pair (
  bracket char,
  matching char,
  score int
);

insert into pair
values
  -- unmatched closing brackets (part 1)
  (')', '(', 3),
  (']', '[', 57),
  ('}', '{', 1197),
  ('>', '<', 25137),
  -- unmatched opening brackets (part 2)
  ('(', ')', 1),
  ('[', ']', 2),
  ('{', '}', 3),
  ('<', '>', 4)
;


/*
 * Read input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day10.sample.txt' */
\copy raw_input(line) FROM '2021/day10.txt'

/*
 * The problem
 */

with recursive
-- replace matching pairs until there are none left
output(id, line) as (
  select * from raw_input
  union
  select id, regexp_replace(line, '\[\]|\(\)|\{\}|<>', '')
  from output
),
-- select the shortest string for each line from the output
simplified as (
  select distinct on (id)
    id, line
  from output
  order by id, length(line)
),

-- Part 1: first incorrect closing bracket

corrupted as (
  select id, (regexp_match(line, '\]|\}|\)|>'))[1] as closing_bracket
  from simplified
),
part1(part, answer) as (
  select 'part1', sum(pair.score)
  from corrupted
  inner join pair on corrupted.closing_bracket = pair.bracket
),

-- Part 2: complete unmatched brackets

incomplete as (
  select
    simplified.id as line_id,
    split.bracket as opening_bracket,
    split.idx as bracket_idx
  from simplified
  cross join lateral regexp_split_to_table(line, '')
    with ordinality as split(bracket, idx)
  -- remove corrupted lines since we're only dealing with incomplete lines
  inner join corrupted on simplified.id = corrupted.id
  where corrupted.closing_bracket is null
),
autocomplete_score as (
  select
    incomplete.line_id,
    /* The math behind this calculation

      ])}>   example string
      2134   scores by bracket

      (2 * 125) + (1 * 25) + (3 * 5) + (4 * 1) = 294

      sum(n * 5 ^ position)
    */
    sum(pair.score * 5 ^ (incomplete.bracket_idx - 1)) as score,
    -- bracket strings purely for debugging
    string_agg(pair.bracket, '' order by incomplete.bracket_idx asc) as original,
    string_agg(pair.matching, '' order by incomplete.bracket_idx desc) as completion
  from incomplete
  inner join pair on incomplete.opening_bracket = pair.bracket
  group by incomplete.line_id
),
part2(part, answer) as (
  -- median
  select 'part2', percentile_disc(0.5) within group (order by score)
  from autocomplete_score
)

-- Answers

select * from part1
union all
select * from part2
;
