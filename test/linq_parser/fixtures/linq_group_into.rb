q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.group_into(into_name, &b)
  (@calls ||= []) << [:group_into, into_name, b.arity, b.call(1)]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.arity, b.call(:g)]
  self
end

from u in q
group u by u + 10 into g
select g

p q.instance_variable_get(:@calls)
