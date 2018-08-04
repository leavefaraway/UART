module uart_baudrate(
reset_n,
clock,
bps_div,
clock_bps
);

input      reset_n;
input      clock;
input[15:0]bps_div;
output     clock_bps;

reg       clock_bps;
reg [15:0]cnt;

always@(posedge clock or negedge reset_n)begin
  if(!reset_n)begin
    cnt <= 16'h0;
    clock_bps <= 0;
  end
  else if(cnt == bps_div - 1)begin
    cnt <= 16'h0;
    clock_bps <= 1;
  end
  else begin
    cnt <= cnt + 16'h1;
    clock_bps <= 0;
  end
end
endmodule
