# Helpers shared by Ruby builtin generation tools that consume dump_ast JSON.

module BuiltinAST
  BUILTIN_ATTRS = %w[leaf inline_block use_block c_trace without_interrupts].freeze

  PrimitiveCall = Struct.new(:name, :args, :receiver)

  def self.extract_string_literal(node)
    case node["type"]
    when "StringNode"
      node["unescaped"]
    when "InterpolatedStringNode"
      node["parts"].map { |part| extract_string_literal(part) }.join
    else
      raise "unexpected #{node["type"]}"
    end
  end

  def self.line_number(source, node)
    source.b.byteslice(0, node["location"]["start"]).count("\n") + 1
  end

  def self.primitive_call(node)
    return nil unless node["type"] == "CallNode"

    receiver = node["receiver"]
    primitive_name = nil

    if (!receiver.nil? && receiver["type"] == "ConstantReadNode" && receiver["name"] == "Primitive") ||
       (!receiver.nil? && receiver["type"] == "CallNode" && receiver["flags"].include?("VARIABLE_CALL") && receiver["name"] == "__builtin")
      primitive_name = node["name"]
    elsif node["name"].start_with?("__builtin_")
      primitive_name = node["name"][10..-1]
    else
      return nil
    end

    args = node["arguments"].nil? ? [] : node["arguments"]["arguments"]
    PrimitiveCall.new(primitive_name, args, receiver)
  end

  def self.each_node(root, &blk)
    return unless yield root

    root.each do |key, value|
      next if key == "type" || key == "location"

      if value.is_a?(Hash)
        each_node(value, &blk) if value.key?("type")
      elsif value.is_a?(Array) && value[0].is_a?(Hash)
        value.each { |node| each_node(node, &blk) }
      end
    end
  end
end
