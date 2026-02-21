from u in q
join p in posts, on: (u == p)
select u
