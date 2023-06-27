use std::str::FromStr;
use wasmer::*;

#[repr(C)]
pub struct Program {
    store: Store,
}

pub extern "C" fn compile_program(
    wasm: *const u8,
    wasm_len: usize,
    target_triple: *const u8,
    target_triple_len: usize,
    program: *mut Program,
) {
    let engine: Engine = cfg_if::cfg_if! {
        if #[cfg(target_family = "wasm")] {
            Engine::default()
        } else {
            Engine(LLVM::default())
        }
    };

    let triple: Triple = match target_triple.is_null() {
        true => Triple::host(),
        false => unsafe {
            let triple_str = core::str::from_utf8(core::slice::from_raw_parts(
                target_triple,
                target_triple_len,
            ))
            .unwrap();
            Triple::from_str(triple_str).unwrap()
        },
    };

    let mut store = Store::new(engine);
    let module = Module::from_binary(engine, bytes);
}
