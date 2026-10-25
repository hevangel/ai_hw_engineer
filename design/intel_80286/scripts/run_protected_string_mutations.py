#!/usr/bin/env python3
"""Run the INS mutations plus MOVS/STOS/OUTS fault-repair mutations."""

from run_protected_ins_mutations import main


EXTRA_MUTATIONS = [
    (
        "movs_source_wrong_count",
        "gpr[1]<=gpr[1]-(memory_return==STRING_COMMIT ? 16'd2 : 16'd1);",
        "gpr[1]<=gpr[1]-16'd2;",
        "string-fault packet or native indices/count mismatch",
    ),
    (
        "movs_destination_loses_si",
        "gpr[6]<=gpr[6]+string_delta;\n"
        "                                if (memory_return==STRING_COMMIT) gpr[7]<=gpr[7]+string_delta;",
        "gpr[6]<=memory_return==STRING_COMMIT ? gpr[6] : gpr[6]+string_delta;\n"
        "                                if (memory_return==STRING_COMMIT) gpr[7]<=gpr[7]+string_delta;",
        "string-fault packet or native indices/count mismatch",
    ),
    (
        "stos_preserves_di",
        "// Intel LOADALL memo p14: STOS DI/CX repair.\n"
        "                                gpr[7]<=gpr[7]+string_delta;",
        "// Mutation: retain STOS DI.\n                                gpr[7]<=gpr[7];",
        "string-fault packet or native indices/count mismatch",
    ),
    (
        "outs_preserves_si",
        "// for memory-source protection failure.\n"
        "                                gpr[6]<=gpr[6]+string_delta;",
        "// Mutation: retain OUTS SI.\n                                gpr[6]<=gpr[6];",
        "string-fault packet or native indices/count mismatch",
    ),
    (
        "movs_wrap_bypasses_native_repair",
        "!(msw[0] && (opcode==8'ha4 || opcode==8'ha5 || opcode==8'haa ||",
        "!(msw[0] && (opcode==8'haa ||",
        "string-fault packet or native indices/count mismatch",
    ),
]


if __name__ == "__main__":
    main(EXTRA_MUTATIONS)
