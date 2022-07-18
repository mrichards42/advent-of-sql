\c
\echo --- Day 24: Arithmetic Logic Unit ---

-- lol I have no idea how to solve this programatically . . . maybe we need to
-- keep track of symbols somehow?
-- day24.parsing.txt is how I solved this by hand in js


/*
 * Schema
 */

\timing

create temp table instruction (
  id int primary key generated always as identity,
  op text,
  a_reg char not null,
  b_reg char,
  b_num bigint
);

/*
 * Parse input
 */

create temp table raw_input (
  id int primary key generated always as identity,
  line text
);

/* \copy raw_input(line) FROM '2021/day24.sample.txt' */
\copy raw_input(line) FROM '2021/day24.txt'

insert into instruction(op, a_reg, b_reg, b_num)
select
  m[1] as op,
  m[2] as a_reg,
  m[3] as b_reg,
  m[4]::int as b_num
from
  raw_input,
  lateral regexp_match(line, '(\S+) (x|y|z|w)(?: (x|y|z|w)| (-?\d+))?') as m
;

select * from instruction
;

with recursive input_number as (
  select array[1,1,1,1,1,1,1,1,1,1,1,1,1,1] as num
),
alu(ip, input_pos, registers) as (
  select 1, 1, '{"x":0,"y":0,"z":0,"w":0}'::jsonb

  union all

  (
    with prev as (
      select * from alu
    ),
    result as (
      select
        prev.input_pos + (instruction.op = 'inp')::int as input_pos,
        instruction.a_reg as reg_key,
        case instruction.op
          when 'inp' then input_number.num[prev.input_pos]
          when 'add' then a_val + b_val
          when 'mul' then a_val * b_val
          when 'div' then a_val / b_val
          when 'mod' then a_val % b_val
          when 'eql' then (a_val = b_val)::int
        end as reg_val
      from prev
      inner join instruction on prev.ip = instruction.id
      cross join input_number
      cross join lateral (select (prev.registers -> instruction.a_reg)::bigint as a_val) _1
      cross join lateral (
        select coalesce(
          instruction.b_num,
          (prev.registers -> instruction.b_reg)::bigint
        ) as b_val
      ) _2
    )
    select
      prev.ip + 1 as ip,
      result.input_pos as input_pos,
      prev.registers || jsonb_build_object(result.reg_key, result.reg_val) as registers
    from prev
    cross join result
  )
)
select * from alu
left join instruction on alu.ip = instruction.id
;

-- Another version
with recursive input_number as (
  select array[1,1,1,1,1,1,1,1,1,1,1,1,1,1] as num
),
args as (
  select
    array[1,1,1,1,1,26,1,26,26,1,26,26,26,26] as arg1,
    array[10,12,10,12,11,-16,10,-11,-13,13,-8,-1,-4,-14] as arg2,
    array[12,7,8,8,15,12,8,13,3,13,3,9,4,13] as arg3


),
arg2 as (
),
arg3 as (
)
alu(ip, input_pos, registers) as (
  select 1, 1, '{"x":0,"y":0,"z":0,"w":0}'::jsonb

  union all

  (
    with prev as (
      select * from alu
    ),
    result as (
      select
        prev.input_pos + (instruction.op = 'inp')::int as input_pos,
        instruction.a_reg as reg_key,
        case instruction.op
          when 'inp' then input_number.num[prev.input_pos]
          when 'add' then a_val + b_val
          when 'mul' then a_val * b_val
          when 'div' then a_val / b_val
          when 'mod' then a_val % b_val
          when 'eql' then (a_val = b_val)::int
        end as reg_val
      from prev
      inner join instruction on prev.ip = instruction.id
      cross join input_number
      cross join lateral (select (prev.registers -> instruction.a_reg)::bigint as a_val) _1
      cross join lateral (
        select coalesce(
          instruction.b_num,
          (prev.registers -> instruction.b_reg)::bigint
        ) as b_val
      ) _2
    )
    select
      prev.ip + 1 as ip,
      result.input_pos as input_pos,
      prev.registers || jsonb_build_object(result.reg_key, result.reg_val) as registers
    from prev
    cross join result
  )
)
select * from alu
left join instruction on alu.ip = instruction.id
;
