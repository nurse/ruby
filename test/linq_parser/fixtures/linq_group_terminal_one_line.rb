q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.group(&b)
  (@calls ||= []) << [:group, b.call(1)]
  self
end

query = from u in q group u by u + 10

p query.equal?(q)
p q.instance_variable_get(:@calls)
