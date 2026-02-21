from = 10
where = 20
select = 30
p [from, where, select]

obj = Object.new

def obj.from(v)
  v + 1
end

p obj.from(41)
