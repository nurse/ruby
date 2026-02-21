let = :local
obj = Object.new

def obj.let(x)
  x + 1
end

p [let, obj.let(2)]
