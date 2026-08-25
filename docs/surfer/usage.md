# Surfer Usage Guide

## Opening Waveforms

```bash
# Open VCD file
surfer simulation.vcd

# Open FST file
surfer simulation.fst

# Open from URL (web version)
# Drag and drop file onto https://app.surfer-project.org
```

## Basic Navigation

### Time Navigation
- **Scroll**: Pan timeline left/right
- **Zoom**: Mouse wheel or pinch gesture
- **Fit**: View entire waveform duration
- **Jump**: Click on timeline to set cursor position

### Signal Management
- **Add signals**: Browse hierarchy tree, double-click or drag to waveform view
- **Remove signals**: Right-click signal name → Remove
- **Reorder**: Drag signals up/down in the signal list
- **Group**: Create signal groups for organization

### Cursor and Markers
- **Primary cursor**: Click on waveform area
- **Secondary cursor**: Right-click or Shift+click
- **Measure**: Distance between cursors shown in toolbar

## Viewing Signals

### Display Formats
- Binary
- Hexadecimal
- Decimal (signed/unsigned)
- Octal
- ASCII

### Bus/Vector Display
- Expand bus to show individual bits
- Collapse bits back to bus view
- Color coding for different signal types

## Working with Hierarchies

1. Open the hierarchy browser (left panel)
2. Navigate module tree
3. Select signals from any level
4. Double-click to add to waveform view

## Searching

- Search signals by name
- Filter hierarchy tree
- Find value transitions on a signal

## Integration with Simulators

### From Verilator
```bash
verilator --binary --trace-fst top.sv
./obj_dir/Vtop
surfer dump.fst
```

### From xezim
```bash
xezim --simulate -s top design.sv --fst output.fst
surfer output.fst
```

### From Icarus Verilog
```bash
iverilog -o sim design.v
vvp sim
surfer dump.vcd
```

## Tips

1. **Use FST format** when possible — smaller files, faster loading
2. **Limit trace depth** in simulator to reduce file size
3. **Use hierarchy** to organize signals logically
4. **Bookmark** important time points during debugging
5. **Compare** multiple runs by loading files side by side (web version)
