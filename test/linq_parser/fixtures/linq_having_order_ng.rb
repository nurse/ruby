from u in q
group u by u + 10 into g
where g > 0
having g > 0
select g
