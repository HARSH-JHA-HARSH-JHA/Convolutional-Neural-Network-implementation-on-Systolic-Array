module PE #(parameter bit = 16,width = 32) (rst,clk,ain,bin,aout,bout,cout);
input rst,clk;
input [bit-1:0] ain, bin;
output reg [bit-1:0] aout, bout;
output reg [width-1:0] cout;

always @(posedge clk,posedge rst) 
if(rst) begin
aout <= 0;
bout <= 0;
cout <= 0;
end
else begin
aout <= ain;
bout <= bin;
cout <= cout + ain*bin;
end

endmodule
