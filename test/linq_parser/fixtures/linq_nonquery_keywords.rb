join = 1
group = 2
orderby = 3
having = 4
limit = 5
offset = 6

obj = Object.new

def obj.join(x)
  x * 2
end

def obj.group(x)
  x + 10
end

def obj.orderby(x)
  x - 1
end

def obj.having(x)
  x.to_s
end

def obj.limit(x)
  x
end

def obj.offset(x)
  x
end

p [join, group, orderby, having, limit, offset]
p [obj.join(2), obj.group(3), obj.orderby(4), obj.having(5), obj.limit(6), obj.offset(7)]
