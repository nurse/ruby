require File.expand_path("../../../../prototype/lib/linq", __dir__)

Linq.enable_parser_runtime!

users = [1, 2]
bad_source = 123

begin
  q = from u in users
  join p in bad_source on u equals p
  select [u, p]
  p q.to_a
rescue => e
  p [e.class.name, e.message]
end
