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

ary=[];from u in q where 1 select 2

p q.instance_variable_get(:@calls)
