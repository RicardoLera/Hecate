import sympy as sp

x, y, z, N = sp.symbols('x y z N')

print(sp.simplify((N/4) * (sp.log(N,2)-2)))

