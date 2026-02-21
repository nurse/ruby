q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.where(&b)
  (@calls ||= []) << [:where, b.call(1)]
  self
end

def q.orderby(dir = nil, &b)
  (@calls ||= []) << [:orderby, b.call(1), dir]
  self
end

def q.limit(n)
  (@calls ||= []) << [:limit, n]
  self
end

def q.offset(n)
  (@calls ||= []) << [:offset, n]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.call(1)]
  self
end

from u in q
where u > 0
orderby u + 10 descending
limit 3
offset 1
select u

p q.instance_variable_get(:@calls)
