import math
import numpy as np
import scipy as scp
from matplotlib import pyplot as plot
plot.style.use('dark_background')

# Standard Test
img = np.array([1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=np.int8)
ker = np.array([1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=np.int8)

# 1D Test
# img = np.array([1, 1, 0], dtype=np.int8)
# ker = np.array([1, 1, 0], dtype=np.int8)

# 2D Test
# img = np.array([1, 1, 0, 1, 1, 0], dtype=np.int8)
# ker = np.array([1, 1, 0, 1, 1, 0], dtype=np.int8)

# 3D Test
# img = np.array([1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0], dtype=np.int8)
# ker = np.array([1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0], dtype=np.int8)

# Random array test
# img = np.random.rand(8)
# ker = np.random.rand(8)
# img[4:8] = 0
# ker[4:8] = 0

spsize = 2**(math.ceil(math.log(np.size(img), 2))) # next power of 2

IMG = np.fft.fft(img, spsize)
KER = np.fft.fft(ker, spsize)
HAD = IMG * KER
had = np.fft.ifft(HAD, np.size(HAD))

fig, axs = plot.subplots(nrows=3, ncols=2)

axs[0][0].title.set_text("img")
axs[0][0].plot(np.linspace(0, np.size(img)-1, np.size(img)), img, linestyle='', marker='o')
axs[0][0].set_xlabel("N")
axs[0][0].grid(True, which="both")

axs[0][1].title.set_text("ker")
axs[0][1].plot(np.linspace(0, np.size(ker)-1, np.size(ker)), ker, linestyle='', marker='o')
axs[0][1].set_xlabel("N")
axs[0][1].grid(True, which="both")

axs[1][0].title.set_text("img DFT")
axs[1][0].plot(np.angle(IMG), np.abs(IMG), linestyle='', marker='o')
axs[1][0].set_xlabel("Angle")
axs[1][0].grid(True, which="both")

axs[1][1].title.set_text("ker DFT")
axs[1][1].plot(np.angle(KER), np.abs(KER), linestyle='', marker='o')
axs[1][1].set_xlabel("Angle")
axs[1][1].grid(True, which="both")

axs[2][0].title.set_text("Pointwise Multiplication")
axs[2][0].plot(np.angle(HAD), np.abs(HAD), linestyle='', marker='o')
axs[2][0].set_xlabel("Angle")
axs[2][0].grid(True, which="both")

axs[2][1].title.set_text("Convolution")
axs[2][1].plot(np.linspace(0, np.size(had) - 1, np.size(had)), had, linestyle='-', marker='o')
axs[2][1].set_xlabel("2*N - 1")
axs[2][1].grid(True, which="both")

plot.show()