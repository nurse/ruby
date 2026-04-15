class String
  with_zjit do
    if Primitive.rb_builtin_basic_definition_p(:delete_prefix)
      undef :delete_prefix

      def delete_prefix(prefix)
        drop = Primitive.rb_str_delete_prefix_len(prefix)
        return Primitive.rb_str_vstr_full(Primitive.cconst!('INT2FIX(VSTR_FRESH_ON_MATERIALIZE)')) unless drop

        Primitive.rb_str_vstr_subseq(drop, Primitive.rb_str_vstr_bytesize - drop, 0)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:delete_suffix)
      undef :delete_suffix

      def delete_suffix(suffix)
        drop = Primitive.rb_str_delete_suffix_len(suffix)
        return Primitive.rb_str_vstr_full(Primitive.cconst!('INT2FIX(VSTR_FRESH_ON_MATERIALIZE)')) unless drop

        Primitive.rb_str_vstr_subseq(0, Primitive.rb_str_vstr_bytesize - drop, 0)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:lstrip)
      undef :lstrip

      def lstrip(*selectors)
        return Primitive.rb_str_lstrip_fallback(selectors) unless selectors.empty?

        beg = Primitive.rb_str_lstrip_beg
        return Primitive.rb_str_vstr_full(Primitive.cconst!('INT2FIX(VSTR_FRESH_ON_MATERIALIZE)')) unless beg

        Primitive.rb_str_vstr_subseq(beg, Primitive.rb_str_vstr_bytesize - beg, 0)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:rstrip)
      undef :rstrip

      def rstrip(*selectors)
        return Primitive.rb_str_rstrip_fallback(selectors) unless selectors.empty?

        fin = Primitive.rb_str_rstrip_end
        return Primitive.rb_str_vstr_full(Primitive.cconst!('INT2FIX(VSTR_FRESH_ON_MATERIALIZE)')) unless fin

        Primitive.rb_str_vstr_subseq(0, fin, 0)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:strip)
      undef :strip

      def strip(*selectors)
        return Primitive.rb_str_strip_fallback(selectors) unless selectors.empty?

        beg = Primitive.rb_str_strip_beg
        return Primitive.rb_str_vstr_full(Primitive.cconst!('INT2FIX(VSTR_FRESH_ON_MATERIALIZE)')) unless beg

        fin = Primitive.rb_str_strip_end_from(beg)
        Primitive.rb_str_vstr_subseq(beg, fin - beg, 0)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:chomp)
      undef :chomp

      def chomp(separator = (missing = true))
        return Primitive.rb_str_chomp_fallback(separator) unless missing

        drop = Primitive.rb_str_chomp_drop
        return Primitive.rb_str_vstr_full(Primitive.cconst!('INT2FIX(VSTR_FRESH_ON_MATERIALIZE)')) unless drop

        Primitive.rb_str_vstr_subseq(0, Primitive.rb_str_vstr_bytesize - drop, 0)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:chop)
      undef :chop

      def chop
        drop = Primitive.rb_str_chop_drop
        return Primitive.rb_str_vstr_full(Primitive.cconst!('INT2FIX(VSTR_FRESH_ON_MATERIALIZE)')) unless drop

        Primitive.rb_str_vstr_subseq(0, Primitive.rb_str_vstr_bytesize - drop, 0)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:bytesize)
      undef :bytesize

      def bytesize
        Primitive.rb_str_vstr_bytesize
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:empty?)
      undef :empty?

      def empty?
        Primitive.rb_str_vstr_bytesize == 0
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:start_with?)
      undef :start_with?

      def start_with?(*args)
        return Primitive.rb_str_start_with_fallback(args) unless args.length == 1

        arg = args[0]
        Primitive.rb_str_vstr_start_with(arg)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:end_with?)
      undef :end_with?

      def end_with?(*args)
        return Primitive.rb_str_end_with_fallback(args) unless args.length == 1

        arg = args[0]
        Primitive.rb_str_vstr_end_with(arg)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:eql?)
      undef :eql?

      def eql?(other)
        Primitive.rb_str_vstr_eql(other)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:==)
      undef :==

      def ==(other)
        Primitive.rb_str_vstr_equal(other)
      end
    end

    if Primitive.rb_builtin_basic_definition_p(:byteindex)
      undef :byteindex

      def byteindex(needle, offset = (missing = true))
        Primitive.rb_str_vstr_byteindex(needle, offset, missing)
      end
    end
  end
end
