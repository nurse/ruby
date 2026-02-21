q = Object.new
posts = :posts

def q.from(x)
  (@calls ||= []) << [:from, x]
  self
end

def q.join(src, &b)
  (@calls ||= []) << [:join, src, b.call(1, 1)]
  self
end

def q.where(&b)
  (@calls ||= []) << [:where, b.call(1, 1)]
  self
end

def q.select(&b)
  (@calls ||= []) << [:select, b.call(1, 1)]
  self
end

from u in q
join p in posts on u equals p
where (u + p) > 1
select [u, p]

p q.instance_variable_get(:@calls)
