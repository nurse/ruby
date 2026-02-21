q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.group(&b)
  (@calls ||= []) << [:group, b.call(1)]
  self
end

def q.having(&b)
  (@calls ||= []) << [:having, b.call(1)]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.call(1)]
  self
end

from u in q
group u by u + 10
having u > 0
select u

p q.instance_variable_get(:@calls)
