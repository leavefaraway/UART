module uart_top(
reset_n,
clock,
control_data,
rxd,
txd,
parity_check_error,
control_check_error
);

input reset_n;  //reset signal
input clock;    //system clock,100MHz
input control_data;  //serial receive control signal
input rxd;      //serial receive data
output txd;      //serial transmit data
output parity_check_error;  //parity error signal 
output control_check_error; //control check error signal

wire [15:0]bps_div;     //frequency division coefficient of 16 times baudrate
wire       clock_bps;   //16 times baudrate clock
wire  [3:0]data_size;   //data size
wire  [5:0]stop_size;   //stop_size
wire  [1:0]parity_check;//parity control signal
wire       rx_ready;    
wire       rx_shift;

//baudrate clock module instantiation
uart_baudrate baudrate(
.reset_n  (reset_n),
.clock    (clock),
.bps_div  (bps_div),
.clock_bps(clock_bps)
);

//control module instantiation
uart_control control(
.reset_n            (reset_n),
.clock              (clock),
.control_data       (control_data),
.clock_bps          (clock_bps),
.bps_div            (bps_div),
.data_size          (data_size),
.stop_size          (stop_size),
.parity_check       (parity_check),
.control_check_error(control_check_error)
);

//transmit data module instantiation
uart_tx tx(
.reset_n     (reset_n),
.clock       (clock),
.clock_bps   (clock_bps),
.rx_ready    (rx_ready),
.rx_shift    (rx_shift),
.data_size   (data_size),
.stop_size   (stop_size),
.parity_check(parity_check),
.txd         (txd)
);

//receive data module instantiation
uart_rx rx(
.reset_n           (reset_n),
.clock             (clock),
.clock_bps         (clock_bps),
.data_size         (data_size),
.stop_size         (stop_size),
.parity_check      (parity_check),
.rxd               (rxd),
.parity_check_error(parity_check_error),
.rx_ready          (rx_ready),
.rx_shift          (rx_shift)
);
endmodule
