module fft_8_tb();

  reg  [24:0] i[0:7];
  wire [24:0] o[0:8][0:1];
  reg  clock=0, start=1, reset=0;
  wire s_ready;

  fft_8 dut(.*);

  wire [24:0] o_r[0:8];
  wire [24:0] o_i[0:8];

  assign {o_r[0], o_r[1], o_r[2], o_r[3], o_r[4], o_r[5], o_r[6], o_r[7]} =
         {o[0][0], o[1][0], o[2][0], o[3][0], o[4][0], o[5][0], o[6][0], o[7][0]};

  assign {o_i[0], o_i[1], o_i[2], o_i[3], o_i[4], o_i[5], o_i[6], o_i[7]} =
        {o[0][1], o[1][1], o[2][1], o[3][1], o[4][1], o[5][1], o[6][1], o[7][1]};

  initial
  begin
    $dumpfile("waveforms/verilog.vcd");
    $dumpvars(0, fft_8_tb);
    for (integer id = 0; id < 8; id++)
    begin
      $dumpvars(0, i[id]);
      $dumpvars(0, o_r[id]);
      $dumpvars(0, o_i[id]);
    end
  end

  initial
    for (integer id = 0; id < 8; id++)
      i[id] = 25'b0000000010000000000000000;
  
  always
    #1 clock = ~clock;

  always
    #1 if (s_ready === 1)
      $finish;

endmodule
