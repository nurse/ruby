require File.expand_path("../../../../prototype/lib/linq", __dir__)

Linq.enable_parser_runtime!

users = [
  { id: 1, score: 7 },
  { id: 2, score: 3 }
]

q = from u in users
where u[:score] > 5
select u[:id]

p q.to_a
