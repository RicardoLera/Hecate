import math
import numpy as np
from matplotlib import pyplot as plot
plot.style.use('dark_background')

def toHex(value:float): # Credit to user8234870 at StackOverflow
  result = ""
  l = list()
  #converting to positive number and storing the - sign to the list
  if value < 0: 
      value = -value
      l.append('-')

  ivalue = int(value)#represent the integer part
  fvalue = value - ivalue#represent the floating part
  
  l.append(hex(ivalue))#storing the hexadecimal representation of integer part
  l.append('.')

  #float is 8 bytes and so has at most 16 hexadecimal values
  for i in range(16):
      fvalue = fvalue * 16
      digit = int(fvalue)
      l.append(format(digit,'X'))
      fvalue -= digit#removing the integer part
      if fvalue == 0:
        break
  #converting the result to a string
  for v in l:
      result += str(v)

  return result
arrToHex = np.vectorize(toHex)



# Standard Test
# img = np.array([1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=np.float64)
# ker = np.array([1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0], dtype=np.float64)

# 1D Test
# img = np.array([1, 1, 0], dtype=np.int8)
# ker = np.array([1, 1, 0], dtype=np.int8)

# 2D Test
# img = np.array([1, 1, 0, 1, 1, 0, 0, 0, 0], dtype=np.int8)
# ker = np.array([1, 1, 0, 1, 1, 0, 0, 0, 0], dtype=np.int8)

# 3D Test
img = np.array([1, 1, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0], dtype=np.float64)
ker = np.array([1, 0.5, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0], dtype=np.float64)

# img = np.array([1, 0, 0, 1, 0, 1, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 1, 0, 0.5, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0], dtype=np.float64)
# ker = np.array([1, 0, 0, 1, 0, 1, 0, 0, 0, 0.5, 0, 0, 0, 0, 0, 1, 0, 0.5, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0], dtype=np.float64)

# Random array test
# img = np.random.rand(8)
# ker = np.random.rand(8)
# img[4:8] = 0
# ker[4:8] = 0

#https://www.wolframalpha.com/input?i2d=true&i=Product%5BSqrt%5B1%2BPower%5B2%2C%5C%2840%29-2x%5C%2841%29%5D%5D%2C%7Bx%2C0%2C25-1%7D%5D
kcor = 1.6467602581210646732881021003239958776890527483399070103764969935

spsize =2**(math.ceil(math.log(np.size(img), 2))) # next power of 2



# FFT
IMG = np.fft.fft(img, spsize)
# print(arrToHex(np.real(IMG)))
# print(arrToHex(np.imag(IMG)))
KER = np.fft.fft(ker, spsize)
# print(arrToHex(np.real(KER)))

# CORDIC rect -> polar
mIMG = np.abs(IMG) * kcor
pIMG = np.angle(IMG)
mKER = np.abs(KER) * kcor
pKER = np.angle(KER)

# Hadamard
mHAD = mIMG * mKER / 32
pHAD = pIMG + pKER

# CORDIC polar -> rect
HAD = mHAD * np.exp(1j*pHAD) * kcor

# IFFT
had = np.fft.ifft(HAD, np.size(HAD)) * 32 /  pow(kcor,3)
print(arrToHex(np.real(had)))



# Prints
hex_xIMG = arrToHex(np.real(IMG))
hex_yIMG = arrToHex(np.imag(IMG))
hex_xKER = arrToHex(np.real(KER))
hex_yKER = arrToHex(np.imag(KER))
hex_mIMG = arrToHex(mIMG)
hex_pIMG = arrToHex(pIMG)
hex_mKER = arrToHex(mKER)
hex_pKER = arrToHex(pKER)
hex_mHAD = arrToHex(mHAD)
hex_pHAD = arrToHex(pHAD)
hex_xHAD = arrToHex(np.real(HAD))
hex_yHAD = arrToHex(np.imag(HAD))



# Plots
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