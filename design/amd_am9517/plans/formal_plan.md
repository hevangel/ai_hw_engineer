# Am9517 formal plan

Adapt the peripheral's symbolic channel safety proof for native asynchronous
reset, grant-time arbitration and pending CPU access. Prove ownership/strobes,
one DACK, register/count updates, READY stalls, base preservation, auto reload,
copy phases, pointer toggle and original AMD status/map differences. Use
async2sync only in sampled formal analysis; simulation checks off-edge reset.
BMC, unbounded PDR and nonvacuous covers are required. Covers use explicit
programming sequences and valid software requests for memory copies.
