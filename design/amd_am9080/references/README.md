# Independent oracle and original software

The unmodified files under `superzazu/` are from
[superzazu/8080, commit 274ffd700b81baabea99b0963bc1260b67132185](https://github.com/superzazu/8080/tree/274ffd700b81baabea99b0963bc1260b67132185),
copyright Nicolas Allemand, MIT license included. `i8080.c` SHA-256:
`aba87f0e380e607b1971943323c96114305b889c1f76c5db303f5262da73db36`.
This external artifact predates this RTL and is the independent oracle.

Its Intel ANA AC formula differs from AMD. The adapter must override AC to
zero only after ANA/ANI, as stated in AMD 1977 handbook 3-10/3-11 and confirmed
by [Alexander Demin's physical AMD-chip tests](https://demin.ws/blog/english/2012/12/24/my-i8080-collection/).
Do not modify the vendored emulator or derive a new reference from the RTL.

Original diagnostics are obtained from [Altair Clone's historical CPU-test
archive](https://altairclone.com/downloads/cpu_tests/). Binary cache is separate
from project source; original instruction bytes are not patched. Record hashes:

| Program | SHA-256 |
|---|---|
| TST8080.COM | `9561c6fb6c99efe3de00eb77e4044fd102151058b39ac2d7bce10483838a08e7` |
| 8080PRE.COM | `18eb3c79cba42c0718f160be6a1853cb64cdce7aa47d65780189a57bdd98c4e0` |
| CPUTEST.COM | `e61a9a75348c774486c2207080ea4effbf6c2367fdace31b0731081a4144030b` |

Primary handbook cache/hash: [repository source cache](../../../references/amd/README.md).
