module hadamard
  #(parameter N = 8, logN = 3)
  (
    input  [24:0] img[0:1],
    output [24:0] ker[0:1],
    input  clock, start, reset,
    output ready
  );

  wire [24:0] calc_vals_arr[logN+1];
  reg  [24:0] add_a[0:8][0:1], add_b[0:8][0:1];
  reg  [8:0]  fft_ready = '0;


  initial
    for (integer id = 0; id < 8; id++)
    begin
      add_a[id][0] = '0;
      add_a[id][1] = '0;
      add_b[id][0] = '0;
      add_b[id][1] = '0;
    end

  // Multiplication Layer
  generate
    for (genvar id = 0; id < 8; id++)
    begin : mul_loop

      assign calc_vals_arr[id][0] = i[id];

      if ( (id % 4 == 1) | (id % 4 == 3) )
      begin
        b25_cmul mul_22(
                   .a   (i[id]),
                   .con (25'b0000000001110110010000100),
                   .res (calc_vals_arr[id][1])
                 );

        b25_cmul mul_45(
                   .a   (i[id]),
                   .con (25'b0000000001011010100000101),
                   .res (calc_vals_arr[id][2])
                 );

        b25_cmul mul_67(
                   .a   (i[id]),
                   .con (25'b0000000000110000111111000),
                   .res (calc_vals_arr[id][3])
                 );
      end

      if (id % 4 == 2)
        b25_cmul mul_45(
                   .a   (i[id]),
                   .con (25'b0000000001011010100000101),
                   .res (calc_vals_arr[id][2])
                 );
    end : mul_loop
  endgenerate

  // Addition Layer
  generate
    for (genvar o_id = 0; o_id < 9; o_id++)
    begin : add_loop

      b25_add sum_r(
                .a   (add_a[o_id][0]),
                .b   (add_b[o_id][0]),
                .res (add_r[o_id][0])
              );

      b25_add sum_i(
                .a   (add_a[o_id][1]),
                .b   (add_b[o_id][1]),
                .res (add_r[o_id][1])
              );

      always@(posedge clock)
      begin : add_process

        int unsigned i_id = 0;
        int unsigned w, wi;
        reg [24:0] c, ci;

        if (reset == 1'b0 & start == 1'b1)
          if (i_id < 8)
          begin
            w  = (i_id * o_id) % 16;
            wi = (4 - i_id * o_id) % 16;

            if (cos_val_ref[w] != 4) // if the exponent of w is not 4
            begin
              c                    = calc_vals_arr[i_id][cos_val_ref[w][1:0]];
              add_a[o_id][0]       = add_r[o_id][0];
              add_b[o_id][0][23:0] = c[23:0];
              add_b[o_id][0][24]   = cos_sig_ref[w] ? ~c[24] : c[24];
            end

            if (cos_val_ref[w] != 0) // if the exponent of w is not 0
            begin
              ci                   = calc_vals_arr[i_id][cos_val_ref[wi][1:0]];
              add_a[o_id][1]       = add_r[o_id][1];
              add_b[o_id][1][23:0] = ci[23:0];
              add_b[o_id][1][24]   = cos_sig_ref[wi] ? ~ci[24] : ci[24];
            end

            i_id++;
          end
          else
          begin
            fft_ready[o_id] = 1'b1;
          end

      end : add_process

      assign o[o_id][0] = {add_r[o_id][0][24], 2'b0, add_r[o_id][0][23:2]};
      assign o[o_id][1] = {add_r[o_id][1][24], 2'b0, add_r[o_id][1][23:2]};

    end : add_loop
  endgenerate

  assign s_ready = &fft_ready;

endmodule
