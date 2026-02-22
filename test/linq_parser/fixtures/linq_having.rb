q = Object.new

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.group_into(into_name, &b)
  (@calls ||= []) << [:group_into, into_name, b.call(1)]
  self
end

def q.having(&b)
  (@calls ||= []) << [:having, b.call({ key: 11, items: [1] })]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.call({ key: 11, items: [1] })]
  self
end

from u in q
group u by u + 10 into g
having g[:key] > 0
select g

p q.instance_variable_get(:@calls)
