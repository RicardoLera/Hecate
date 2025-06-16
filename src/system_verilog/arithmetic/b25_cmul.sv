module b25_cmul(
    input  [24:0] a, con,
    output [24:0] res
  );

  wire [39:0] um = (a[23:0] * con[23:0]);
  assign res[24]   = (um == '0) ? 1'b0 : (a[24] ^ con[24]);
  assign res[23:0] = um[39:16];

endmodule
