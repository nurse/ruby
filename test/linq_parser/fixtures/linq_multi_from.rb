q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.from_each(name, &b)
  (@calls ||= []) << [:from_each, name, b.arity, b.call(1)]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.arity, b.call(1, 2)]
  self
end

from u in q
from v in [u + 1]
select [u, v]

p q.instance_variable_get(:@calls)
