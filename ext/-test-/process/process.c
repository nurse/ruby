#include <ruby/ruby.h>
#include <ruby/encoding.h>

extern VALUE rb_ruby_binpath(void);

static VALUE
binpath(VALUE klass)
{
    return rb_ruby_binpath();
}

void
Init_process(void)
{
    VALUE m = rb_define_module_under(rb_define_module("Bug"), "Process");
    rb_define_singleton_method(m, "ruby_binpath", binpath, 0);
}
