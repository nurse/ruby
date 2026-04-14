class String
  with_zjit do
    if Primitive.rb_builtin_basic_definition_p(:delete_prefix)
      undef :delete_prefix

      def delete_prefix(prefix)
        drop = Primitive.cexpr! 'LONG2NUM(deleted_prefix_length(self, prefix))'
        return Primitive.cexpr! 'str_duplicate(rb_cString, self)' if drop == 0

        Primitive.cexpr! 'rb_str_subseq(self, NUM2LONG(drop), RSTRING_LEN(self) - NUM2LONG(drop))'
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:delete_suffix)
      undef :delete_suffix

      def delete_suffix(suffix)
        drop = Primitive.cexpr! 'LONG2NUM(deleted_suffix_length(self, suffix))'
        return Primitive.cexpr! 'str_duplicate(rb_cString, self)' if drop == 0

        Primitive.cexpr! 'rb_str_subseq(self, 0, RSTRING_LEN(self) - NUM2LONG(drop))'
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:lstrip)
      undef :lstrip

      def lstrip(*selectors)
        unless selectors.empty?
          return Primitive.cexpr! 'rb_str_lstrip((int)RARRAY_LEN(selectors), (VALUE *)RARRAY_CONST_PTR(selectors), self)'
        end

        beg = Primitive.cexpr! 'LONG2NUM(lstrip_offset(self, RSTRING_PTR(self), RSTRING_END(self), STR_ENC_GET(self)))'
        return Primitive.cexpr! 'str_duplicate(rb_cString, self)' if beg == 0

        Primitive.cexpr! 'rb_str_subseq(self, NUM2LONG(beg), RSTRING_LEN(self) - NUM2LONG(beg))'
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:rstrip)
      undef :rstrip

      def rstrip(*selectors)
        unless selectors.empty?
          return Primitive.cexpr! 'rb_str_rstrip((int)RARRAY_LEN(selectors), (VALUE *)RARRAY_CONST_PTR(selectors), self)'
        end

        len = Primitive.cexpr! 'LONG2NUM(RSTRING_LEN(self))'
        fin = Primitive.cexpr! 'LONG2NUM(RSTRING_LEN(self) - rstrip_offset(self, RSTRING_PTR(self), RSTRING_END(self), STR_ENC_GET(self)))'
        return Primitive.cexpr! 'str_duplicate(rb_cString, self)' if fin == len

        Primitive.cexpr! 'rb_str_subseq(self, 0, NUM2LONG(fin))'
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:strip)
      undef :strip

      def strip(*selectors)
        unless selectors.empty?
          return Primitive.cexpr! 'rb_str_strip((int)RARRAY_LEN(selectors), (VALUE *)RARRAY_CONST_PTR(selectors), self)'
        end

        len = Primitive.cexpr! 'LONG2NUM(RSTRING_LEN(self))'
        beg = Primitive.cexpr! 'LONG2NUM(lstrip_offset(self, RSTRING_PTR(self), RSTRING_END(self), STR_ENC_GET(self)))'
        fin = Primitive.cexpr! 'LONG2NUM(RSTRING_LEN(self) - rstrip_offset(self, RSTRING_PTR(self), RSTRING_END(self), STR_ENC_GET(self)))'
        return Primitive.cexpr! 'str_duplicate(rb_cString, self)' if beg == 0 && fin == len

        Primitive.cexpr! 'rb_str_subseq(self, NUM2LONG(beg), NUM2LONG(fin) - NUM2LONG(beg))'
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:chomp)
      undef :chomp

      def chomp(separator = (missing = true))
        return Primitive.cexpr! 'rb_str_chomp(1, (VALUE *)&separator, self)' unless missing

        drop = Primitive.cexpr! 'LONG2NUM(RSTRING_LEN(self) - chompped_length(self, rb_rs))'
        return Primitive.cexpr! 'str_duplicate(rb_cString, self)' if drop == 0

        Primitive.cexpr! 'rb_str_subseq(self, 0, RSTRING_LEN(self) - NUM2LONG(drop))'
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:chop)
      undef :chop

      def chop
        drop = Primitive.cexpr! 'LONG2NUM(RSTRING_LEN(self) - chopped_length(self))'
        return Primitive.cexpr! 'str_duplicate(rb_cString, self)' if drop == 0

        Primitive.cexpr! 'rb_str_subseq(self, 0, RSTRING_LEN(self) - NUM2LONG(drop))'
      end
    end
  end
end
