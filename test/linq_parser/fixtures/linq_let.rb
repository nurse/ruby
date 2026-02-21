q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.let(name, &b)
  (@calls ||= []) << [:let, name, b.arity, b.call(1)]
  self
end

def q.where(&b)
  (@calls ||= []) << [:where, b.arity, b.call(1, 11)]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.arity, b.call(1, 11)]
  self
end

from u in q
let x = u + 10
where x > 5
select [u, x]

p q.instance_variable_get(:@calls)
