q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.where(&b)
  (@calls ||= []) << [:where, b.call(1)]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.call(1)]
  self
end

query = from u in q where u > 0 select u

p query.equal?(q)
p q.instance_variable_get(:@calls)
