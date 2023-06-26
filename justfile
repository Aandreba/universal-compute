build STEP *ARGS:
    zig build comptime_info {{ARGS}}
    zig build {{STEP}} {{ARGS}}
