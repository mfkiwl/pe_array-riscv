`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/08/2021 10:20:18 AM
// Design Name: 
// Module Name: pe_array_bd
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A linear bidirectional array of RISC-V PEs  
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
`include "parameters.vh"

module pe_array_bd(
    clk, rst, load, din_v, din, dout_v, dout
    );
    
input  clk; 
input  rst; 
input  load; 
input  din_v; 
input  [`DATA_WIDTH*2-1:0] din; 

output dout_v; // reg
output [`DATA_WIDTH*2-1:0] dout; // reg 

reg [`PE_NUM-1:0] array_in_v = 0;
reg [`DATA_WIDTH*2-1:0] array_in [`PE_NUM-1:0];

//reg [13:0] stream_cnt = 0; // 2^14 = 16384 = 256*32*2 (X, Y matrices)
//reg [14:0] stream_cnt = 0; // 2^15 = 32768 = 256*32*2*2 (X, Y matrices)

integer j;
wire [`DATA_WIDTH*2-1:0] stream_in;
wire empty;
reg rd_en = 0;
reg ready = 0;
reg [15:0] count = 0; // 2^16 = 65536

always @(posedge clk) begin
	if(~empty) begin // when FIFO is not empty
		if (count < `PE_NUM *`LOAD_NUM) begin
			count <= count + 1;
			rd_en <= 1;
		end
		else if (count == 16'd4095) begin
			count <= 0;
			rd_en <= 0;
		end
		else begin
			count <= count + 1;
			rd_en <= 0;
		end
		for (j = 0; j < `PE_NUM; j = j+1) begin
		    if (count >= j*`LOAD_NUM + 2 && count < (j+1)*`LOAD_NUM + 2) begin
                array_in_v[j] <= ready;
                array_in[j] <= stream_in;
            end
            else begin
                array_in_v[j] <= 0;
                array_in[j] <= 0;
            end
        end
	end
	else begin // when FIFO is empty
		count <= 0;
		rd_en <= 0;
		array_in_v[`PE_NUM-1] <= 0;
		array_in[`PE_NUM-1] <= 0;
	end
	ready <= rd_en;
end

// Built-in FIFO generated by Xilinx IP Catalog
fifo_generator_0 input_fifo (
  .clk(clk),                  // input wire clk
  .srst(rst),                 // input wire srst
  .din(din),                  // input wire [31 : 0] din
  .wr_en(din_v),              // input wire wr_en
  .rd_en(rd_en),              // input wire rd_en
  .dout(stream_in),           // output wire [31 : 0] dout
  .full(full),                // output wire full
  .empty(empty),              // output wire empty
  .wr_rst_busy(wr_rst_busy),  // output wire wr_rst_busy
  .rd_rst_busy(rd_rst_busy)   // output wire rd_rst_busy
);

reg [`PE_NUM-1:0] pe_in_v;
reg [`DATA_WIDTH*2-1:0] pe_in [`PE_NUM-1:0];
reg [`PE_NUM-1:0] pe_tx_in_v;
reg [`DATA_WIDTH*2-1:0] pe_tx_in [`PE_NUM-1:0];
reg [`PE_NUM-1:0] pe_shift_in_v;
reg [`DATA_WIDTH*2-1:0] pe_shift_in [`PE_NUM-1:0];
reg [`PE_NUM-1:0] s_shift_c;
reg [7:0] iter_num [`PE_NUM-1:0];

wire [`PE_NUM-1:0] pe_out_v;
wire [`DATA_WIDTH*2-1:0] pe_out [`PE_NUM-1:0];
wire [`PE_NUM-1:0] pe_tx_out_v;
wire [`DATA_WIDTH*2-1:0] pe_tx_out [`PE_NUM-1:0];
wire [`PE_NUM-1:0] pe_shift_out_v;
wire [`DATA_WIDTH*2-1:0] pe_shift_out [`PE_NUM-1:0];
wire [`PE_NUM-1:0] m_shift_c;
wire [`PE_NUM-1:0] pe_back;

integer m;
always @ (posedge clk) begin
    for (m = 0; m < `PE_NUM; m = m+1) begin 
        if(m == 0) begin // PE[0]
            if(~pe_back[0]) begin // forward
                pe_in_v[0] <= array_in_v[0];
                pe_in[0] <= array_in[0];
                pe_tx_in_v[0] <= 0;
                pe_tx_in[0] <= 0;
                pe_shift_in_v[0] <= pe_shift_out_v[1];
                pe_shift_in[0] <= pe_shift_out[1];
                s_shift_c[0] <= 0;
            end
            else begin // backward
                pe_in_v[0] <= array_in_v[`PE_NUM-1];
                pe_in[0] <= array_in[`PE_NUM-1];
                pe_tx_in_v[0] <= pe_tx_out_v[1];
                pe_tx_in[0] <= pe_tx_out[1];
                pe_shift_in_v[0] <= 0;
                pe_shift_in[0] <= 0;
                s_shift_c[0] <= m_shift_c[1];
            end
        end 
        else if(m == `PE_NUM-1) begin // PE[N-1]
            if(~pe_back[`PE_NUM-1]) begin // forward
                pe_in_v[`PE_NUM-1] <= array_in_v[`PE_NUM-1];
                pe_in[`PE_NUM-1] <= array_in[`PE_NUM-1];
                pe_tx_in_v[`PE_NUM-1] <= pe_tx_out_v[`PE_NUM-2];
                pe_tx_in[`PE_NUM-1] <= pe_tx_out[`PE_NUM-2];
                pe_shift_in_v[`PE_NUM-1] <= 0;
                pe_shift_in[`PE_NUM-1] <= 0;
                s_shift_c[`PE_NUM-1] <= m_shift_c[`PE_NUM-2];
            end
            else begin // backward
                pe_in_v[`PE_NUM-1] <= array_in_v[0];
                pe_in[`PE_NUM-1] <= array_in[0];
                pe_tx_in_v[`PE_NUM-1] <= 0;
                pe_tx_in[`PE_NUM-1] <= 0;
                pe_shift_in_v[`PE_NUM-1] <= pe_shift_out_v[`PE_NUM-2];
                pe_shift_in[`PE_NUM-1] <= pe_shift_out[`PE_NUM-2];
                s_shift_c[`PE_NUM-1] <= 0;
            end
        end 
        else begin // PE[1] to PE[N-2]
            if(~pe_back[m]) begin // forward
                pe_in_v[m] <= array_in_v[m];
                pe_in[m] <= array_in[m];
                pe_tx_in_v[m] <= pe_tx_out_v[m-1];
                pe_tx_in[m] <= pe_tx_out[m-1];
                pe_shift_in_v[m] <= pe_shift_out_v[m+1];
                pe_shift_in[m] <= pe_shift_out[m+1];
                s_shift_c[m] <= m_shift_c[m-1];
            end
            else begin // backward
                pe_in_v[m] <= array_in_v[`PE_NUM-1-m];
                pe_in[m] <= array_in[`PE_NUM-1-m];
                pe_tx_in_v[m] <= pe_tx_out_v[m+1];
                pe_tx_in[m] <= pe_tx_out[m+1];
                pe_shift_in_v[m] <= pe_shift_out_v[m-1];
                pe_shift_in[m] <= pe_shift_out[m-1];
                s_shift_c[m] <= m_shift_c[m+1];
            end
        end
    end    
end

wire out_v, p_in_v;
wire [`PE_NUM*`DATA_WIDTH*2-1:0] p_in;

genvar i;
generate
    for (i = 0; i < `PE_NUM; i = i+1) begin : array
        // PE[0] to PE[N-1]
        pe #
        (
//        .ITER_NUM(`ITER_NUM-2*(i+1)) 
        .ITER_NUM_1(`ITER_NUM-2*(i+1)), //
        .ITER_NUM_2(2*i) // 
        )
        PE_i( 
        .clk(clk), 
        .rst(rst), 
        .din_pe_v(pe_in_v[i]), 
        .din_pe(pe_in[i]),           
        .din_tx_v(pe_tx_in_v[i]), 
        .din_tx(pe_tx_in[i]),
        .din_shift_v(pe_shift_in_v[i]), 
        .din_shift(pe_shift_in[i]),  
        .s_shift(s_shift_c[i]), 
        .iter_set(pe_back[i]),
            
        .dout_pe_v(pe_out_v[i]), 
        .dout_pe(pe_out[i]), 
        .dout_tx_v(pe_tx_out_v[i]), 
        .dout_tx(pe_tx_out[i]),
        .dout_shift_v(pe_shift_out_v[i]), 
        .dout_shift(pe_shift_out[i]),
        .m_shift(m_shift_c[i]),
        .backward(pe_back[i])
        ); 
        
//        assign p_in_v = pe_out_v[i] ? 1 : 0;
//        assign p_in[(i+1)*`DATA_WIDTH*2-1:i*`DATA_WIDTH*2] = pe_out[i];
        
    end
endgenerate

//piso_new out_buffer(
//    .clk(clk), 
//    .load(load), 
//    .p_in_v(), // 
//    .p_in(p_in), 
//    .s_out_v(dout_v), 
//    .s_out(dout)
//    );

reg [`PE_NUM-1:0] out_buf_v;
reg [`DATA_WIDTH*2-1:0] out_buf [`PE_NUM-1:0];

integer k;
always @ (posedge clk) begin
//    dout_v <= out_buf_v[0];
//    dout <= out_buf[0];
    
    for (k = `PE_NUM-1; k >= 0 ; k = k-1) begin 
        if (k == `PE_NUM-1) begin 
            if (pe_out_v[k]) begin 
                out_buf_v[k] <= 1;
                out_buf[k] <= pe_out[k];
            end
            else begin
                out_buf_v[k] <= 0;
                out_buf[k] <= 0;
            end
        end
//        else if (k == 0) begin
//            dout_v <= out_buf_v[k+1];
//            dout <= out_buf[k+1];
//        end
        else begin // 0 < k < `PE_NUM-1
            if (pe_out_v[k]) 
                out_buf[k] <= pe_out[k];
            else 
                out_buf[k] <= out_buf[k+1];
                
            if (pe_out_v[k] | out_buf_v[k+1]) 
                out_buf_v[k] <= 1;
            else 
                out_buf_v[k] <= 0;
        end
        
//        if(pe_out_v[k]) begin // load
//            dout_v <= 1;
//            dout <= pe_out[k];
//        end
//        else begin
//            dout_v <= 0;
//            dout <= 0;
//        end
    end
end

wire out_empty;
wire out_rd_en;

assign out_rd_en = out_empty ? 0 : 1;

fifo_generator_0 output_fifo (
  .clk(clk),                  // input wire clk
  .srst(rst),                 // input wire srst
  .din(out_buf[0]),                  // input wire [31 : 0] din
  .wr_en(out_buf_v[0]),              // input wire wr_en
  .rd_en(out_rd_en),              // input wire rd_en
  .dout(dout),           // output wire [31 : 0] dout
  .full(),                // output wire full
  .empty(out_empty),              // output wire empty
  .wr_rst_busy(),  // output wire wr_rst_busy
  .rd_rst_busy()   // output wire rd_rst_busy
);

reg out_rd_en_r = 0;
always @(posedge clk) 
    out_rd_en_r <= out_rd_en;

assign dout_v = out_rd_en_r;
    
endmodule