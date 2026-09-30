# Apple II system (in progress)

The original Apple II was introduced in **1977**. This system now connects the early MOS 6502 core to a 48 KiB RAM, ROM, and keyboard memory block. A text-page read port is available for later video timing. The core cannot yet boot Apple firmware.

The [Computer History Museum](https://www.computerhistory.org/tdih/june/10/) records its 1977 shipment. The [Apple II Reference Manual](https://apple2history.org/dl/Apple_II_Redbook.pdf) is the primary system architecture source. See the [system specification](spec/spec.md) and [plan](plans/implementation_plan.md).

The [supporting chip inventory](spec/chip_inventory.md) maps the motherboard's
RAM, ROM, character generator, TTL logic, and analog support parts. A synthetic
ROM regression now exercises CPU keyboard polling, text-RAM writes and strobe
acknowledgement end to end; authentic Monitor boot remains pending.
