import sympy as sp

x, y, z, N = sp.symbols('x y z N')

print(sp.simplify(sp.atan(sp.Pow(2,-x))))

