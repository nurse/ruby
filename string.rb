class String
  with_zjit do
    if Primitive.rb_builtin_basic_definition_p(:delete_prefix)
      undef :delete_prefix

      def delete_prefix(prefix)
        drop = Primitive.rb_str_delete_prefix_len(prefix)
        return Primitive.rb_str_vstr_copy unless drop

        Primitive.rb_str_vstr_subseq(drop, Primitive.rb_str_vstr_bytesize - drop)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:delete_suffix)
      undef :delete_suffix

      def delete_suffix(suffix)
        drop = Primitive.rb_str_delete_suffix_len(suffix)
        return Primitive.rb_str_vstr_copy unless drop

        Primitive.rb_str_vstr_subseq(0, Primitive.rb_str_vstr_bytesize - drop)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:lstrip)
      undef :lstrip

      def lstrip(*selectors)
        return Primitive.rb_str_lstrip_selectors(selectors) unless selectors.empty?

        beg = Primitive.rb_str_lstrip_beg
        return Primitive.rb_str_vstr_copy if beg == 0

        Primitive.rb_str_vstr_subseq(beg, Primitive.rb_str_vstr_bytesize - beg)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:rstrip)
      undef :rstrip

      def rstrip(*selectors)
        return Primitive.rb_str_rstrip_selectors(selectors) unless selectors.empty?

        len = Primitive.rb_str_vstr_bytesize
        fin = Primitive.rb_str_rstrip_end
        return Primitive.rb_str_vstr_copy if fin == len

        Primitive.rb_str_vstr_subseq(0, fin)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:strip)
      undef :strip

      def strip(*selectors)
        return Primitive.rb_str_strip_selectors(selectors) unless selectors.empty?

        len = Primitive.rb_str_vstr_bytesize
        beg = Primitive.rb_str_lstrip_beg
        fin = Primitive.rb_str_rstrip_end
        return Primitive.rb_str_vstr_copy if beg == 0 && fin == len

        slice_len = fin - beg
        Primitive.rb_str_vstr_subseq(beg, slice_len)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:chomp)
      undef :chomp

      def chomp(separator = (missing = true))
        return Primitive.rb_str_chomp_arg(separator) unless missing

        drop = Primitive.rb_str_chomp_drop
        return Primitive.rb_str_vstr_copy if drop == 0

        Primitive.rb_str_vstr_subseq(0, Primitive.rb_str_vstr_bytesize - drop)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:chop)
      undef :chop

      def chop
        drop = Primitive.rb_str_chop_drop
        return Primitive.rb_str_vstr_copy if drop == 0

        Primitive.rb_str_vstr_subseq(0, Primitive.rb_str_vstr_bytesize - drop)
      end
    end
  end
end
