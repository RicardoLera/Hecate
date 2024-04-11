module b25_add(
    input  [24:0] a, b,
    output [24:0] res
  );

  assign res[23:0] = ~(a[24] ^ b[24])    ? (a[23:0] + b[23:0]) :
                     (a[23:0] > b[23:0]) ? (a[23:0] - b[23:0]) :
                                           (b[23:0] - a[23:0]);

  assign res[24] = (res[23:0] == '0)   ? 1'b0  :
                   (a[23:0] < b[23:0]) ? b[24] :
                   a[24];

endmodule





// always
//   if (a[24] ^ b[24])
//     if (ua > ub)
//       reg_res = {a[24], ua - ub};
//     else
//       reg_res = {b[24], ua - ub};
//   else
//     reg_res = {a[24], ua + ub};
