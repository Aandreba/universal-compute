set windows-shell := ["powershell.exe", "-c"]

build STEP *ARGS:
    zig build -Dcomptime_info {{ARGS}}
    zig build {{STEP}} {{ARGS}}

submodule:
    git submodule update --init --remote --recursive
