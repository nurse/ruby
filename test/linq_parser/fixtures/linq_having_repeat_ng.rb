from u in q
group u by u + 10 into g
having g > 0
having g > -1
select g
