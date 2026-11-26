<div align="center">

# 🧠 CNN Inference on a Systolic Array

**Handwritten-digit recognition (MNIST) computed entirely by a 4×4 grid of Verilog multiply-accumulate units**

`Verilog HDL` · `Systolic arrays` · `Python / Keras` · `Fixed-point CNN`

</div>

---

## ✨ What is this?

A small hardware accelerator, built from scratch, that runs the inference of a convolutional neural network.
Instead of a CPU or GPU, every multiply-accumulate of the network is executed by a **4×4 systolic array** of identical processing elements (PEs). Convolutions and fully connected layers are rewritten as matrix multiplications, tiled onto the array, and streamed through it cycle by cycle.

```
 Python (Keras)                         Verilog (behavioural simulation)
┌──────────────────────┐   .mem files   ┌───────────────────────────────────────┐
│ Train CNN on MNIST   │ ─────────────▶ │ Testbench feeds weights + image data  │
│ Quantise to integers │                │ into the 4×4 systolic array, collects │
│ Export weights/images│                │ results, applies ReLU / pooling       │
└──────────────────────┘                └───────────────────────────────────────┘
```

---

## 🗺️ Project at a glance

| Stage | What it does | Main file |
|:-----:|--------------|-----------|
| **1. PE** | One multiply-accumulate cell that also relays its inputs | `PE.v` |
| **2. Systolic array** | 4×4 grid of PEs wired with `generate` loops | `Systolic_Array.v` |
| **3. CNN** | Train a small CNN, export integer weights, run inference on the array | `Part_C_CNN_.ipynb` + testbench |

---

## 1️⃣ Processing element

The building block. On every rising clock edge it passes its inputs along and accumulates their product:

```
aout(t) = ain(t-1)
bout(t) = bin(t-1)
cout(t) = cout(t-1) + ain(t-1) · bin(t-1)
```

```
              reset   clk   bin
                ↓      ↓     ↓
   ain ──▶ ┌───────────────────┐ ──▶ [REG] ──▶ aout
           │    PE  (MAC)      │
           │                   │ ──▶ [REG] ──▶ cout  (accumulator)
           └───────────────────┘
                      ↓
                    [REG]
                      ↓
                     bout
```

```verilog
module PE #(parameter bit = 16, width = 32) (rst, clk, ain, bin, aout, bout, cout);
```

- `ain`, `bin`: signed `bit`-bit operands, `cout`: signed `width`-bit accumulator
- `aout` goes to the PE on the right, `bout` to the PE below
- `rst` clears everything

---

## 2️⃣ Systolic array

PEs are connected so that `A` values flow **left → right** and `B` values flow **top → bottom**. Each PE ends up holding one element of the result matrix `C = A × B`.

```
              b30  b31  b32  b33          B enters from the top,
              b20  b21  b22  b23          each column delayed by one
              b10  b11  b12  b13          more cycle than the previous
              b00  b01   0    0
               ↓    ↓    ↓    ↓
  a03 a02 a01 a00 ─▶ [PE]─▶[PE]─▶[PE]─▶[PE]
                      ↓     ↓     ↓     ↓
  a13 a12 a11 a10 0 ─▶[PE]─▶[PE]─▶[PE]─▶[PE]      A enters from the left,
                      ↓     ↓     ↓     ↓          each row delayed by one
  a23 a22 a21 a20 0 0 ▶[PE]─▶[PE]─▶[PE]─▶[PE]      more cycle than the
                      ↓     ↓     ↓     ↓          previous
  a33 a32 a31 a30 0 0 0▶[PE]─▶[PE]─▶[PE]─▶[PE]
```

```verilog
module Systolic_Array #(parameter bit = 3, m = 2, n = 4, width = 5)
                       (clk, rst, row, column, out);
```

| Port | Meaning |
|------|---------|
| `row [m*bit-1:0]` | one operand per array row (left edge) |
| `column [n*bit-1:0]` | one operand per array column (top edge) |
| `out [m*n*width-1:0]` | all accumulators, row-major: `C[i][j]` at bits `[(i·n + j)·width +: width]` |

### ⏱️ Timing

At clock edge `t`, row `i` receives `A[i][t-i]` and column `j` receives `B[t-j][j]` (zeros outside `0…K-1`). PE(i,j) sees the matching pair `A[i][k]`, `B[k][j]` at edge `t = i + j + k`.

A 4×4 block of the result is complete after

$$\text{cycles} = K + m + n - 2 = K + 6$$

| Product | K | Minimum clock cycles |
|---------|:-:|:--------------------:|
| (4×4) · (4×4) | 4 | **10** |
| (4×8) · (8×4) | 8 | **14** |

Because each PE keeps accumulating, larger inner dimensions simply stream for longer. Larger matrices are handled by tiling the output into 4×4 blocks.

---

## 3️⃣ CNN on MNIST

### Network

```
 28×28×1
   │  Conv2D  5 filters, 3×3, ReLU
 26×26×5
   │  MaxPool 2×2
 13×13×5
   │  Conv2D 10 filters, 3×3, ReLU
 11×11×10
   │  MaxPool 2×2
  5×5×10
   │  Flatten  →  Dropout(0.45)
   250
   │  Dense 128, ReLU
   128
   │  Dense 10, softmax
   10  → predicted digit
```

Trained with Adam (learning rate 0.001) and categorical cross-entropy on the 60,000 MNIST training images, tested on the separate 10,000 test images.

### Turning layers into matrix multiplications

A convolution becomes one big matrix product (the *im2col* trick): every 3×3 image patch is flattened into a row, every filter into a column.

| Layer | Left matrix (patches / inputs) | Right matrix (weights) | Result |
|-------|-------------------------------|------------------------|--------|
| conv1 | 676 × 9  (26·26 patches) | 9 × 5 | 676 × 5 |
| conv2 | 121 × 45 (11·11 patches × 5 channels) | 45 × 10 | 121 × 10 |
| dense1 | 1 × 250 | 250 × 128 | 1 × 128 |
| dense2 | 1 × 128 | 128 × 10 | 1 × 10 |

Everything is computed with **integer** arithmetic: weights are quantised to fit the PE operand width (`bit`), and the accumulators (`width`) are wide enough not to overflow.

### Exported data

The notebook writes plain `.mem` files that the Verilog testbench reads with `$readmemb`:

```
conv1_weights.mem   conv1_biases.mem
conv2_weights.mem   conv2_biases.mem
dense1_weights.mem  dense1_biases.mem
dense2_weights.mem  dense2_biases.mem
test_images_100.mem test_labels_100.mem      (100 images, 10 per digit)
```

---

## 📊 Results

| Metric | Value |
|--------|-------|
| Keras train accuracy | **97.5 %** |
| Keras test accuracy | **98.9 %** |
| Accuracy on 100 test images, systolic-array simulation | **99 %** (99 / 100) |
| Cycles for 4×4 · 4×4 | 10 |
| Cycles for 4×8 · 8×4 | 14 |

Add the accuracy-vs-epoch plot (`mnist_cnn_accuracy.png`) and waveform screenshots here.

---

## 🚀 Getting started

```
.
├── rtl/   PE.v   Systolic_Array.v
├── tb/    testbenches
├── python/ Part_C_CNN_.ipynb
└── mem/   generated .mem files
```

1. **Train and export** – run `Part_C_CNN_.ipynb` (Colab or Jupyter with TensorFlow) and download the generated `.mem` files.
2. **Simulate** – add `PE.v`, `Systolic_Array.v` and a testbench to Vivado / ModelSim / Icarus Verilog, put the `.mem` files in the simulator working directory, set the testbench as top and run.

```
iverilog -g2001 -o sim rtl/PE.v rtl/Systolic_Array.v tb/<testbench>.v
vvp sim
```

> ⚠️ Compile as **Verilog-2001**, not SystemVerilog: `bit` is used as a parameter name and is a reserved word in SystemVerilog.

---

## 🔧 Possible extensions

- Larger arrays (change `m`, `n`) and compare cycle counts
- Pipelined bias / ReLU / pooling units so only the array and glue logic remain
- Synthesis and timing analysis on an FPGA
- Other datasets (e.g. CIFAR-10 with 3×3×3 kernels, 27-column im2col)

---

