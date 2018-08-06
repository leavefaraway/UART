module uart_control(
reset_n,
clock,
clock_bps,
bps_div,
data_size,
stop_size,
parity_check,
control_check_error
);

input reset_n;
input clock;
input control_data;  //serial receive control data
input clock_bps;
output bps_div;
output data_size;
output stop_size;
output parity_check;
output control_check_error;

reg [15:0]bps_div = 16'd325;
reg [3:0] data_size;
reg [5:0] stop_size;
reg       control_check_error;

reg       control_ready = 1'b0;
reg [47:0]control_frame;  //control data frame

reg [7:0] checksum;
reg [15:0]control; //16 bit control register
reg [3:0] baudrate;
reg [1:0] data_width;
reg [1:0] stop;
reg [1:0] parity_check;

wire control_in;
reg  control1;
reg  control2;
reg  control3;
wire control_pos;
wire control_neg;

reg      rx_ready = 1'b0;
reg [7:0]rx_shift;

parameter [2:0]s_idle  = 3'b000;
parameter [2:0]s_sample= 3'b001;
parameter [2:0]s_check = 3'b010;
parameter [2:0]s_stop  = 3'b011;

reg [3:0]cnt = 6'b0;
reg [3:0]dcnt= 4'b0;
reg [3:0]ready_num = 4'b0; //rx_ready count
reg [2:0]num = 3'b0;
reg [2:0]state = s_idle;

//processing across the clock domain
always@(posedge clock_bps or negedge reset_n)begin
  if(!reset_n)begin
    control1 <= 1'b0;
    control2 <= 1'b0;
    control3 <= 1'b0;
  end
  else begin
    control1 <= control_data;
    control2 <= control1;
    control3 <= control2;
  end
end
assign control_pos = control2 & (!control3);
assign control_neg = control3 & (!control2);
assign control_in  = control2;

//calculation of frequency division coefficient of 16 times baudrate
//bps_div = clock/(16*baudrate)
always@(pesedge clock or negedge reset_n)begin
  if(!reset_n)begin
    bps_div <= 16'd325;
  end
  else begin
    if(control_ready == 1'b1)begin
      case(baudrate)
        4'b0000: bps_div <= 16'd28409; //16*baudrate = 110
        4'b0001: bps_div <= 16'd10416; //16*baudrate = 300
        4'b0010: bps_div <= 16'd5208;  //16*baudrate = 600
        4'b0011: bps_div <= 16'd2604;  //16*baudrate = 1200
        4'b0100: bps_div <= 16'd1302;  //16*baudrate = 2400
        4'b0101: bps_div <= 16'd651;   //16*baudrate = 4800
        4'b0110: bps_div <= 16'd325;   //16*baudrate = 9600
        4'b0111: bps_div <= 16'd217;   //16*baudrate = 14400
        4'b1000: bps_div <= 16'd162;   //16*baudrate = 19200
        4'b1001: bps_div <= 16'd81;    //16*baudrate = 38400
        4'b1010: bps_div <= 16'd72;    //16*baudrate = 43000
        4'b1011: bps_div <= 16'd55;    //16*baudrate = 56000
        4'b1100: bps_div <= 16'd54;    //16*baudrate = 57600
        4'b1101: bps_div <= 16'd27;     //16*baudrate = 115200
        4'b1110: bps_div <= 16'd24;    //16*baudrate = 128000
        4'b1111: bps_div <= 16'd12;    //16*baudrate = 256000
      endcase
    end
    else begin
      bps_div <= bps_div;
    end
  end
end

//data width select
always@(posedge clock)begin
  if(control_ready == 1'b1)begin
    case(data_width)
      2'b00: data_size <= 4'd5; //5 bit data
      2'b01: data_size <= 4'd6; //6 bit data
      2'b10: data_size <= 4'd7; //7 bit data
      2'b11: data_size <= 4'd8; //8 bit data
    endcase
  end
  else begin
    data_size <= data_size;
  end
end

//stop size select
always@(posedge clock)begin
  if(control_ready == 1'b1)begin
    case(stop)
      2'b00: stop_size <= 6'd16;
      2'b01: stop_size <= 6'd24;
      2'b10: stop_size <= 6'd32;
      default: stop_size <= 6'd16;
    endcase
  end
  else begin
    stop_size <= stop_size;
  end
end

//serial receive control data
always@(posedge clock_bps or negedge reset_n)begin
  if(!reset_n)begin
    state <= s_idle;
    cnt   <= 4'b0;
    dcnt  <= 4'b0;
    rx_shift <= 8'b0;
    rx_ready <= 1'b0;
  end
  else begin
    case(state)
      //idle state, check start signal
      s_idle:begin
        rx_ready <= 1'b0;
        if(control_in == 1'b0)begin
          if(cnt == 4'b0111)begin
            cnt   <= 4'b0;
            state <= s_sample;
          end
          else begin
            cnt   <= cnt + 1'b1;
            state <= s_idle;
          end
        end
        else begin
          cnt <= 1'b0;
        end
      end
      //sample state,serial receive data
      s_sample:begin
        rx_ready <= 1'b0;
        if(dcnt == 4'd8)begin
          dcnt  <= 4'b0;
          state <= s_check;
        end
        else begin
          state <= s_sample;
          if(cnt == 4'b1111)begin
            dcnt <= dcnt + 1'b1;
            cnt  <= 4'b0;
            rx_shift[dcnt] <= control_in;
          end
          else begin
            cnt <= cnt + 1'b1;
          end
        end
      end
      //check state,receive parity bit
      s_check:begin
        rx_ready <= 1'b0;
        if(cnt == 4'b0110)begin
          cnt   <= 4'b0;
          state <= s_stop;
        end
        else begin
          cnt <= cnt + 1'b1;
        end
      end
      //stop state,check stop signal
      s_stop:begin
        rx_ready <= 1'b1;
        if(cnt == 4'b1111)begin
          cnt   <= 4'b0;
          state <= s_idle;
        end
        else begin
          cnt <= cnt + 1'b1;
        end
      end
      default:state <= s_idle;
    endcase
  end
end

//receive control frame
always@(posedge clock_bps or negedge reset_n)begin
  if(!reset_n)begin
    ready_num <= 4'b0;
    num       <= 3'b0;
    control_frame <= 48'b0;
  end
  else if(num == 3'd6)begin
    num <= 3'b0;
  end
  else if(rx_ready == 1'b0)begin
    num <= num;
  end
  else if(ready_num == 4'b1111)begin
    ready_num <= 4'b0;
    case(num)
      3'b0:if(rx_shift == 8'haa)begin
             control_frame[47:40] <= rx_shift;
             num <= num + 1'b1;
           end
           else begin
             control_frame <= 48'b0;
             num <= 3'b0;
           end
      3'b1:if(rx_shift == 8'h55)begin
             control_frame[39:32] <= rx_shift;
             num <= num + 1'b1;
           end
	   else if(rx_shift == 8'haa)begin
	     control_frame[47:40] <= rx_shift;
	     num <= 3'b1;     
	   end 
	   else begin
	     control_frame <= 48'b0;
	     num <= 3'b0;
	   end
      3'b2:begin
	   control_frame[31:24] <= rx_shift;
	   num <= num + 1'b1;
	   end
      3'b3:begin
	   control_frame[23:16] <= rx_shift;
	   num <= num + 1'b1;
	   end
      3'b4:begin
	   control_frame[15:8] <= rx_shift;
	   num <= num + 1'b1;
	   end
      3'b5:if(rx_shift == 8'h55)begin
	     control_frame[7:0] <= rx_shift;
	     num <= num + 1'b1;
	   end
	   else if(rx_shift == 8'haa)begin
	     control_frame <= {rx_shift,40'b0};
	     num <= 3'b1;
	   end
	   else begin
	     control_frame <= 48'b0;
	     num <= 3'b0;
	   end
      default:control_frame <= 48'b0;
    endcase
  end
  else begin
    ready_num <= ready_num + 1'b1;
  end
end
//judge whether control data is correct
always@(posedge clock or negedge reset_n)begin
  if(!reset_n)begin
    control_ready       <= 1'b0;
    control_check_error <= 1'b0;
  end
	else if(num == 3'd6)begin
		if(control_frame[47:32]==16'haa55 && control_frame[7:0]==8'h55)begin
			if(control_frame[31:24] + control_frame[23:16] == control_frame[15:8])begin
			  control_ready       <= 1'b1;
				control_check_error <= 1'b0;
				checksum <= control_frame[15:8];
				control  <= control_frame[31:16];
				baudrate <= control[11:8];
				data_width  <= control[5:4];
				stop        <= control[3:2];
				parity_check<=control[1:0];
			end
			else begin
			  control_ready       <= 1'b0;
				control_check_error <= 1'b1;
			end
		end
		else begin
		  control_ready       <= 1'b0;
			control_check_error <= control_check_error;
		end
	end
	else begin
	  control_ready       <= 1'b0;
		control_check_error <= control_check_error;
	end
end
endmodule
