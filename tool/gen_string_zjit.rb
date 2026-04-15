require 'json'
require 'open3'
require 'stringio'
require_relative 'lib/builtin_ast'

FRESH_CONST = 'INT2FIX(VSTR_FRESH_ON_MATERIALIZE)'
TARGET_METHODS = %w[
  delete_prefix
  delete_suffix
  lstrip
  rstrip
  strip
  chomp
  chop
  bytesize
  empty?
  start_with?
  end_with?
  eql?
  ==
  byteindex
].freeze

SCALAR_PRIMITIVES = %w[
  rb_str_delete_prefix_len
  rb_str_delete_suffix_len
  rb_str_lstrip_beg
  rb_str_rstrip_end
  rb_str_strip_beg
  rb_str_strip_end_from
  rb_str_chomp_drop
  rb_str_chop_drop
].freeze

PURE_FALLBACK_PRIMITIVES = %w[
  rb_str_lstrip_fallback
  rb_str_rstrip_fallback
  rb_str_strip_fallback
  rb_str_chomp_fallback
  rb_str_start_with_fallback
  rb_str_end_with_fallback
].freeze

CONSUMER_TERMINALS = %w[
  rb_str_vstr_bytesize
  rb_str_vstr_start_with
  rb_str_vstr_end_with
  rb_str_vstr_eql
  rb_str_vstr_equal
  rb_str_vstr_byteindex
].freeze

MethodIR = Struct.new(:name, :requireds, :rest, :optionals, :statements, keyword_init: true)
WrapperSpec = Struct.new(:name, :source_name, :args, :arg_kinds, :return_kind, :nil_fallback, keyword_init: true)

def error_at(source, node, message)
  line = BuiltinAST.line_number(source, node)
  raise "string.rb:#{line}: #{message}"
end

def read_ast(dump_ast, path)
  stdout, stderr, status = Open3.capture3(dump_ast, path)
  raise stderr unless status.success?
  JSON.parse(stdout)
end

def primitive_call_name(node)
  primitive = BuiltinAST.primitive_call(node)
  primitive&.name
end

def with_zjit_block(root, source)
  class_node = root.dig('statements', 'body')&.find do |node|
    node['type'] == 'ClassNode' && node.dig('constant_path', 'type') == 'ConstantReadNode' && node.dig('constant_path', 'name') == 'String'
  end
  raise 'string.rb: class String not found' unless class_node

  call = class_node.dig('body', 'body')&.find do |node|
    node['type'] == 'CallNode' && node['receiver'].nil? && node['name'] == 'with_zjit' && node['block']
  end
  error_at(source, class_node, 'with_zjit block not found in String') unless call
  call.dig('block', 'body', 'body') || []
end

def extract_methods(root, source)
  methods = {}

  with_zjit_block(root, source).each do |node|
    next unless node['type'] == 'IfNode'

    predicate = BuiltinAST.primitive_call(node['predicate'])
    next unless predicate&.name == 'rb_builtin_basic_definition_p'

    arg = predicate.args.first
    next unless arg && arg['type'] == 'SymbolNode'

    method_name = arg['unescaped']
    next unless TARGET_METHODS.include?(method_name)

    def_node = node.dig('statements', 'body')&.find { |stmt| stmt['type'] == 'DefNode' && stmt['name'] == method_name }
    error_at(source, node, "target method #{method_name} is missing def body under with_zjit") unless def_node
    methods[method_name] = def_node
  end

  missing = TARGET_METHODS - methods.keys
  raise "string.rb: missing target methods: #{missing.join(', ')}" unless missing.empty?
  methods
end

def parse_params(node, source)
  params = node['parameters']
  return [[], nil, []] if params.nil?

  requireds = params.fetch('requireds', []).map { |param| param['name'] }
  rest = params['rest']&.dig('name')
  optionals = params.fetch('optionals', []).map do |param|
    value = param['value']
    unless value && value['type'] == 'ParenthesesNode'
      error_at(source, param, "unsupported optional parameter shape in #{node['name']}")
    end
    [param['name'], value]
  end

  [requireds, rest, optionals]
end

def parse_expr(source, node)
  case node['type']
  when 'IntegerNode'
    { kind: :int, value: node['value'] }
  when 'NilNode'
    { kind: :nil }
  when 'LocalVariableReadNode'
    { kind: :local, name: node['name'] }
  when 'CallNode'
    if (primitive = BuiltinAST.primitive_call(node))
      case primitive.name
      when 'cexpr!', 'cstmt!'
        error_at(source, node, "Primitive.#{primitive.name} is not allowed in target methods")
      when 'cconst!'
        text = BuiltinAST.extract_string_literal(primitive.args.fetch(0))
        error_at(source, node, 'Primitive.cconst! is only allowed for VSTR_FRESH_ON_MATERIALIZE') unless text == FRESH_CONST
        { kind: :fresh_const }
      else
        { kind: :primitive, name: primitive.name, args: primitive.args.map { |arg| parse_expr(source, arg) } }
      end
    else
      recv = node['receiver'] && parse_expr(source, node['receiver'])
      args = node['arguments'] ? node['arguments']['arguments'].map { |arg| parse_expr(source, arg) } : []
      case node['name']
      when '+', '-', '==', '!=', 'empty?', 'length', '[]'
        { kind: :call, name: node['name'], recv: recv, args: args }
      else
        error_at(source, node, "unsupported call #{node['name']} in target method")
      end
    end
  else
    error_at(source, node, "unsupported expression node #{node['type']}")
  end
end

def parse_guard(source, node)
  body = node.dig('statements', 'body') || []
  unless body.size == 1 && body.first['type'] == 'ReturnNode'
    error_at(source, node, 'only single-return guard branches are supported')
  end

  return_args = body.first.dig('arguments', 'arguments') || []
  unless return_args.size == 1
    error_at(source, body.first, 'guard return must return exactly one expression')
  end

  {
    kind: :guard,
    branch: node['type'] == 'UnlessNode' ? :unless : :if,
    predicate: parse_expr(source, node['predicate']),
    return_expr: parse_expr(source, return_args.first),
    node: node,
  }
end

def parse_statement(source, node)
  case node['type']
  when 'LocalVariableWriteNode'
    {
      kind: :assign,
      name: node['name'],
      expr: parse_expr(source, node['value']),
      node: node,
    }
  when 'IfNode', 'UnlessNode'
    parse_guard(source, node)
  when 'CallNode'
    {
      kind: :expr,
      expr: parse_expr(source, node),
      node: node,
    }
  else
    error_at(source, node, "unsupported statement node #{node['type']}")
  end
end

def parse_method(source, node)
  requireds, rest, optionals = parse_params(node, source)
  body = node.dig('body', 'body') || []
  MethodIR.new(
    name: node['name'],
    requireds: requireds,
    rest: rest,
    optionals: optionals,
    statements: body.map { |stmt| parse_statement(source, stmt) },
  )
end

def expr_equal?(lhs, rhs)
  lhs == rhs
end

def bytesize_expr?(expr)
  expr[:kind] == :primitive && expr[:name] == 'rb_str_vstr_bytesize' && expr[:args].empty?
end

def fresh_full?(expr)
  expr[:kind] == :primitive &&
    expr[:name] == 'rb_str_vstr_full' &&
    expr[:args].size == 1 &&
    expr[:args].first[:kind] == :fresh_const
end

def subseq_call?(expr)
  expr[:kind] == :primitive &&
    expr[:name] == 'rb_str_vstr_subseq' &&
    expr[:args].size == 3 &&
    expr[:args][2] == { kind: :int, value: 0 }
end

def fallback_guard?(stmt)
  return false unless stmt[:kind] == :guard && stmt[:branch] == :unless

  expr = stmt[:return_expr]
  expr[:kind] == :primitive && PURE_FALLBACK_PRIMITIVES.include?(expr[:name])
end

def producer_method?(method)
  stmt = method.statements.last
  stmt && stmt[:kind] == :expr && subseq_call?(stmt[:expr])
end

def normalize_from_full_guard(local_name, off_expr, len_expr)
  local = { kind: :local, name: local_name }

  return :zero if expr_equal?(off_expr, local)
  return :length if expr_equal?(len_expr, local)

  if len_expr[:kind] == :call &&
     len_expr[:name] == '-' &&
     bytesize_expr?(len_expr[:recv]) &&
     len_expr[:args].size == 1 &&
     expr_equal?(len_expr[:args].first, local)
    return :zero
  end

  raise "unsupported fresh-on-materialize normalization for #{local_name}"
end

def jit_wrapper_name(source_name)
  suffix =
    if source_name.start_with?('rb_str_vstr_')
      source_name.delete_prefix('rb_str_vstr_')
    elsif source_name.start_with?('rb_str_')
      source_name.delete_prefix('rb_str_')
    else
      raise "unexpected primitive name #{source_name}"
    end
  "rb_jit_vstr_#{suffix}"
end

def classify_method(source, method)
  if producer_method?(method)
    classify_producer(source, method)
  else
    classify_consumer(source, method)
  end
end

def classify_producer(source, method)
  stmts = method.statements.dup
  fallback = stmts.shift if fallback_guard?(stmts.first)

  assigns = []
  full_guard = nil
  while (stmt = stmts.shift)
    if stmt[:kind] == :assign
      expr = stmt[:expr]
      unless expr[:kind] == :primitive && SCALAR_PRIMITIVES.include?(expr[:name])
        error_at(source, stmt[:node], "producer assignments must use supported scalar Primitive.* calls in #{method.name}")
      end
      assigns << stmt
      next
    end

    if stmt[:kind] == :guard && stmt[:branch] == :unless && stmt[:predicate][:kind] == :local && fresh_full?(stmt[:return_expr])
      full_guard = stmt
      break
    end

    error_at(source, stmt[:node], "unsupported producer statement order in #{method.name}")
  end

  error_at(source, method.statements.last[:node], "producer #{method.name} is missing fresh full guard") unless full_guard

  while stmts.first&.dig(:kind) == :assign
    stmt = stmts.shift
    expr = stmt[:expr]
    unless expr[:kind] == :primitive && SCALAR_PRIMITIVES.include?(expr[:name])
      error_at(source, stmt[:node], "producer assignments must use supported scalar Primitive.* calls in #{method.name}")
    end
    assigns << stmt
  end

  error_at(source, method.statements.last[:node], "producer #{method.name} must end with a single rb_str_vstr_subseq call") unless stmts.size == 1 && stmts.first[:kind] == :expr

  final = stmts.first[:expr]
  off_expr, len_expr = final[:args][0], final[:args][1]
  guarded_local = full_guard[:predicate][:name]
  nil_fallback = normalize_from_full_guard(guarded_local, off_expr, len_expr)
  scalar_locals = assigns.map { |assign| assign[:name] }

  wrappers = assigns.map do |assign|
    primitive = assign[:expr]
    arg_kinds = primitive[:args].map do |arg|
      case arg[:kind]
      when :local
        if method.requireds.include?(arg[:name])
          :value
        elsif scalar_locals.include?(arg[:name])
          :cint
        else
          raise "unsupported scalar arg local #{arg[:name]} in #{method.name}"
        end
      else
        raise "unsupported scalar arg #{arg.inspect} in #{method.name}"
      end
    end
    WrapperSpec.new(
      name: jit_wrapper_name(primitive[:name]),
      source_name: primitive[:name],
      args: primitive[:args],
      arg_kinds: arg_kinds,
      return_kind: :cint,
      nil_fallback: assign[:name] == guarded_local ? nil_fallback : nil,
    )
  end

  {
    kind: :producer,
    name: method.name,
    args_shape: producer_args_shape(method),
    fallback: fallback,
    assignments: assigns,
    off_expr: off_expr,
    len_expr: len_expr,
    wrappers: wrappers,
  }
end

def producer_args_shape(method)
  return :no_args if method.requireds.empty? && method.rest.nil? && method.optionals.empty?
  return :no_args if method.requireds.empty? && !method.rest.nil? && method.optionals.empty?
  return :string_arg if method.requireds.size == 1 && method.rest.nil? && method.optionals.empty?
  return :no_args if method.requireds.empty? && method.rest.nil? && method.optionals.size == 1
  raise "unsupported producer parameter shape for #{method.name}"
end

def classify_consumer(source, method)
  stmts = method.statements.dup
  fallback = stmts.shift if fallback_guard?(stmts.first)
  while stmts.first&.dig(:kind) == :assign
    stmts.shift
  end
  error_at(source, method.statements.last[:node], "consumer #{method.name} must end with a single expression") unless stmts.size == 1 && stmts.first[:kind] == :expr

  expr = stmts.first[:expr]
  case method.name
  when 'bytesize'
    unless bytesize_expr?(expr)
      error_at(source, stmts.first[:node], 'bytesize must be Primitive.rb_str_vstr_bytesize')
    end
    { kind: :consumer, name: method.name, inline: :inline_string_bytesize, return_type: 'types::Fixnum', wrappers: [] }
  when 'empty?'
    unless expr[:kind] == :call &&
           expr[:name] == '==' &&
           bytesize_expr?(expr[:recv]) &&
           expr[:args] == [{ kind: :int, value: 0 }]
      error_at(source, stmts.first[:node], 'empty? must be Primitive.rb_str_vstr_bytesize == 0')
    end
    { kind: :consumer, name: method.name, inline: :inline_string_empty_p, return_type: 'types::BoolExact', wrappers: [] }
  else
    unless expr[:kind] == :primitive && CONSUMER_TERMINALS.include?(expr[:name])
      error_at(source, stmts.first[:node], "unsupported consumer terminal in #{method.name}")
    end

    inline, return_type =
      case expr[:name]
      when 'rb_str_vstr_start_with' then [:inline_string_start_with, 'types::BoolExact']
      when 'rb_str_vstr_end_with' then [:inline_string_end_with, 'types::BoolExact']
      when 'rb_str_vstr_eql' then [:inline_string_eql, 'types::BoolExact']
      when 'rb_str_vstr_equal' then [:inline_string_eq, 'types::BoolExact']
      when 'rb_str_vstr_byteindex' then [:inline_string_byteindex, 'types::Fixnum.union(types::NilClass)']
      else
        raise "unexpected consumer terminal #{expr[:name]}"
      end

    wrappers = []
    if expr[:name] != 'rb_str_vstr_bytesize'
      wrappers << WrapperSpec.new(
        name: jit_wrapper_name(expr[:name]),
        source_name: expr[:name],
        args: expr[:args],
        arg_kinds: Array.new(expr[:args].size, :value),
        return_kind: expr[:name] == 'rb_str_vstr_byteindex' ? :byteindex : :value,
        nil_fallback: nil,
      )
    end

    {
      kind: :consumer,
      name: method.name,
      inline: inline,
      return_type: return_type,
      fallback: fallback,
      wrappers: wrappers,
    }
  end
end

def rust_expr_contains_bytesize?(expr)
  return true if bytesize_expr?(expr)
  return false unless expr.is_a?(Hash)

  case expr[:kind]
  when :call
    rust_expr_contains_bytesize?(expr[:recv]) || expr[:args].any? { |arg| rust_expr_contains_bytesize?(arg) }
  when :primitive
    expr[:args].any? { |arg| rust_expr_contains_bytesize?(arg) }
  else
    false
  end
end

def emit_rust_cint_expr(io, expr, counter)
  case expr[:kind]
  when :int
    raise "unsupported integer literal #{expr[:value]}" unless expr[:value] == 0
    'zero_cint64(fun, block)'
  when :local
    expr[:name]
  when :primitive
    raise "unsupported producer primitive #{expr[:name]} in scalar expression" unless expr[:name] == 'rb_str_vstr_bytesize'
    'bytesize'
  when :call
    case expr[:name]
    when '-'
      left = emit_rust_cint_expr(io, expr[:recv], counter)
      right = emit_rust_cint_expr(io, expr[:args].fetch(0), counter)
      tmp = "_tmp#{counter[:value]}"
      counter[:value] += 1
      io.puts "    let #{tmp} = fun.push_insn(block, hir::Insn::IntSub { left: #{left}, right: #{right} });"
      tmp
    else
      raise "unsupported scalar operator #{expr[:name]}"
    end
  else
    raise "unsupported scalar expression kind #{expr[:kind]}"
  end
end

def rust_value_expr(expr)
  case expr[:kind]
  when :local
    expr[:name]
  else
    raise "unsupported VALUE expression #{expr.inspect}"
  end
end

def emit_rust_wrapper_args(exprs)
  exprs.map { |expr| rust_value_expr(expr) }.join(', ')
end

def emit_producer_inline(io, method)
  io.puts "fn inline_string_zjit_#{method[:name].gsub(/\W/, '_')}(fun: &mut hir::Function, block: hir::BlockId, recv: hir::InsnId, args: &[hir::InsnId], state: hir::InsnId) -> Option<hir::InsnId> {"
  io.puts "    let recv = ensure_vstr(fun, block, recv, state)?;"

  if method[:args_shape] == :string_arg
    arg_name = method[:assignments].first[:expr][:args].first[:name]
    io.puts "    let [#{arg_name}] = args else { return None; };"
    io.puts "    let #{arg_name} = guard_vstr_string_arg(fun, block, recv, *#{arg_name}, state)?;"
  else
    io.puts "    let &[] = args else { return None; };"
  end

  if rust_expr_contains_bytesize?(method[:off_expr]) || rust_expr_contains_bytesize?(method[:len_expr])
    io.puts "    let bytesize = vstr_length(fun, block, recv);"
  end

  method[:assignments].zip(method[:wrappers]).each do |assign, wrapper|
    args = emit_rust_wrapper_args(wrapper.args)
    arg_list = args.empty? ? 'vec![]' : "vec![#{args}]"
    io.puts "    let #{assign[:name]} = vstr_scalar_helper(fun, block, recv, #{wrapper.name} as *const u8, #{arg_list});"
  end

  counter = { value: 0 }
  off = emit_rust_cint_expr(io, method[:off_expr], counter)
  len = emit_rust_cint_expr(io, method[:len_expr], counter)
  io.puts "    let off = #{off};"
  io.puts "    let len = #{len};"
  io.puts '    Some(call_vstr_subseq(fun, block, recv, off, len))'
  io.puts "}"
  io.puts
end

def emit_c_wrapper(io, wrapper)
  io.puts(wrapper.return_kind == :cint ? 'long' : 'VALUE')
  case wrapper.return_kind
  when :cint
    params = ['const rb_jit_vstr_t *slice']
    params.concat(wrapper.arg_kinds.each_with_index.map do |kind, idx|
      case kind
      when :value then "VALUE arg#{idx}"
      when :cint then "long arg#{idx}"
      else raise "unexpected arg kind #{kind}"
      end
    end)
    io.puts "#{wrapper.name}(#{params.join(', ')})"
    io.puts '{'
    io.puts '    struct RString fake_str = {RBASIC_INIT};'
    call_args = wrapper.arg_kinds.each_with_index.map do |kind, idx|
      kind == :cint ? "LONG2NUM(arg#{idx})" : "arg#{idx}"
    end.join(', ')
    io.puts "    VALUE result = #{wrapper.source_name}(NULL, rb_jit_vstr_fake_string(slice, &fake_str)#{call_args.empty? ? '' : ", #{call_args}"});"
    case wrapper.nil_fallback
    when :zero
      io.puts '    return NIL_P(result) ? 0 : NUM2LONG(result);'
    when :length
      io.puts '    return NIL_P(result) ? slice->len : NUM2LONG(result);'
    when nil
      io.puts '    RUBY_ASSERT(!NIL_P(result));'
      io.puts '    return NUM2LONG(result);'
    else
      raise "unexpected nil fallback #{wrapper.nil_fallback}"
    end
    io.puts '}'
  when :value
    params = ['const rb_jit_vstr_t *slice']
    params.concat(Array.new(wrapper.args.size) { |idx| "VALUE arg#{idx}" })
    io.puts "#{wrapper.name}(#{params.join(', ')})"
    io.puts '{'
    io.puts '    struct RString fake_str = {RBASIC_INIT};'
    call_args = Array.new(wrapper.args.size) { |idx| "arg#{idx}" }.join(', ')
    io.puts "    return #{wrapper.source_name}(NULL, rb_jit_vstr_fake_string(slice, &fake_str)#{call_args.empty? ? '' : ", #{call_args}"});"
    io.puts '}'
  when :byteindex
    io.puts "#{wrapper.name}(const rb_jit_vstr_t *slice, VALUE needle, long initpos)"
    io.puts '{'
    io.puts '    struct RString fake_str = {RBASIC_INIT};'
    io.puts "    return #{wrapper.source_name}(NULL, rb_jit_vstr_fake_string(slice, &fake_str), needle, LONG2NUM(initpos), Qfalse);"
    io.puts '}'
  else
    raise "unexpected wrapper return kind #{wrapper.return_kind}"
  end
  io.puts
end

def generate_c(methods)
  wrappers = methods.flat_map { |method| method[:wrappers] }.uniq { |wrapper| wrapper.name }
  out = StringIO.new
  out.puts "/* This file is @generated by tool/gen_string_zjit.rb from string.rb. */"
  out.puts
  wrappers.each { |wrapper| emit_c_wrapper(out, wrapper) }
  out.string
end

def consumer_registry_inline(method)
  method[:inline]
end

def emit_registry(io, methods)
  io.puts "pub(crate) fn string_zjit_cfunc_name(cfunc: *const u8) -> Option<&'static str> {"
  first = true
  methods.flat_map { |method| method[:wrappers] }.uniq { |wrapper| wrapper.name }.each do |wrapper|
    prefix = first ? '    if' : '    else if'
    io.puts "#{prefix} cfunc == #{wrapper.name} as *const u8 {"
    io.puts "        Some(\"#{wrapper.name}\")"
    io.puts '    }'
    first = false
  end
  io.puts '    else {'
  io.puts '        None'
  io.puts '    }'
  io.puts '}'
  io.puts

  methods.select { |method| method[:kind] == :producer }.each do |method|
    emit_producer_inline(io, method)
  end

  io.puts 'pub(crate) fn init_string_zjit_methods(annotations: &mut Annotations) {'
  methods.each do |method|
    inline_name =
      if method[:kind] == :producer
        "inline_string_zjit_#{method[:name].gsub(/\W/, '_')}"
      else
        method[:inline].to_s
      end
    call_guard =
      if method[:kind] == :producer
        method[:args_shape] == :string_arg ? 'call_guard_one_string_arg' : 'call_guard_no_args'
      else
        'no_call_guard'
      end
    returns_vstr = method[:kind] == :producer ? 'true' : 'false'
    return_type = method[:kind] == :producer ? 'types::StringExact' : method[:return_type]

    io.puts "    register_iseq_method(annotations, \"#{method[:name]}\", FnProperties {"
    io.puts "        return_type: #{return_type},"
    io.puts "        returns_vstr: #{returns_vstr},"
    io.puts "        call_guard: #{call_guard},"
    io.puts "        inline: #{inline_name},"
    io.puts '        ..Default::default()'
    io.puts '    });'
  end
  io.puts '}'
end

def generate_rust(methods)
  out = StringIO.new
  out.puts '// This file is @generated by tool/gen_string_zjit.rb from string.rb.'
  out.puts
  emit_registry(out, methods)
  out.string
end

def main
  unless ARGV.size == 4
    abort "usage: #{$PROGRAM_NAME} DUMP_AST STRING_RB OUT_RS OUT_C"
  end

  dump_ast, string_rb, out_rs, out_c = ARGV
  source = File.read(string_rb)
  ast = read_ast(dump_ast, string_rb)
  extracted = extract_methods(ast, source)
  methods = TARGET_METHODS.map { |name| parse_method(source, extracted.fetch(name)) }.map { |method| classify_method(source, method) }

  File.write(out_rs, generate_rust(methods))
  File.write(out_c, generate_c(methods))
end

main if $PROGRAM_NAME == __FILE__
