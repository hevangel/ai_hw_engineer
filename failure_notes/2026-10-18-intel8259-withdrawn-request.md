# 8259A request withdrawal during Model 30 warm restart

## External failure

Original IBM PC DOS 3.30 FDISK created a partition through the Model 30 DBA
controller, then jumped through the original BIOS reset vector. Warm POST
reported 102 (timer failure), although cold POST and all existing PIC tests
passed. The original ROM and DOS bytes were unchanged.

## Root cause and independent authority

The PIC reference model and RTL both treated an edge request as irrevocably
pending until acknowledged. After the old mode-3 PIT request, POST programmed
mode 0, which lowered OUT0. The stale IRR0 nevertheless survived and caused
an immediate first interrupt; the short timer count expired during service,
leaving another request that disrupted the second timer test.

[Intel 8259A, order 231468-003](https://www.pcjs.org/documents/datasheets/intel/INTEL_8259A_PIC.pdf),
printed pages 17–18, Figure 9 and the edge/level description, specifies that
the request must remain high until the falling edge of the first INTA.
The priority-cell diagram separates the edge-sense latch from the request
latch. The edge latch prevents repeated requests while IR stays high; it
does not preserve a request after IR falls. An empty acknowledge always
uses IR7, including after priority rotation.

## Repair and verification

IR withdrawal clears the sampled request and excludes it from eligibility.
The first INTA captures a valid request/vector so later withdrawal cannot
change that vector. Empty acknowledge selects fixed IR7 rather than the
rotated lowest-priority level. The model cites the manufacturer diagram.
Literal directed tests independently check masked withdrawal, reassertion,
withdrawal before/after first INTA, ISR effects and rotated spurious IR7.
Formal assertions require a sampled low source to clear its IRR bit and
empty acknowledge to select IR7. Existing reset/init/mask/EOI checks remain.

The complete chip lint, Xezim, BMC/prove/cover and synthesis flow passes.
A synthetic external-ROM warm-start reproducer also reaches the original
BIOS timer test without 102 after the repair. The full unchanged FDISK
software restart also passes at 412,000,000 cumulative clocks without
adding any POST diagnostic; the historical suite checks this explicitly.

## Prevention

Model agreement is insufficient when both implementations share a mistaken
interpretation. Protocol boundary tests must use literal expected outcomes
pinned to a manufacturer diagram. The Model 30 real-software suite exercises
FDISK's software reset as well as cold boot and peripheral unit tests.
