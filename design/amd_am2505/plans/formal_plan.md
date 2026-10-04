# Formal plan: Am2505

Pure combinational proof with unrestricted binary physical pins. An
independent oracle forms signed coefficient d=ym+y0-2*y1 and computes
`d*signed(X)+signed(K)+cin-y1`, plus +xm for d=+2 or -xm for d=-2.
This captures one's-complement subtraction and independent carry input.
Assert S0-S3 modulo 16 for all inputs, all six signed result bits when
X4=X3, and Cn+4 from a separate operation-table nibble addition.

Cover all eight Booth input combinations, both polarity levels,
positive/negative 2X, and subtraction carry. No reset or temporal
assumptions apply to a combinational device. BMC/prove/cover use depth 2.
