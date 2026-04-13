unless defined?($__zjit_virtual_string_slice_compare_ready)
  if GC.respond_to?(:auto_compact=)
    GC.auto_compact = ENV["RUBY_VSTR_DISABLE"] == "1"
  end

  def vstr_chain(s)
    s.strip.delete_prefix("https://").end_with?("/")
  end

  $__zjit_virtual_string_slice_compare_inputs = [
    "  https://example.com/\n",
    "http://example.com",
  ].freeze
  $__zjit_virtual_string_slice_compare_index = -1

  4.times do
    $__zjit_virtual_string_slice_compare_inputs.each do |input|
      vstr_chain(input)
    end
  end

  $__zjit_virtual_string_slice_compare_ready = true
end

$__zjit_virtual_string_slice_compare_index =
  ($__zjit_virtual_string_slice_compare_index + 1) & 1
vstr_chain(
  $__zjit_virtual_string_slice_compare_inputs[
    $__zjit_virtual_string_slice_compare_index
  ]
)
