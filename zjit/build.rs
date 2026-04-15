// Ruby builds normally invoke `rustc` directly, but Cargo-based developer
// workflows still run this build script. Use it only to configure Cargo
// builds; make-based builds wire the same state through zjit.mk.
fn main() {
    use std::env;

    println!("cargo:rustc-check-cfg=cfg(ruby_build_dir_generated)");

    // option_env! automatically registers a rerun-if-env-changed
    if let Some(ruby_build_dir) = option_env!("RUBY_BUILD_DIR") {
        println!("cargo:rustc-cfg=ruby_build_dir_generated");

        // Link against libminiruby.a
        println!("cargo:rustc-link-search=native={ruby_build_dir}");
        println!("cargo:rustc-link-lib=static:-bundle=miniruby");
        // Re-link when libminiruby.a changes
        println!("cargo:rerun-if-changed={ruby_build_dir}/libminiruby.a");

        // System libraries that libminiruby needs. Has to be
        // ordered after -lminiruby above.
        let link_flags = env::var("RUBY_LD_FLAGS").unwrap();

        let mut split_iter = link_flags.split(" ");
        while let Some(token) = split_iter.next() {
            if token == "-framework" {
                if let Some(framework) = split_iter.next() {
                    println!("cargo:rustc-link-lib=framework={framework}");
                }
            } else if let Some(lib_name) = token.strip_prefix("-l") {
                println!("cargo:rustc-link-lib={lib_name}");
            }
        }
    }
}
