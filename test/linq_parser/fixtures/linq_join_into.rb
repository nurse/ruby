q = Object.new
posts = :posts

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.join_into(src, join_name, into_name, &b)
  (@calls ||= []) << [:join_into, src, join_name, into_name, b.arity, b.call(1, 2)]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.arity, b.call(1, :g)]
  self
end

from u in q
join p in posts on u equals p into g
select [u, g]

p q.instance_variable_get(:@calls)
